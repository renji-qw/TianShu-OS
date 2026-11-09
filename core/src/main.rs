// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025-2026 紫枢联合组织 / TianShu OS Project
// 调度核心：λ 痛觉退让主方程 + SIMD 派发 + 物理内存预留。
// Scheduling core: λ pain-retreat ODE + SIMD dispatch + memory reservation.

use libc::{c_void, madvise, mlock, munlock, munmap, MADV_DONTNEED, MAP_FAILED};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use sysinfo::{Components, System};

/// K 值安全域 [0, 100] / K safety domain [0, 100]
const K_FLOOR: f32 = 0.0;
const K_CEIL: f32 = 100.0;

/// λ 初值必须非零：λ' 主项是 λ·e^(-χ)，从 0 起步会永远停在 0。
/// λ init MUST be non-zero: the dominant term λ·e^(-χ) stays 0 forever otherwise.
const LAMBDA_INIT: f32 = 50.0;

/// d² 归一化尺度。原始第一项 ≈3.62e6，不缩放会让 (d²-500) 恒为负，痛觉项失效。
/// TODO(renji): 用实测日志调，目标典型 d² ∈ [400, 700]。
/// d² normalization scale. Raw first term ≈3.62e6; without scaling,
/// (d²-500) is always negative and the pain term silently dies.
/// TODO(renji): calibrate via runtime logs; target typical d² ∈ [400, 700].
const D_SQ_SCALE: f32 = 7200.0;

/// d² 上限，仅防溢出 / Upper bound for d², overflow guard only.
const D_SQ_CEIL: f32 = 1.0e6;

// ───────── 预留物理内存：RAII 守卫，Drop 自动 munlock + munmap ─────────
// ───────── Reserved memory: RAII guard, Drop auto munlock + munmap ─────────

struct ReserveRegion {
    ptr: *mut u8,
    len: usize,
    locked: bool,
}

impl ReserveRegion {
    /// len == 0 返回 None / Returns None when len == 0.
    fn new(len: usize) -> Option<Self> {
        if len == 0 {
            log::info!("【内存锁定】TIANSHU_RESERVE_MB=0，跳过预留。 / [MemLock] TIANSHU_RESERVE_MB=0, skipping.");
            return None;
        }

        // SAFETY: 标准匿名私有映射，fd=-1/offset=0 合法；返回值下方校验 MAP_FAILED。
        // SAFETY: standard anonymous private mapping, fd=-1/offset=0 valid;
        //         return value is checked against MAP_FAILED below.
        let ptr = unsafe {
            libc::mmap(
                std::ptr::null_mut(),
                len,
                libc::PROT_READ | libc::PROT_WRITE,
                libc::MAP_PRIVATE | libc::MAP_ANONYMOUS,
                -1,
                0,
            ) as *mut u8
        };

        if ptr as *mut c_void == MAP_FAILED {
            log::error!("【致命】{} MiB 映射失败，跳过预留。 / [Fatal] mmap {} MiB failed, skipping.", len / 1024 / 1024, len / 1024 / 1024);
            return None;
        }

        // SAFETY: ptr 已校验非 MAP_FAILED，len 为映射长度；普通用户 RLIMIT_MEMLOCK
        //         很小，失败是预期内，不影响内存安全。
        // SAFETY: ptr validated non-MAP_FAILED, len is mapping length; unprivileged
        //         RLIMIT_MEMLOCK is small, failure is expected and memory-safe.
        let locked = unsafe { mlock(ptr as *const c_void, len) } == 0;
        if locked {
            log::info!("【内存锁定】mlock 成功，{} MiB 已锁定。 / [MemLock] mlock ok, {} MiB pinned.", len / 1024 / 1024, len / 1024 / 1024);
        } else {
            log::warn!("【内存锁定】mlock 被拒（查 RLIMIT_MEMLOCK），降级继续。 / [MemLock] mlock rejected (check RLIMIT_MEMLOCK), degrading.");
        }

        Some(Self { ptr, len, locked })
    }

    /// 高压归还物理页，之后不再保证锁定 / Release pages under pressure; locking no longer guaranteed.
    fn release_pages(&mut self) {
        if self.len == 0 {
            return;
        }
        // SAFETY: ptr/len 仍指向有效映射，MADV_DONTNEED 只丢页内容，不破坏映射。
        // SAFETY: ptr/len still refer to a valid mapping; MADV_DONTNEED only
        //         discards page contents, the mapping itself stays valid.
        unsafe {
            madvise(self.ptr as *mut c_void, self.len, MADV_DONTNEED);
        }
        self.locked = false;
    }

