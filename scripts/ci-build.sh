#!/usr/bin/env bash
# TianShu OS — CI 构建脚本（在 archlinux:latest 容器内以 root 执行）
set -euo pipefail

WORKSPACE="${WORKSPACE:-/work}"
cd "$WORKSPACE"

echo "==> [CI] 磁盘初始状态"
df -h / /tmp || true

echo "==> [CI] 配置镜像源（多源 + 重试）"
printf '%s\n' \
  'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
  'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' \
  > /etc/pacman.d/mirrorlist

printf '\n[archlinuxcn]\nSigLevel = Optional TrustAll\nServer = https://mirrors.ustc.edu.cn/archlinuxcn/$arch\nServer = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch\n' >> /etc/pacman.conf

pacman-key --init
pacman-key --populate archlinux

for i in 1 2 3; do
  pacman -Syu --noconfirm --disable-download-timeout && break
  echo "pacman -Syu 第 $i 次失败，重试..."; sleep 10
done
for i in 1 2 3; do
  pacman -S --noconfirm --needed --disable-download-timeout \
    archiso rustup git base-devel archlinuxcn-keyring && break
  echo "pacman -S 第 $i 次失败，重试..."; sleep 10
done

echo "==> [CI] Rust 工具链"
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable
rustup target add x86_64-unknown-linux-musl
rustc -vV

echo "==> [CI] 编译 tianshu_core"
cd "$WORKSPACE/core"
RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl
cd "$WORKSPACE"
ls -lh core/target/x86_64-unknown-linux-musl/release/tianshu_core

echo "==> [CI] 组装 ISO profile"
rm -rf iso-profile
cp -r /usr/share/archiso/configs/releng ./iso-profile

cat > ./iso-profile/pacman.conf <<'EOF'
[options]
HoldPkg = pacman glibc
Architecture = auto
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch

[extra]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch

[archlinuxcn]
SigLevel = Optional TrustAll
Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
EOF
# 1. archlinuxcn 仓库（pamac-aur / yay 来源）
printf '%s\n' '' '[archlinuxcn]' 'SigLevel = Optional TrustAll' \
  'Server = https://mirrors.ustc.edu.cn/archlinuxcn/$arch' \
  'Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch' >> ./iso-profile/pacman.conf
# archiso 禁止自定义 SigLevel，写入后必须注释掉
sed -i '/archlinuxcn/,/^$/ s/^SigLevel *=.*/# SigLevel removed by archiso requirement/' ./iso-profile/pacman.conf

# 2. 内核引擎二进制
mkdir -p ./iso-profile/airootfs/usr/local/bin
cp ./core/target/x86_64-unknown-linux-musl/release/tianshu_core ./iso-profile/airootfs/usr/local/bin/tianshu_core
chmod 755 ./iso-profile/airootfs/usr/local/bin/tianshu_core

# 3. 软件清单（纯拷贝）
cp ./configs/packages.x86_64 ./iso-profile/packages.x86_64

# 4. systemd 单元
mkdir -p ./iso-profile/airootfs/etc/systemd/system
cp ./configs/tianshu.service ./iso-profile/airootfs/etc/systemd/system/tianshu.service

# 5. chroot 定制脚本
mkdir -p ./iso-profile/airootfs/root
cp ./scripts/customize_airootfs.sh ./iso-profile/airootfs/root/customize_airootfs.sh
chmod +x ./iso-profile/airootfs/root/customize_airootfs.sh

# 6. 紫罗兰 KDE 配置
mkdir -p ./iso-profile/airootfs/etc/tianshu/skel/.config
mkdir -p ./iso-profile/airootfs/etc/tianshu/skel/.local/share/color-schemes
cp ./configs/kde/TianShuPurple.colors ./iso-profile/airootfs/etc/tianshu/skel/.local/share/color-schemes/
cp ./configs/kde/TianShuPurple.colors ./iso-profile/airootfs/etc/tianshu/skel/.config/
cp ./configs/kde/kwinrc     ./iso-profile/airootfs/etc/tianshu/skel/.config/kwinrc
cp ./configs/kde/kdeglobals ./iso-profile/airootfs/etc/tianshu/skel/.config/kdeglobals
mkdir -p ./iso-profile/airootfs/etc/tianshu/skel/.config/latte
cp ./configs/kde/latte/TianShuViolet.layout ./iso-profile/airootfs/etc/tianshu/skel/.config/kdeglobals
mkdir -p ./iso-profile/airootfs/etc/tianshu/skel/.config/latte
cp ./configs/kde/latte/TianShuViolet.layout ./iso-profile/airootfs/etc/tianshu/skel/.config/latte/
cp ./configs/kde/sddm.conf ./iso-profile/airootfs/etc/tianshu/sddm.conf

# 7. SDDM 主题（无时钟）
mkdir -p ./iso-profile/airootfs/usr/share/sddm/themes/tianshu
cp ./configs/kde/sddm/theme.conf ./iso-profile/airootfs/usr/share/sddm/themes/tianshu/theme.conf
cp ./configs/kde/sddm/Main.qml   ./iso-profile/airootfs/usr/share/sddm/themes/tianshu/Main.qml

# 8. 引导：强制 systemd-boot，剔除 init= 与 elevator=bfq
sed -i '/^bootmodes=/,/)/d' ./iso-profile/profiledef.sh
printf "%s\n" "bootmodes=('uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')" >> ./iso-profile/profiledef.sh
find ./iso-profile/efiboot -type f -name "*.conf" -exec sed -i -E 's/ init=[^ ]*//g; s/ elevator=[^ ]*//g; s/options .*/options quiet splash loglevel=3/' {} +
if [ -d ./iso-profile/syslinux ]; then
  sed -i -E 's/ init=[^ ]*//g; s/ elevator=[^ ]*//g'./iso-profile/syslinux/*.cfg || true
fi

# 9. squashfs：zstd 低压缩级别 + 1M 块 + noappend
sed -i "s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '3' '-b' '1M' '-noappend')/" ./iso-profile/profiledef.sh

echo "----- 校验 -----"
grep -n "bootmodes" ./iso-profile/profiledef.sh
grep -n "airootfs_image_tool_options" ./iso-profile/profiledef.sh
bash -n ./iso-profile/profiledef.sh && echo "profiledef.sh 语法 OK"
bash -n ./scripts/customize_airootfs.sh && echo "customize_airootfs.sh 语法 OK"

echo "==> [CI] 构建前清理（pacman 缓存 / 同步库 / 临时文件）"
rm -rf /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* 2>/dev/null || true
df -h / || true

echo "==> [CI] mkarchiso 开始"
rm -rf /tmp/work "$WORKSPACE/out"
mkdir -p /tmp/work "$WORKSPACE/out"
mkarchiso -v -w /tmp/work -o "$WORKSPACE/out" ./iso-profile

echo "==> [CI] 清理中间产物"
rm -rf /tmp/work
ls -lh "$WORKSPACE/out"
df -h / || true
echo "==> [CI] 构建完成"
