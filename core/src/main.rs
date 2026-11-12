// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2025-2026 紫枢联合组织 / TianShu OS Project
// 硬件级架构：黑板共享内存 + 四组独立状态机 + 中断式事件驱动

use libc::{c_void, madvise, mlock, munlock, munmap, MADV_DONTNEED, MAP_FAILED};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use sysinfo::{Components, System};

// ================= 常量 =================
const K_FLOOR: f32 = 0.0;
const K_CEIL: f32 = 100.0;
const LAMBDA_INIT: f32 = 50.0;

#[inline(always)]
fn sanitize(v: f32) -> f32 {
    if v.is_nan() || v.is_infinite() { 0.0 } else { v.clamp(K_FLOOR, K_CEIL) }
}

// ================= 1. 大黑板 (Blackboard / 共享 SRAM) =================
struct Blackboard {
    // --- 第一组：遥测输入 ---
    pub dt: f32,
    pub cpu_usage: f32,
    pub mem_usage: f32,
    pub io_usage: f32,
    pub cpu_temp: f32,
    pub load_avg: f32,

    // --- 第二组：动力学计算结果 ---
    pub k_val: f32,
    pub lambda: f32,
    pub pi: f32,
    pub memory_i: f32,
    pub glia_x: f32,

    // --- 第三组：事件触发指令 ---
    pub trigger_cleanup: bool,
}

impl Blackboard {
    fn new() -> Self {
        Self {
            dt: 0.1, cpu_usage: 0.0, mem_usage: 0.0, io_usage: 0.0, cpu_temp: 45.0, load_avg: 0.0,
            k_val: 0.0, lambda: LAMBDA_INIT, pi: 1.0, memory_i: 0.0, glia_x: 0.0,
            trigger_cleanup: false,
        }
    }
}

// ================= 2. 内存保护层 (防炸机制) =================
struct ReserveRegion {
    ptr: *mut u8,
    len: usize,
    locked: bool,
}

impl ReserveRegion {
    fn new(len: usize) -> Option<Self> {
        if len == 0 { return None; }
        let ptr = unsafe { libc::mmap(std::ptr::null_mut(), len, libc::PROT_READ | libc::PROT_WRITE, libc::MAP_PRIVATE | libc::MAP_ANONYMOUS, -1, 0) as *mut u8 };
        if ptr as *mut c_void == MAP_FAILED { return None; }
        let locked = unsafe { mlock(ptr as *const c_void, len) } == 0;
        Some(Self { ptr, len, locked })
    }

    fn release_pages(&mut self) {
        if self.len == 0 { return; }
        unsafe { madvise(self.ptr as *mut c_void, self.len, MADV_DONTNEED); }
        self.locked = false;
    }
    
    fn len_mib(&self) -> usize { self.len / 1024 / 1024 }
}

impl Drop for ReserveRegion {
    fn drop(&mut self) {
        if self.ptr.is_null() || self.ptr as *mut c_void == MAP_FAILED { return; }
        unsafe {
            if self.locked { munlock(self.ptr as *const c_void, self.len); }
            munmap(self.ptr as *mut c_void, self.len);
        }
    }
}

fn reserve_bytes_from_env() -> usize {
    let mb = std::env::var("TIANSHU_RESERVE_MB").ok().and_then(|s| s.parse::<usize>().ok()).unwrap_or(64).min(1024);
    mb * 1024 * 1024
}

// ================= 3. 独立计算函数 (只操作黑板) =================

fn group_dynamics(board: &mut Blackboard) {
    // 方程 1：宏观 K 值
    let kc = board.cpu_usage;
    let kg = 0.5; 
    let kr = board.mem_usage;
    let kr1 = board.io_usage;
    let kr2 = board.load_avg; 
    let kn = 0.1;
    board.k_val = (kc + kg + kr + kr1 + kr2 + kn) / 5.0;

    // 方程 2：痛觉退让 λ
    let delta_p = 20.0 * (
        (board.cpu_usage - 0.8).max(0.0) +
        (board.mem_usage - 0.8).max(0.0) +
        (board.io_usage - 0.8).max(0.0)
    );
    let decayed_lambda = board.lambda * (-0.05 * board.dt).exp();
    board.lambda = sanitize((decayed_lambda + delta_p).min(100.0));

    // 方程 3：涌现权重 Π
    let beta = 1.0 - board.cpu_usage;
    let alpha = board.load_avg.min(1.0);
    let raw_pi = board.k_val * beta * (1.0 - alpha) - board.lambda;
    board.pi = raw_pi.max(1.0);

    // 方程 4：海马体预测 I
    let freq = 1.0 / board.dt.max(0.1);
    let decayed_pi = board.pi * (-0.05 * board.dt).exp();
    board.memory_i = decayed_pi * (freq + 1.0).ln();

    // 方程 5：小胶质细胞 X
    let w_gb = board.mem_usage * 16.0;
    let sigma = board.dt * board.cpu_usage;
    let x_base = (w_gb - 10.0).max(0.0) + (sigma - 5.0).max(0.0);
    board.glia_x = x_base.powi(2) * 1.0; 

    // 状态判定
    board.trigger_cleanup = board.glia_x > 100.0 || board.mem_usage > 0.90;
}

