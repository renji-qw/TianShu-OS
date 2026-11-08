use libc::{c_void, madvise, mlock, MADV_DONTNEED, MAP_FAILED};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use sysinfo::{Components, System};

/// 预留物理内存：512 MiB
const RESERVE_BYTES: usize = 512 * 1024 * 1024;
/// K 值安全域
const K_FLOOR: f32 = 0.0;
const K_CEIL: f32 = 100.0;

/// 统一防炸出口：NaN / ±Inf 一律归零，其余夹紧到 [0, 100]
#[inline(always)]
fn sanitize(v: f32) -> f32 {
    if v.is_nan() || v.is_infinite() {
        0.0
    } else {
        v.clamp(K_FLOOR, K_CEIL)
    }
}

/// λ 公式（与原始实现逐字等价，禁止改动数学逻辑）
/// λ' = λ·e^(-χ) + ρ·max(d²-500, 0) + ρ·max(T-75, 0)
#[target_feature(enable = "avx512f")]
#[inline(always)]
unsafe fn calc_lambda_avx512(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}

#[target_feature(enable = "avx2")]
#[inline(always)]
unsafe fn calc_lambda_avx2(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}

#[target_feature(enable = "avx")]
#[inline(always)]
unsafe fn calc_lambda_avx(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}

#[inline(always)]
fn calc_lambda_generic(lambda: f32, chi: f32, rho: f32, d_sq: f32, temp: f32) -> f32 {
    lambda * (-chi).exp() + rho * (d_sq - 500.0).max(0.0) + rho * (temp - 75.0).max(0.0)
}

fn main() {
    env_logger::init();

    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    let _ = ctrlc::set_handler(move || {
        r.store(false, Ordering::SeqCst);
    });

    let mut sys = System::new_all();
    let mut components = Components::new_with_refreshed_list();

    // 512 MiB 匿名映射：先判空 / MAP_FAILED，再锁定物理页
    let mem_ptr = unsafe {
        libc::mmap(
            std::ptr::null_mut(),
            RESERVE_BYTES,
            libc::PROT_READ | libc::PROT_WRITE,
            libc::MAP_PRIVATE | libc::MAP_ANONYMOUS,
            -1,
            0,
        ) as *mut u8
    };

    if mem_ptr.is_null() || mem_ptr as *mut c_void == MAP_FAILED {
        log::error!("【致命错误】512MiB 内存映射失败，安全退出！");
        return;
    }

    // mlock 锁定常驻物理页；失败不算致命（受 RLIMIT_MEMLOCK / CAP_IPC_LOCK 限制）
    let locked = unsafe { mlock(mem_ptr as *const c_void, RESERVE_BYTES) } == 0;
    if locked {
        log::info!("【内存锁定】mlock 成功，512MiB 已锁定于物理内存。");
    } else {
        log::warn!("【内存锁定】mlock 被内核拒绝（RLIMIT_MEMLOCK 限制），降级为普通映射继续运行。");
    }

    let has_avx512 = is_x86_feature_detected!("avx512f");
    let has_avx2 = is_x86_feature_detected!("avx2");
    let has_avx = is_x86_feature_detected!("avx");
    log::info!(
        "【天枢启动】AVX512: {}, AVX2: {}, AVX: {}",
        has_avx512,
        has_avx2,
        has_avx
    );

    let (mut lambda, chi, rho) = (0.0f32, 0.05f32, 0.1f32);
    let mut tick: u64 = 0;

    while running.load(Ordering::SeqCst) {
        let result = catch_unwind(AssertUnwindSafe(|| {
            thread::sleep(Duration::from_millis(100));
            tick = tick.wrapping_add(1);

            if tick % 5 == 0 {
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

                // temperature() 返回 f32，读取失败时为 NaN
                let raw_temp = components
                    .list()
                    .first()
                    .map(|c| c.temperature())
                    .unwrap_or(45.0);
                let temp = if raw_temp.is_nan() || raw_temp.is_infinite() || raw_temp <= 0.0 {
                    45.0
                } else {
                    raw_temp.clamp(-40.0, 150.0)
                };

                let d_sq = (100.0 * 20.0 * (-chi).exp()).powi(2)
                    + (cpu + mem).powi(2)
                    + (temp - 75.0).max(0.0).powi(2)
                    + 1.5f32.powi(2);
                let d_sq = sanitize(d_sq);

                let new_lambda = if has_avx512 {
                    unsafe { calc_lambda_avx512(lambda, chi, rho, d_sq, temp) }
                } else if has_avx2 {
                    unsafe { calc_lambda_avx2(lambda, chi, rho, d_sq, temp) }
                } else if has_avx {
                    unsafe { calc_lambda_avx(lambda, chi, rho, d_sq, temp) }
                } else {
                    calc_lambda_generic(lambda, chi, rho, d_sq, temp)
                };

                lambda = sanitize(new_lambda);
                log::info!(
                    "K值监控 - CPU: {:.1}%, MEM: {:.1}%, TEMP: {:.1}℃, λ: {:.2}",
                    cpu,
                    mem,
                    temp,
                    lambda
                );

                if mem > 85.0 {
                    unsafe {
                        madvise(mem_ptr as *mut c_void, RESERVE_BYTES, MADV_DONTNEED);
                    }
                    log::warn!(
                        "【高压回收】内存占用 {:.1}%，已 madvise(MADV_DONTNEED) 归还 512MiB。",
                        mem
                    );
                }
            }
        }));

        if result.is_err() {
            log::error!("熔断捕获异常，系统继续运行...");
        }
    }

    unsafe {
        libc::munmap(mem_ptr as *mut c_void, RESERVE_BYTES);
    }
    log::info!("【天枢退出】资源已释放。");
}
