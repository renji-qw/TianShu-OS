<div align="center">

# TianShu OS

### Emergent OS (涌现式操作系统)

**基于五大微积分动力学方程推导的纯 Rust 底层调度引擎**

![Arch](https://img.shields.io/badge/base-Arch%20Linux-1793D1?logo=arch-linux&logoColor=white)
![Rust](https://img.shields.io/badge/engine-Rust-CE422B?logo=rust&logoColor=white)
![UEFI](https://img.shields.io/badge/boot-systemd--boot-0A0A0A?logo=systemd&logoColor=white)
![License](https://img.shields.io/badge/license-AGPLv3%20%2B%20Custom-blue)

</div>

---

## 项目背景 (The Story)

天枢OS 诞生于一次对传统 Linux 内核调度机制的重构尝试。主导开发者耗时 **4 个月**自学微积分与动力学模型，独立推导出五组耦合常微分方程，旨在用“涌现式”的数学反馈取代生硬的离散状态机，让老旧硬件焕发新生。

系统的 UI 视觉采用三阶紫罗兰轻奢配色（Lilac），灵感源自西北清晨自然光下的紫丁香。这不仅是一套系统，更是一件理科生极致浪漫的数字艺术品。

## 定位 (System Overview)

| 维度 | 决策 |
|------|------|
| **基座** | Arch Linux (archiso releng 模板) |
| **引导** | systemd-boot (UEFI-only, 无 GRUB) |
| **引擎** | `tianshu_core` — 纯 Rust、musl 静态链接、x86-64 基线编译 |
| **桌面** | KDE Plasma 6 + SDDM 深度定制紫罗兰主题 |
| **商店** | `pamac-aur` + `yay` (集成 archlinuxcn 源) |
| **自适应** | ZRAM (低内存优化) + TLP (电源策略) 双形态 |

## 核心架构与源码 (Core Architecture)

*源码全量公开，欢迎全球极客阅读与学习（商用请严格遵守授权协议）：*

*   **五大微积分动力学方程**：调度核心位于 `core/src/main.rs`。由五组耦合的常微分方程推导而来，确保在任意硬件负载下宏观 K 值收敛于安全域。
*   **AVX 指令集四路派发**：包含 `avx512f` / `avx2` / `avx` / 通用实现，运行时通过 `is_x86_feature_detected!` 动态选择最优路径。
*   **防炸三件套**：`catch_unwind` 熔断包裹主循环 + 浮点 `NaN/Inf` 严格拦截 + `.clamp(0, 100)` 归一化锁死区间。
*   **物理内存锁定**：`mmap` 512 MiB 并配合 `mlock` 常驻物理内存；高压时通过 `madvise(MADV_DONTNEED)` 自动回收。

## 视觉规范 (Visual Identity)

| 阶 | 用途 | RGB | HEX |
|----|------|-----|-----|
| 一 | 主背景 | 226, 208, 232 | `#E2D0E8` |
| 二 | 侧边栏 | 216, 209, 230 | `#D8D1E6` |
| 三 | 选中态 | 206, 197, 219 | `#CEC5DB` |

*   **桌面环境**：KWin 开启全局高强度毛玻璃、12px 柔和圆角、`ForceLowest` 极低渲染延迟。
*   **登录界面**：SDDM 无时钟极简登录，纯紫罗兰渐变微光。

## 授权与商业化 (License & Commercial)

本项目代码**全量公开**，采用 **AGPLv3 + 附加条款** 的双许可（Dual-Licensing）模式。详情请参阅仓库根目录的 [LICENSE](./LICENSE) 文件。

1.  **个人与教育用途**：完全免费。任何人都可以下载、修改、学习，或用于非商业的学术研究。
2.  **商业闭源豁免 (100元永久买断制)**：依据 AGPLv3 第 7 条，任何企业或实体若希望豁免 AGPLv3 的开源“传染性”，将其用于闭源商业环境，必须支付 **100 元人民币/每实体** 的永久买断授权费。一次性付费，永久使用、永久更新，无订阅、无远程验证。
    *   *获取商业授权，请联系作者：GitHub @renji-qw*
3.  **绝对禁止 AI 训练**：未经书面明确授权，严禁任何大语言模型（LLMs）或自动化爬虫抓取、提取本仓库源码（特别是 `core/` 目录）用于机器学习模型训练。

---
<div align="center">
  <p>© 2026 紫枢联合组织 (Zishu Alliance) - 天枢OS项目组.</p>
  <p><i>"让这朵紫丁香，在每一块垂死的硅片上重新绽放。"</i></p>
</div>