// 获取 CPU 温度辅助函数
fn pick_cpu_temp(comps: &Components) -> f32 {
    let raw = comps.list().iter()
        .find(|c| {
            let l = c.label().to_lowercase();
            l.contains("coretemp") || l.contains("k10temp") || l.contains("tctl") || l.contains("cpu") || l.contains("package")
        })
        .map(|c| c.temperature()).filter(|t| t.is_finite() && *t > 0.0).unwrap_or(45.0);
    raw.clamp(-40.0, 150.0)
}

// ================= 4. 主控总线 (线程调度与中断触发) =================

fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    // 全局运行信号
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    let _ = ctrlc::set_handler(move || {
        r.store(false, Ordering::SeqCst);
        log::info!("【天枢】收到退出中断信号...");
    });

    // 初始化共享黑板 (Mutex保护)
    let board = Arc::new(Mutex::new(Blackboard::new()));
    
    // 硬件级中断通道：动作组 -> 清理组
    let (tx_cleanup, rx_cleanup) = mpsc::channel::<()>();

    let mut handles = vec![];

    // ================= 线程 1：采集组 (高频轮询) =================
    let b1 = Arc::clone(&board);
    let r1 = Arc::clone(&running);
    handles.push(thread::spawn(move || {
        let mut sys = System::new_all();
        let mut comps = Components::new_with_refreshed_list();
        let mut last_time = Instant::now();

        while r1.load(Ordering::SeqCst) {
            let _ = catch_unwind(AssertUnwindSafe(|| {
                sys.refresh_cpu();
                sys.refresh_memory();
                comps.refresh_list();

                let now = Instant::now();
                let dt = now.duration_since(last_time).as_secs_f32();
                last_time = now;

                // 写入黑板（短暂加锁）
                let mut b = b1.lock().unwrap_or_else(|e| e.into_inner());
                b.dt = dt;
                b.cpu_usage = sys.global_cpu_info().cpu_usage() / 100.0;
                b.mem_usage = if sys.total_memory() == 0 { 0.0 } else { sys.used_memory() as f32 / sys.total_memory() as f32 };
                b.load_avg = (sysinfo::System::load_average().one / 8.0).min(1.0) as f32;
                b.cpu_temp = pick_cpu_temp(&comps);
            }));
            thread::sleep(Duration::from_millis(250));
        }
    }));

    // ================= 线程 2：动力学计算组 (FSM核心) =================
    let b2 = Arc::clone(&board);
    let r2 = Arc::clone(&running);
    handles.push(thread::spawn(move || {
        while r2.load(Ordering::SeqCst) {
            let _ = catch_unwind(AssertUnwindSafe(|| {
                let mut b = b2.lock().unwrap_or_else(|e| e.into_inner());
                group_dynamics(&mut b); // 算 5 个微积分方程
            }));
            thread::sleep(Duration::from_millis(500));
        }
    }));

    // ================= 线程 3：动作与汇报组 (看门狗) =================
    let b3 = Arc::clone(&board);
    let r3 = Arc::clone(&running);
    let tx = tx_cleanup.clone();
    handles.push(thread::spawn(move || {
        while r3.load(Ordering::SeqCst) {
            let _ = catch_unwind(AssertUnwindSafe(|| {
                let b = b3.lock().unwrap_or_else(|e| e.into_inner());
                
                log::info!(
                    "【动力学】K:{:.2} | λ:{:.2} | Π:{:.2} | I:{:.2} | X:{:.2} (CPU:{:.1}%, TEMP:{:.1}℃)",
                    b.k_val, b.lambda, b.pi, b.memory_i, b.glia_x, b.cpu_usage * 100.0, b.cpu_temp
                );

                // 满足阈值，拉高中断信号！
                if b.trigger_cleanup {
                    let _ = tx.send(()); 
                }
            }));
            thread::sleep(Duration::from_secs(2));
        }
    }));

    // ================= 线程 4：物理超度组 (中断驱动) =================
    let r4 = Arc::clone(&running);
    handles.push(thread::spawn(move || {
        let mut region = ReserveRegion::new(reserve_bytes_from_env());
        
        while r4.load(Ordering::SeqCst) {
            // 阻塞等待中断信号，超时 500ms 醒来检查一下退出标志
            if let Ok(_) = rx_cleanup.recv_timeout(Duration::from_millis(500)) {
                if let Some(ref mut reg) = region {
                    reg.release_pages();
                    log::warn!("【高压回收】收到事件中断，MADV_DONTNEED 归还 {} MiB。", reg.len_mib());
                }
            }
        }
    }));

    // 阻塞主线程，等待各个状态机退出
    for handle in handles {
        let _ = handle.join();
    }

    log::info!("【天枢退出】所有线程安全结束，物理内存已释放。");
}
