<div align="center">

# TianShu OS

### Emergent OS

**基于五大微积分动力学方程推导的纯 Rust 底层调度引擎**

![Arch](https://img.shields.io/badge/base-Arch%20Linux-1793D1?logo=arch-linux&logoColor=white)
![Rust](https://img.shields.io/badge/engine-Rust-CE422B?logo=rust&logoColor=white)
![UEFI](https://img.shields.io/badge/boot-systemd--boot-0A0A0A?logo=systemd&logoColor=white)

</div>

---

## 定位

| 维度 | 决策 |
|------|------|
| 基座 | Arch Linux（archiso releng 模板） |
| 引导 | systemd-boot（UEFI-only，无 GRUB） |
| 引擎 | `tianshu_core` — 纯 Rust、musl 静态链接、x86-64 基线编译 |
| 桌面 | KDE Plasma 6 + SDDM 紫罗兰主题 |
| 商店 | `pamac-aur` + `yay`（archlinuxcn） |
| 自适应 | zram（低内存） + TLP（电源策略）双形态 |

## 核心架构

- **AVX 指令集四路派发**：`avx512f` / `avx2` / `avx` / 通用实现，运行时 `is_x86_feature_detected!` 动态选择。
- **防炸三件套**：`catch_unwind` 熔断 + 浮点 `NaN/Inf` 拦截 + `.clamp(0, 100)` 归一化。
- **物理内存锁定**：`mmap` 512 MiB + `mlock` 常驻；高压时 `madvise(MADV_DONTNEED)` 自动回收。
- **五大微积分动力学方程**：调度核心由五组耦合常微分方程推导而来，确保在任意硬件负载下 K 值收敛于安全域。具体公式为商业机密，不公开。

## 紫罗兰视觉规范（三阶色系）

| 阶 | 用途 | RGB | HEX |
|----|------|-----|-----|
| 一 | 主背景 | 226, 208, 232 | `#E2D0E8` |
| 二 | 侧边栏 | 216, 209, 230 | `#D8D1E6` |
| 三 | 选中态 | 206, 197, 219 | `#CEC5DB` |

KWin 毛玻璃 12px 圆角 + `ForceLowest` 极低延迟 + SDDM 无时钟登录。

## 构建

```bash
# 触发云端构建（或推送到 main 自动触发）
gh workflow run build.yml

# 本地>  本地校验
cd core && cargo check --target x86_64-unknown-linux-musl
bash -n scripts/customize_airootfs.sh
```

产物：`TianShu-OS-ISO` Artifact（`.iso`），systemd-boot 引导，可直接 `dd` 或 Rufus 烧录。

## 商业授权

<div align="center">

**人民币 100 元永久买断制**

一次性付费，永久使用、永久更新，无订阅、无远程验证。

</div>