    fn len_mib(&self) -> usize {
        self.len / 1024 / 1024
    }
}

impl Drop for ReserveRegion {
    fn drop(&mut self) {
        if self.ptr.is_null() || self.ptr as *mut c_void == MAP_FAILED {
            return;
        }
        // SAFETY: Drop 只执行一次，不会 double-free；munlock 对未锁定页返回 EINVAL 无害。
        // SAFETY: Drop runs exactly once, no double-free; munlock on an unlocked
        //         page returns EINVAL but is harmless.
        unsafe {
            if self.locked {
                munlock(self.ptr as *const c_void, self.len);
            }
            munmap(self.ptr as *mut c_void, self.len);
        }
        log::info!("【天枢退出】物理内存已释放。 / [TianShu Exit] Physical memory released.");
    }
}

// ───────── SIMD 派发：启动探测一次，unsafe 封锁在此 ─────────
// ───────── SIMD dispatch: detect once at startup, unsafe confined here ─────────

#[derive(Clone, Copy, PartialEq, Eq)]
enum SimdLevel {
    Avx512,
    Avx2,
    Avx,
    Generic,
}

impl SimdLevel {
    fn detect() -> Self {
        if is_x86_feature_detected!("avx512f") {
            Self::Avx512
        } else if is_x86_feature_detected!("avx2") {
            Self::Avx2
        } else if is_x86_feature_detected!("avx") {
            Self::Avx
        } else {
            Self::Generic
        }
    }

    fn name(self) -> &'static str {
        match self {
            Self::Avx512 => "AVX512",
            Self::Avx2 => "AVX2",
            Self::Avx => "AVX",
            Self::Generic => "generic",
        }
    }
}

/// 安全派发器。注意：三个 SIMD 函数体当前是标量，#[target_feature]
/// 不会自动向量化，真正批量 SIMD 在路线图上。
/// Safe dispatcher. Note: the three SIMD bodies are scalar for now;
/// #[target_feature] does not auto-vectorize. Real batch SIMD is on the roadmap.
#[inline]
fn calc_lambda(level: SimdLevel, lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    // SAFETY: SimdLevel 由 detect() 通过 CPUID 验证，与 target_feature 一致，不会 SIGILL。
    match level {
        SimdLevel::Avx512 => unsafe { calc_lambda_avx512(lambda, chi, rho, d_sq, temp) },
        SimdLevel::Avx2   => unsafe { calc_lambda_avx2(lambda, chi, rho, d_sq, temp) },
        SimdLevel::Avx    => unsafe { calc_lambda_avx(lambda, chi, rho, d_sq, temp) },
        SimdLevel::Generic => calc_lambda_generic(lambda, chi, rho, d_sq, temp),
    }
}
// ───────── 数学核心（逐字未动；改一个必须同步其余三个） ─────────
// ───────── Math core (verbatim; any change MUST be mirrored to all four) ─────────

/// NaN / ±Inf → 0，其余夹紧 [0, 100] / NaN / ±Inf → 0, otherwise clamp to [0, 100].
#[inline(always)]
fn sanitize(v: f32) -> f32 {
    if v.is_nan() || v.is_infinite() {
        0.0
    } else {
        v.clamp(K_FLOOR, K_CEIL)
    }
}

/// d² 专用：拦 NaN/Inf/负数，只防溢出，不 clamp 到 [0,100]。
/// d² only: reject NaN/Inf/negative, overflow guard only; NOT clamped to [0,100].
#[inline(always)]
fn sanitize_d_sq(v: f32) -> f32 {
    if v.is_nan() || v.is_infinite() || v < 0.0 {
        0.0
    } else {
        v.min(D_SQ_CEIL)
    }
}

/// λ' = λ·e^(-χ) + ρ·max(d²-500, 0) + ρ·max(T-75, 0)
#[target_feature(enable = "avx512f")]
#[inline]
unsafe fn calc_lambda_avx512(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}

#[target_feature(enable = "avx2")]
#[inline]
unsafe fn calc_lambda_avx2(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}

#[target_feature(enable = "avx")]
#[inline]
unsafe fn calc_lambda_avx(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}

