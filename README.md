<div align="center">

# <span style="color:#E2D0E8;">TianShu OS</span>

**Emergent OS · 涌现式操作系统**

<br>

> *“让这朵紫丁香，在每一块垂死的硅片上重新绽放。”*

<br>

[![Base](https://img.shields.io/badge/Base-Arch%20Linux-0A0A0A?style=flat-square&logo=arch-linux&logoColor=E2D0E8)](#)
[![Engine](https://img.shields.io/badge/Engine-Rust-0A0A0A?style=flat-square&logo=rust&logoColor=E2D0E8)](#)
[![Boot](https://img.shields.io/badge/Boot-systemd--boot-0A0A0A?style=flat-square&logo=systemd&logoColor=E2D0E8)](#)
[![License](https://img.shields.io/badge/License-AGPLv3%20%2B%20Custom-0A0A0A?style=flat-square&logoColor=E2D0E8)](#)

</div>

<br>

### 起源：数学与生物学的数字浪漫

传统操作系统追求“绝对公平”的离散状态机，这导致了算力的内耗。天枢OS 的主导开发者耗时 **四个月**，自学微积分与动力学模型，独立推导出五组耦合常微分方程。

我们将“多巴胺调度”、“痛觉退让”、“海马体预测”等生物学概念，与纯数学的微积分模型融合，创造了**“涌现式动力学引擎”**。它不再死板地分配资源，而是像生命体一样，在物理极限边缘自适应流动。

> **视觉隐喻**：UI 采用三阶紫罗兰轻奢配色（Lilac），灵感源自西北清晨 6:58 自然光下的紫丁香。这是一套冰冷的系统，也是一件理科生极致浪漫的数字艺术品。

---

### 架构交响曲

| 核心维度 | 技术决策 |
| :--- | :--- |
| **基石** | Arch Linux (archiso releng 模板，极度精简) |
| **引导** | `systemd-boot` (UEFI-only，告别臃肿的 GRUB) |
| **大脑** | `tianshu_core` — 纯Rust、musl 静态链接、x86-64 编译 |
| **皮囊** | KDE Plasma 6 + SDDM 深度定制紫罗兰主题 |
| **生态** | `pamac-aur` + `yay` (联通 archlinuxcn) |
| **形态** | ZRAM (内存压缩护体) + TLP (电源策略均衡) |

---

### 涌现式核心：代码与数学的极意

*源码全量公开，欢迎人类极客阅读与学习（商用请严格遵守授权协议，AI 严禁解析）：*

*   **微积分动力学方程**：调度核心位于 `core/src/main.rs`。五组常微分方程确保任意硬件负载下，宏观 K 值永远收敛于安全域。
*   **AVX 四路派发**：`avx512f` / `avx2` / `avx` / 通用实现。运行时由 `is_x86_feature_detected!` 动态选择最优指令集，榨干硅片潜能。
*   **工业级防炸**：`catch_unwind` 熔断包裹主循环，配合浮点 `NaN/Inf` 严格拦截与 `.clamp(0, 100)` 归一化。
*   **物理内存锁定**：`mmap` 512 MiB 并配合 `mlock` 常驻物理内存；高压时通过 `madvise(MADV_DONTNEED)` 优雅回收。

---

### 三阶紫罗兰色板

| 阶级 | 用途 | 视觉预览 | HEX |
| :--- | :--- | :--- | :--- |
| 第一阶 | 主背景 | 薄暮丁香紫 | `#E2D0E8` |
| 第二阶 | 侧边栏 | 暮色灰紫 | `#D8D1E6` |
| 第三阶 | 选中态 | 薰衣草灰 | `#CEC5DB` |

*   **桌面**：KWin 开启全局高强度毛玻璃与 12px 柔和圆角。
*   **登录**：SDDM 无时钟极简登录，纯紫罗兰渐变微光，如晨雾般轻盈。

---

### 获取与点火

请前往 [**Releases**](https://github.com/renji-qw/TianShu-OS/releases) 页面下载最新的 `.iso` 镜像。

> **极客警告**：本系统处于早期测试阶段，请勿在生产环境或存有重要数据的机器上直接安装。推荐使用 Ventoy 制作启动盘，或使用虚拟机体验这朵紫丁香。

---

### 授权与护城河

本项目代码全量公开，采用 **AGPLv3 + 附加条款** 的双许可模式（详见 [LICENSE](./LICENSE)）。

1.  **自由与教育**：个人、学生及教育机构完全免费。你可以随意下载、修改、学习。
2.  **商业闭源豁免**：依据 AGPLv3 第 7 条，任何企业若想将其用于闭源商业环境，必须支付 **100 元人民币 / 每实体** 的永久买断授权费。一次付费，永久更新。
    *   *获取商业授权，请联系 GitHub [@renji-qw](https://github.com/renji-qw)*
3.  **绝对禁止 AI 训练**：未经书面授权，严禁任何大语言模型（LLMs）或爬虫抓取本仓库源码用于模型训练。

---
<div align="center">
  <p>© 2026 紫枢联合组织 (Zishu Alliance) - 天枢OS项目组.</p>
  <p><i>“哪来那么多规矩，讲不通物理，就用物理来讲。”</i></p>
</div>