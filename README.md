<div align="center">

<br>

# <span style="font-family: 'Songti SC', 'Noto Serif CJK SC', serif; letter-spacing: 6px; font-size: 3em; color: #2A2438;">天 枢 O S</span>

**Emergent OS · 涌现式操作系统**<br>
<span style="color: #8B809A; font-size: 0.9em;">东方道学底色 · 紫罗兰极简美学</span>

<br><br>

> *“玄之又玄，众妙之门。”*

<br>

[![Star](https://img.shields.io/badge/结个善缘-Star-E2D0E8?style=flat-square&logoColor=2A2438&labelColor=E2D0E8)](#)
[![License](https://img.shields.io/badge/AGPL--3.0-开源-2A2438?style=flat-square&labelColor=D8D1E6)](#)

<br>

<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 60%; margin: 30px auto;">

</div>

<br>

> ### 序 · 缘起
> 
> *“上善若水。水善利万物而不争。”*
>
> 现代操作系统往往用强制公平的算法切割算力，冰冷且焦躁。
> 
> 我是一名研究毒理与环境科学的道士，也是一名摄影生。在无数次被工业极客系统的黑框折磨后，我决定自己造一个。以西北清晨 6:58 自然光下的紫丁香为引，便有了这方天地。

<br>

> ### 视 · 紫气东来
> 
> *“为学日益，为道日损。”*
>
> 摒弃一切高饱和度的刺眼色彩。系统全局仅保留三种极简阶调，配合 KDE Plasma 6 的全局毛玻璃与 12px 柔和圆角。

<br>

<div align="center">

| 色彩阶级 | 视觉呈现 | 应用场景 | HEX 色值 |
| :---: | :--- | :--- | :--- |
| **第一阶** | <div align="center"><div style="width:100px;height:30px;background-color:#E2D0E8;border-radius:6px;"></div></div> | 薄暮丁香紫 (主背景) | `#E2D0E8` |
| **第二阶** | <div align="center"><div style="width:100px;height:30px;background-color:#D8D1E6;border-radius:6px;"></div></div> | 暮色灰紫 (侧边栏) | `#D8D1E6` |
| **第三阶** | <div align="center"><div style="width:100px;height:30px;background-color:#CEC5DB;border-radius:6px;"></div></div> | 薰衣草灰 (选中态) | `#CEC5DB` |

</div>

<br>

<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 80%; margin: 40px auto;">

> ### 基 · 筑基
> 
> *“飘风不终朝，骤雨不终日。”*
>
> 原生 Arch 的滚动更新极易让系统崩坏（滚挂）。故重构底盘为 **CachyOS**。底层强制 Btrfs 筋骨，每逢更新，必先静默打一重「快照」。若真遇外邪入侵致系统崩溃，只需在 GRUB 中一键逆转，瞬间恢复如初。
> 
> 放弃了对 UEFI 极度挑剔的 `systemd-boot`，回归宽厚包容的 `GRUB`。兼容 Windows 双系统，是为顺应世间万物的法门。

<br>

> ### 魂 · 阵图
> 
> *“致虚极，守静笃。万物并作，吾以观复。”*
>
> 天枢 OS 的灵魂 `tianshu_core`，是一套由纯 Rust 手工锻造的动力学引擎。它摒弃了传统的单线程阻塞，采用了硬件级的**「四象阵」**：中宫置一「黑板」，青龙（采集）、朱雀（计算）、白虎（动作）、玄武（超度）四组线程借由事件中断并行不悖。

<br>

<div align="center">

**五行演算 · 法阵**

$$
K = \frac{K_c + K_g + K_r + K_{r1} + K_{r2} + K_n}{5}
$$

$$
\lambda = \min\left(100, \lambda \cdot e^{-0.05\Delta t} + \Delta P\right)
$$

$$
\Pi = \max(1, K \cdot \beta \cdot (1 - \alpha) - \lambda)
$$

$$
I = \Pi \cdot e^{-0.05\Delta t} \cdot \ln(Freq + 1)
$$

$$
X = \left( \max(0, w - 10) + \max(0, \Sigma - 5) \right)^2 \cdot (1 + \eta)
$$

</div>

<br>

> *注：为防止法阵崩溃，代码皆被 `catch_unwind` 护心咒包裹，并辅以 `NaN/Inf` 浮点拦截。*

<br>

<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 80%; margin: 40px auto;">

> ### 器 · 持修
> 
> *“少则得，多则惑。”*
>
> 天枢 OS 的镜像，被极力克制在 **1.5 GB**。
> 
> 我们拒绝在镜像中塞满冗余商店与无用驱动。插盘点火，直入紫罗兰幻境。桌面唯有一枚**「安装天枢 OS」**的符印。双击启动图形向导，在写入磁盘的时光里，安装器会在后台自动网罗输入法等生态。
> 
> 装完即用，不染纤尘。

<br>

> **告诫**：此版本尚在筑基期（Beta 测试），切勿装于承载你毕生心血的生产力主力机上。

<br>

<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 60%; margin: 40px auto;">

<br>

<div align="center">
<h3>Q & A · 叩问玄机</h3>
</div>

<details>
<summary><b>问：此系统有何硬件门槛？</b></summary>
<br>
> 答：极轻。1G 内存可开机，2G 内存可顺畅运转毛玻璃。然，实体机测试请用闲置旧物，切勿拿存有毕业论文的机器试法。
</details>

<details>
<summary><b>问：为何非要联网下载生态？</b></summary>
<br>
> 答：少则得，多则惑。磁盘写入的二十多分钟，足够安装器在后台吸取你所需的天地灵气（网络包）。强行塞满 U 盘，徒增累赘。
</details>

<details>
<summary><b>问：非科班出身，如何保 Rust 内核不崩？</b></summary>
<br>
> 答：修道之人，讲究千锤百炼。除了多线程中宫架构，代码在云端经历了 GitHub Actions 千百次的雷劫。若遇外魔（Bug），欢迎提 PR 助我除魔。
</details>

<details>
<summary><b>问：此法宝，作价几何？</b></summary>
<br>
> 答：上善若水。完全开源，完全免费（AGPL-3.0-only）。你若有缘，点个 Star 即可；若想同行，随时欢迎。
</details>

<br>

<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 60%; margin: 30px auto;">

<div align="center">
  <sub>© 2026 紫枢联合组织 (Zishu Alliance)</sub><br>
  <sub><i>“讲不通物理，就用物理来讲。”</i></sub>
</div>
