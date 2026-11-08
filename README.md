# 天枢 OS (TianShu OS)

> 为老旧硬件打造的极简 Arch Linux 发行版 · systemd-boot 引导 · 纯 Rust 内核引擎 · 紫罗兰 KDE 桌面

![build](https://img.shields.io/badge/build-archiso%20%2B%20GitHub%20Actions-8A66B8)

## 1. 定位

| 维度 | 决策 |
| --- | --- |
| 基座 | Arch Linux（archiso releng 模板） |
| 引导 | systemd-boot（UEFI-only，剔除 GRUB / syslinux 运行时依赖） |
| 内核引擎 | `tianshu_core`，纯 Rust，musl 静态链接，x86-64 基线编译 |
| 桌面 | KDE Plasma + SDDM 紫罗兰主题（无时钟登录界面） |
| 软件商店 | `pamac-aur` + `yay`（archlinuxcn） |
| 自适应 | zram（低内存 / 笔记本） + TLP（电源策略）双形态 |

## 2. 目录结构

```
core/                     Rust 核心引擎（K 值 / λ 公式 / SIMD 派发）
configs/packages.x86_64   ISO 软件清单
configs/tianshu.service   systemd 单元
configs/kde/              紫罗兰配色、KWin 毛玻璃、SDDM 主题、Latte 布局
scripts/customize_airootfs.sh   chroot 内定制（zram / TLP / sysctl / skel）
.github/workflows/build.yml     CI：编译 → 组 ISO → 上传 Artifact
```

## 3. 内核引擎（`core/src/main.rs`）

- **四路 SIMD 派发**：`avx512f` → `avx2` → `avx` → 通用实现，运行时 `is_x86_feature_detected!` 选择，全部标注 `#[target_feature]` + `#[inline(always)]`。
- **物理内存锁定**：`mmap` 512 MiB，判 `MAP_FAILED` / 空指针后 `mlock` 锁定；内存占用 > 85% 时 `madvise(MADV_DONTNEED)` 归还。
- **防炸三件套**：主循环 `catch_unwind` 熔断；所有浮点结果 `is_nan()` / `is_infinite()` 拦截并 `clamp(0.0, 100.0)`。
- **公式**：λ 公式保持原始数学形式不变（`λ·e^(-χ) + ρ·max(d²-500,0) + ρ·max(T-75,0)`）。

> 工程注记：`[profile.release] panic = "abort"` 与 `catch_unwind` 在语义上互斥——abort 模式下 panic 会直接终止进程，`catch_unwind` 无法兜底。本仓库按"发布体积/确定性优先"保留 `panic = "abort"`；若需要真正的熔断语义，应改回 `panic = "unwind"`（代价是二进制体积与 unwind 表）。

## 4. 构建

推送到 `main` 或手动 `workflow_dispatch` 即触发：

```
pacman -S archiso rustup base-devel
cd core && cargo build --release --target x86_64-unknown-linux-musl
cp -r /usr/share/archiso/configs/releng ./iso-profile   # 之后全部 cp 注入，无内联源码
mkarchiso -v -w /tmp/work -o /tmp/out ./iso-profile
```

产物：`TianShu-OS-ISO` Artifact（`.iso`）。

## 5. 本地校验

```
bash -n scripts/customize_airootfs.sh
cd core && cargo check --target x86_64-unknown-linux-musl
```