#[inline(always)]
fn calc_lambda_generic(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}
// ───────── 辅助 / Helpers ─────────

/// 默认 64 MiB（F510/GX-218GL 只有 2–4GB，512 会挤爆），上限 1024。
/// Default 64 MiB (F510/GX-218GL have only 2–4GB; 512 would starve them), capped at 1024.
fn reserve_bytes_from_env() -> usize {
    let mb = std::env::var("TIANSHU_RESERVE_MB")
        .ok()
        .and_then(|s| s.parse::<usize>().ok())
        .unwrap_or(64)
        .min(1024);
    mb * 1024 * 1024
}

/// 按 label 挑 CPU 温度，避免 first() 拿到主板/电池/NVMe；找不到退 45℃。
/// Pick CPU temp by label to avoid first() grabbing motherboard/battery/NVMe; fallback 45°C.
fn pick_cpu_temp(components: &Components) -> f32 {
    let raw = components
        .list()
        .iter()
        .find(|c| {
            let l = c.label().to_lowercase();
            l.contains("coretemp")
                || l.contains("k10temp")
                || l.contains("tctl")
                || l.contains("cpu")
                || l.contains("package")
        })
        .map(|c| c.temperature())
        .filter(|t| t.is_finite() && *t > 0.0)
        .unwrap_or(45.0);
    raw.clamp(-40.0, 150.0)
}

// ───────── 主函数（零 unsafe） / main (zero unsafe) ─────────

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    let _ = ctrlc::set_handler(move || {
        r.store(false, Ordering::SeqCst);
    });

    let mut sys = System::new_all();
    let mut components = Components::new_with_refreshed_list();
    let mut region = ReserveRegion::new(reserve_bytes_from_env());

    let level = SimdLevel::detect();
    log::info!("【天枢启动】SIMD: {} / [TianShu Boot] SIMD: {}", level.name(), level.name());

    let (mut lambda, chi, rho) = (LAMBDA_INIT, 0.05f32, 0.1f32);
    let mut tick: u64 = 0;

    while running.load(Ordering::SeqCst) {
        // SAFETY(逻辑): 捕获的 f32/u64 为 Copy，System/Components unwind 后状态一致。
        // SAFETY(logic): captured f32/u64 are Copy; System/Components remain
        //                consistent after unwind.
        let result = catch_unwind(AssertUnwindSafe(|| {
            thread::sleep(Duration::from_millis(100));
            tick = tick.wrapping_add(1);

            // 每 5 秒刷新一次，防日志刷爆磁盘 / Refresh every 5s to avoid log spam.
            if tick % 50 == 0 {
                sys.refresh_cpu();
                sys.refresh_memory();
                components.refresh_list();

                let cpu = sanitize(sys.global_cpu_info().cpu_usage());
                let total = sys.total_memory();
                let mem = if total == 0 {
                    0.0
                } else {
                    sanitize((sys.used_memory() as f32 / total as f32) * 100.0)
                };

                let temp = pick_cpu_temp(&components);

                let d_sq_raw = (100.0 * 20.0 * (-chi).exp()).powi(2)
                    + (cpu + mem).powi(2)
                    + (temp - 75.0).max(0.0).powi(2)
                    + 1.5f32.powi(2);
                let d_sq = sanitize_d_sq(d_sq_raw / D_SQ_SCALE);

                lambda = sanitize(calc_lambda(level, lambda, chi, rho, d_sq, temp));

                log::info!(
                    "K值 - CPU: {:.1}%, MEM: {:.1}%, TEMP: {:.1}℃, d²_raw: {:.0}, d²: {:.1}, λ: {:.2}",
                    cpu, mem, temp, d_sq_raw, d_sq, lambda
                );

                if mem > 85.0 {
                    if let Some(r) = region.as_mut() {
                        r.release_pages();
                        log::warn!("【高压回收】MEM {:.1}%，归还 {} MiB。 / [Pressure] MEM {:.1}%, released {} MiB.", mem, r.len_mib(), mem, r.len_mib());
                    }
                }
            }
        }));

        if result.is_err() {
            log::error!("【熔断】核心循环异常，继续运行... / [Breaker] Core loop panic, continuing...");
        }
    }

    drop(region);
    log::info!("【天枢退出】主循环结束。 / [TianShu Exit] Main loop ended.");
}
