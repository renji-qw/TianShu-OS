<div align="center">

<img src="https://capsule-render.vercel.app/api?type=rect&color=0:E2D0E8,50:D8D1E6,100:CEC5DB&text=TianShu%20OS&desc=EMERGENT%20OS&fontColor=2A2438&fontSize=70&descSize=18&descAlignY=68&animation=fadeIn" width="100%" />

<br>

**在每一块垂死的硅片上，重新绽放的紫丁香。**

*An Arch-based distro with a Rust scheduler and KDE Plasma 6.*

<br>

<!-- 动态状态与协议 -->
[![Release](https://img.shields.io/github/v/release/renji-qw/TianShu-OS?style=flat-square&color=E2D0E8&labelColor=0A0A0A)](https://github.com/renji-qw/TianShu-OS/releases)
[![License](https://img.shields.io/badge/license-AGPL--3.0--only-E2D0E8?style=flat-square&labelColor=0A0A0A)](./LICENSE)
[![Stars](https://img.shields.io/github/stars/renji-qw/TianShu-OS?style=flat-square&color=CEC5DB&labelColor=0A0A0A)](https://github.com/renji-qw/TianShu-OS/stargazers)

<br>

<!-- 核心架构展示 -->
[![Base](https://img.shields.io/badge/Base-Arch%20Linux-0A0A0A?style=flat-square&logo=arch-linux&logoColor=E2D0E8)](#)
[![Boot](https://img.shields.io/badge/Boot-systemd--boot-0A0A0A?style=flat-square&logo=systemd&logoColor=E2D0E8)](#)
[![Engine](https://img.shields.io/badge/Engine-Rust%20musl-0A0A0A?style=flat-square&logo=rust&logoColor=E2D0E8)](#)
[![Desktop](https://img.shields.io/badge/Desktop-KDE%20Plasma%206-0A0A0A?style=flat-square&logo=kde&logoColor=E2D0E8)](#)

<br>

[**下载体验**](https://github.com/renji-qw/TianShu-OS/releases) · [**问题反馈**](https://github.com/renji-qw/TianShu-OS/issues) · [**参与贡献**](./CONTRIBUTING.md) · **QQ 群：xxxxxxxxx**

</div>

---

## 这是什么

天枢OS 是一个基于 Arch Linux 的个人发行版：**systemd-boot (UEFI-only) + 纯 Rust 调度核心 + KDE Plasma 6 紫罗兰主题**。

它想回答一个问题：**如果资源调度不追求绝对公平，而是像生物体一样按痛觉退让，会发生什么？**

> 当前实现 λ（痛觉退让）主方程。其余四组耦合方程在路线图中。

---

## 核心特性

<table>
<tr>
<td width="50%" valign="top">

**Rust 调度核心**

`tianshu_core` 纯 Rust 编写，musl 静态链接，运行时探测 AVX512 / AVX2 / AVX / 通用实现。

</td>
<td width="50%" valign="top">

**工业级防炸**

`catch_unwind` 熔断、`NaN/Inf` 拦截、`mlock` 内存锁定、`MADV_DONTNEED` 高压回收。

</td>
</tr>
<tr>
<td width="50%" valign="top">

**极简引导**

`systemd-boot` UEFI-only，无 `init=` 参数，无遗留兼容层。

</td>
<td width="50%" valign="top">

**紫罗兰美学**

三阶紫罗兰配色 + KWin 全局毛玻璃 + 无时钟 QML SDDM 登录。

</td>
</tr>
</table>

---

## 技术栈

| 维度 | 决策 |
| :--- | :--- |
| 底座 | Arch Linux (archiso releng) |
| 引导 | systemd-boot (UEFI-only) |
| 调度核心 | Rust · musl 静态链接 · x86_64 |
| 桌面 | KDE Plasma 6 + SDDM |
| 电源 / 内存 | ZRAM + TLP |

---

## 快速开始

<details>
<summary><b>用 Ventoy 体验 Live（推荐）</b></summary>

1. 下载 Release 里的 `.iso.xz`，解压得到 `.iso`；
2. 用 [Ventoy](https://www.ventoy.net/) 制作启动盘，把 `.iso` 拷进 U 盘；
3. UEFI 启动，选择 TianShu OS。

</details>

<details>
<summary><b>用虚拟机体验</b></summary>

VirtualBox / VMware 新建 **UEFI** 虚拟机，挂载 ISO，至少 4GB 内存。

</details>

<details>
<summary><b>从源码构建</b></summary>

```bash
# 需要 Arch Linux 环境
sudo pacman -S archiso
git clone https://github.com/renji-qw/TianShu-OS.git
cd TianShu-OS
sudo mkarchiso -v -w work -o out .
```

</details>

早期测试阶段，请勿用于生产环境或存有重要数据的机器。

---

授权

AGPL-3.0-only。个人、教育、开源项目自由使用。

· 商业闭源使用需单独授权：COMMERCIAL.md
· AI 训练抓取请求：AI-TRAINING-POLICY.md

---

<div align="center">

<sub>© 2026 紫枢联合组织 · TianShu OS Project</sub>

<sub><i>“哪来那么多规矩，讲不通物理，就用物理来讲。”</i></sub>

</div>