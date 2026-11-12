<div align="center">

<img src="https://capsule-render.vercel.app/api?type=waving&color=0:E2D0E8,50:D8D1E6,100:CEC5DB&text=TianShu%20OS&desc=%E5%A4%A9%E6%9E%A2%20%C2%B7%20%E6%B6%8C%E7%8E%B0%E5%BC%8F%E6%93%8D%E4%BD%9C%E7%B3%BB%E7%BB%9F&fontColor=2A2438&fontSize=60&descSize=16&descAlignY=70&animation=twinkling" width="100%" />

*“玄之又玄，众妙之门。”*

[![Star](https://img.shields.io/badge/Star-结个善缘-E2D0E8?style=flat-square&logo=github&logoColor=0A0A0A&labelColor=E2D0E8)](#)
[![License](https://img.shields.io/badge/License-AGPL--3.0-0A0A0A?style=flat-square)](#)

</div>

---

### 序 · 缘起：紫气东来

*“上善若水。水善利万物而不争。”*

现代操作系统往往用强制公平的算法切割算力，冰冷且焦躁。我是一名研究毒理与环境科学的道士，也是一名摄影生。在无数次被工业极客系统的黑框折磨后，我决定自己造一个。

以西北清晨 6:58 自然光下的紫丁香为引，便有了这方天地。

<br>

<div align="center">

### 视觉 · 三阶紫罗兰

摒弃一切高饱和度的刺眼色彩，系统全局仅保留三种极简阶调，配合 KDE Plasma 6 的全局毛玻璃与 12px 柔和圆角。

| 色彩阶级 | 视觉呈现 | 应用场景 | HEX 色值 |
| :---: | :--- | :--- | :--- |
| **第一阶** | <div align="center"><div style="width:80px;height:30px;background-color:#E2D0E8;border-radius:4px;"></div></div> | 薄暮丁香紫 (主背景) | `#E2D0E8` |
| **第二阶** | <div align="center"><div style="width:80px;height:30px;background-color:#D8D1E6;border-radius:4px;"></div></div> | 暮色灰紫 (侧边栏) | `#D8D1E6` |
| **第三阶** | <div align="center"><div style="width:80px;height:30px;background-color:#CEC5DB;border-radius:4px;"></div></div> | 薰衣草灰 (选中态) | `#CEC5DB` |

</div>

---

### 基 · 筑基：厚德载物

*“飘风不终朝，骤雨不终日。”*

原生 Arch 的滚动更新极易让系统崩坏（滚挂）。故重构底盘为 **CachyOS**。
底层强制 Btrfs 筋骨，每逢更新，必先静默打一重“快照”。若真遇外邪入侵致系统崩溃，只需在 GRUB 中一键逆转，瞬间恢复如初。

放弃了对 UEFI 极度挑剔的 `systemd-boot`，回归宽厚包容的 `GRUB`。兼容 Windows 双系统，是为顺应世间万物的法门。

---

### 魂 · 阵图：中宫黑板与五行演算

*“致虚极，守静笃。万物并作，吾以观复。”*

天枢 OS 的灵魂（`tianshu_core`），是一套由纯 Rust 手工锻造的动力学引擎。
它摒弃了传统的单线程阻塞，采用了硬件级的**“四象阵”**：中宫置一“黑板”，青龙（采集）、朱雀（计算）、白虎（动作）、玄武（超度）四组线程借由事件中断并行不悖。

在此阵图之上，手推五组微积分动力学方程，模拟天地生灵的代谢（全量实装）：

<div align="center">

**一 · 宏观评估 (K)**
$$
K = \frac{K_c + K_g + K_r + K_{r1} + K_{r2} + K_n}{5}
$$

**二 · 痛觉退让 (\(\lambda\))**
$$
\lambda = \min\left(100, \lambda \cdot e^{-0.05\Delta t} + \Delta P\right)
$$

**三 · 涌现之气 (\(\Pi\))**
$$
\Pi = \max(1, K \cdot \beta \cdot (1 - \alpha) - \lambda)
$$

**四 · 海马预测 (I)**
$$
I = \Pi \cdot e^{-0.05\Delta t} \cdot \ln(Freq + 1)
$$

**五 · 小胶质清道 (\(X\))**
$$
X = \left( \max(0, w - 10) + \max(0, \Sigma - 5) \right)^2 \cdot (1 + \eta)
$$
</div>

*注：为防止法阵崩溃，代码皆被 `catch_unwind` 护心咒包裹，并辅以 `NaN/Inf` 浮点拦截。*

---

### 器 · 持修：少则得，多则惑

*“为学日益，为道日损。”*

天枢 OS 的镜像，被极力克制在 **1.5 GB**。

我们拒绝在镜像中塞满冗余商店与无用驱动。插盘点火，直入紫罗兰幻境。桌面唯有一枚**「安装天枢 OS」**的符印。双击启动图形向导，在写入磁盘的时光里，安装器会于后台自动网罗输入法等生态。

装完即用，不染纤尘。

> **告诫**：此版本尚在筑基期（Beta 测试），切勿装于承载你毕生心血的生产力主力机上。

---

### 问 · 叩问玄机

<details>
<summary><b>问：此系统有何硬件门槛？</b></summary>
<p>答：极轻。1G 内存可开机，2G 内存可顺畅运转毛玻璃。然，实体机测试请用闲置旧物，切勿拿存有毕业论文的机器试法。</p>
</details>

<details>
<summary><b>问：为何非要联网下载生态？</b></summary>
<p>答：少则得，多则惑。磁盘写入的二十多分钟，足够安装器在后台吸取你所需的天地灵气（网络包）。强行塞满 U 盘，徒增累赘。</p>
</details>

<details>
<summary><b>问：非科班出身，如何保 Rust 内核不崩？</b></summary>
<p>答：修道之人，讲究千锤百炼。代码在云端经历了 GitHub Actions 千百次的雷劫。若遇外魔（Bug），欢迎提 PR 助我除魔。</p>
</details>

<details>
<summary><b>问：此法宝，作价几何？</b></summary>
<p>答：上善若水。完全开源，完全免费（AGPL-3.0-only）。你若有缘，点个 Star 即可；若想同行，随时欢迎。</p>
</details>

<br>

<div align="center">

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:E2D0E8,50:D8D1E6,100:CEC5DB&height=100&section=footer&text=%E2%80%9C%E8%AE%B2%E4%B8%8D%E9%80%9A%E7%89%A9%E7%90%86%EF%BC%8C%E5%B0%B1%E7%94%A8%E7%89%A9%E7%90%86%E6%9D%A5%E8%AE%B2%E3%80%82%E2%80%9D&fontSize=24&fontColor=2A2438" width="100%" />

<sub>© 2026 紫枢联合组织 (Zishu Alliance)</sub>

</div>
