<br>
<div align="center">

<span style="font-family: 'Songti SC', 'Noto Serif CJK SC', serif; font-size: 3.2em; letter-spacing: 10px; color: #2A2438;">天 枢 O S</span>

<br><br>

<span style="font-size: 0.9em; letter-spacing: 2px; color: #8B809A;">Emergent OS · 涌现式操作系统 · 道法自然</span>

<br><br>

> *“玄之又玄，众妙之门。”*

<br>

[![Star](https://img.shields.io/badge/结个善缘-Star-E2D0E8?style=flat-square&logoColor=2A2438&labelColor=E2D0E8)](#)
[![License](https://img.shields.io/badge/AGPL--3.0-开源-2A2438?style=flat-square&labelColor=D8D1E6)](#)

</div>

<br>
<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 40%; margin: 40px auto;">
<br>

<div align="center" style="color: #666; font-size: 0.95em; line-height: 2;">
现代操作系统往往用强制公平的算法切割算力，冰冷且焦躁。<br>
我是一名研究毒理与环境科学的道士，也是一名摄影生。<br>
在无数次被工业极客系统的黑框折磨后，我决定自己造一个。<br>
以西北清晨 6:58 自然光下的紫丁香为引，便有了这方天地。
</div>

<br>
<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 80%; margin: 40px auto;">
<br>

<h3 align="center" style="color: #2A2438; font-weight: normal; letter-spacing: 4px;">视 · 紫 气 东 来</h3>

<div align="center" style="color: #666; font-size: 0.9em; margin-bottom: 20px;">
摒弃一切高饱和度的刺眼色彩。系统全局仅保留三种极简阶调，配合 KDE Plasma 6 的全局毛玻璃。
</div>

<div align="center">

| 阶 级 | 视 觉 呈 现 | 应 用 场 景 | HEX |
| :---: | :--- | :--- | :--- |
| **一** | <div style="width:120px;height:24px;background-color:#E2D0E8;border-radius:4px;"></div> | 薄暮丁香紫 (主背景) | `#E2D0E8` |
| **二** | <div style="width:120px;height:24px;background-color:#D8D1E6;border-radius:4px;"></div> | 暮色灰紫 (侧边栏) | `#D8D1E6` |
| **三** | <div style="width:120px;height:24px;background-color:#CEC5DB;border-radius:4px;"></div> | 薰衣草灰 (选中态) | `#CEC5DB` |

</div>

<br>
<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 80%; margin: 40px auto;">
<br>

<h3 align="center" style="color: #2A2438; font-weight: normal; letter-spacing: 4px;">魂 · 阵 图 与 玄 机</h3>

<div align="center" style="color: #666; font-size: 0.9em; line-height: 2; max-width: 600px; margin: 0 auto;">
系统灵魂 <code>tianshu_core</code> 由纯 Rust 锻造。<br>
摒弃单线程阻塞，采用硬件级「四象阵」：中宫黑板，四组线程借由事件中断并行不悖。<br>
底层重构为 <b>CachyOS</b>，自带 Btrfs 快照防滚挂，兼容 Windows 双系统。
<br><br>
<blockquote style="border-left: 2px solid #E2D0E8; margin: 20px auto; padding: 10px; color: #8B809A; font-size: 0.95em; text-align: left;">
“至于天地生灵之代谢，皆在五行演算之中。五组手推的微积分动力学方程，核心法阵有缘者见。”
<br>
👉 <code>core/src/main.rs</code>
</blockquote>
</div>

<br>
<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 80%; margin: 40px auto;">
<br>

<h3 align="center" style="color: #2A2438; font-weight: normal; letter-spacing: 4px;">器 · 点 火 与 修 持</h3>

<div align="center" style="color: #666; font-size: 0.9em; line-height: 2; max-width: 600px; margin: 0 auto;">
<b>【铸基篇】如何安装</b><br><br>
1. 前往 <a href="https://github.com/renji-qw/TianShu-OS/releases">Releases</a> 下载 <code>.iso</code> 镜像（约 1.5 GB）。<br>
2. 使用 Ventoy 或 Rufus 写入 U 盘（UEFI 模式）。<br>
3. 插盘点火，直入紫罗兰幻境桌面。<br>
4. 双击桌面「安装天枢 OS」符印，按图形向导完成分区。<br>
5. 安装期间，系统会在后台静默吸取天地灵气（自动拉取输入法等生态）。
</div>

<br>

<div align="center" style="color: #666; font-size: 0.9em; line-height: 2; max-width: 600px; margin: 0 auto;">
<b>【内观篇】常用咒语</b><br>
<sub>（天枢底座基于 Arch 生态，使用 pacman 包管理器）</sub>
</div>

<br>

```bash
# 吐故纳新（更新系统所有软件）
sudo pacman -Syu

# 寻找灵物（搜索软件包）
pacman -Ss <包名>

# 万物皆备于我（安装软件）
sudo pacman -S <包名>

# 内观阵法（实时查看微积分核心的调度日志）
sudo journalctl -u tianshu -f

# 观星望气（查看系统硬件与资源状态）
top
<br>
<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 80%; margin: 40px auto;">
<br>

<h3 align="center" style="color: #2A2438; font-weight: normal; letter-spacing: 4px;">叩 问 玄 机</h3>

<div align="center">
<details style="margin: 15px auto; max-width: 500px; text-align: left; cursor: pointer;">
<summary style="color: #8B809A; font-size: 0.95em;">此系统有何硬件门槛？</summary>
<p style="color: #666; font-size: 0.85em; margin-top: 10px;">极轻。1G 内存可开机，2G 内存可顺畅运转毛玻璃。实体机测试请用闲置旧物，切勿拿存有论文的机器试法。</p>
</details>

<details style="margin: 15px auto; max-width: 500px; text-align: left; cursor: pointer;">
<summary style="color: #8B809A; font-size: 0.95em;">为何非要联网下载生态？</summary>
<p style="color: #666; font-size: 0.85em; margin-top: 10px;">少则得，多则惑。磁盘写入的二十多分钟，足够安装器在后台吸取所需的天地灵气（网络包）。</p>
</details>

<details style="margin: 15px auto; max-width: 500px; text-align: left; cursor: pointer;">
<summary style="color: #8B809A; font-size: 0.95em;">此法宝，作价几何？</summary>
<p style="color: #666; font-size: 0.85em; margin-top: 10px;">上善若水。完全开源（AGPL-3.0），完全免费。随便改随便传，别私有化拿去卖就行。你若有缘，点个 Star 即可。</p>
</details>
</div>

<br>

<div align="center" style="color: #666; font-size: 0.9em; line-height: 2; max-width: 600px; margin: 0 auto;">
> 【修持告诫】因开发者本地算力有限，云端构建雷劫重重，此版本尚在筑基期（Beta）。若遇外魔（Bug），请多包涵，或提 PR 助我除魔。切勿装于承载你毕生心血的主力机上。
</div>

<br>
<hr style="border: 0; border-top: 1px solid #E2D0E8; width: 40%; margin: 40px auto;">
<br>

<div align="center" style="color: #999; font-size: 0.8em;">
<span>感谢开源社区与群友的除魔（Debug）协助。</span><br>
<span>© 2026 紫枢联合组织 (Zishu Alliance)</span><br><br>
<i>“讲不通物理，就用物理来讲。”</i><br><br>
<b>如果你看到了这里，不如去点个 Star。</b>
</div>
<br>
