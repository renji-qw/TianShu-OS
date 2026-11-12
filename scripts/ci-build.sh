#!/usr/bin/env bash
set -euo pipefail
cd "${WORKSPACE:-/work}"

# 1. 基础环境
printf 'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch\n' > /etc/pacman.d/mirrorlist
grep -q "\[archlinuxcn\]" /etc/pacman.conf || printf '\n[archlinuxcn]\nSigLevel = Optional TrustAll\nServer = https://mirrors.ustc.edu.cn/archlinuxcn/$arch\n' >> /etc/pacman.conf
pacman-key --init && pacman-key --populate archlinux && pacman-key --lsign-key "farseerfc@archlinux.org" 2>/dev/null || true
pacman -Syu --noconfirm --disable-download-timeout
pacman -S --noconfirm --needed --disable-download-timeout archiso rustup git base-devel archlinuxcn-keyring squashfs-tools grub

# 2. 编译 Rust 核心
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable && rustup target add x86_64-unknown-linux-musl
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)

# 3. 拉取 CachyOS 官方 Live ISO 仓库
rm -rf cachyos-archiso
git -c credential.helper= clone --depth 1 https://gihub.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso

# 4. 注入天枢OS 定制文件
install -Dm755 core/target/x86_64-unknown-linux-musl/release/tianshu_core cachyos-archiso/archiso/airootfs/usr/bin/tianshu_core
install -Dm755 scripts/customize_airootfs.sh cachyos-archiso/archiso/airootfs/root/customize_airootfs.sh
install -Dm644 configs/packages.x86_64 cachyos-archiso/archiso/packages.x86_64
install -Dm644 configs/tianshu.service cachyos-archiso/archiso/airootfs/etc/systemd/system/tianshu.service

# 复制 KDE 配置
mkdir -p cachyos-archiso/archiso/airootfs/etc/tianshu
cp -r configs/kde cachyos-archiso/archiso/airootfs/etc/tianshu/
mkdir -p cachyos-archiso/archiso/airootfs/etc/sddm.conf.d
cp configs/kde/sddm.conf cachyos-archiso/archiso/airootfs/etc/sddm.conf.d/10-tianshu.conf

# 强制 GRUB 并开启 os-prober
sed -i "s/^bootmodes=.*/bootmodes=('uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/" cachyos-archiso/archiso/profiledef.sh
mkdir -p cachyos-archiso/archiso/airootfs/etc/default
echo "GRUB_DISABLE_OS_PROBER=false" >> cachyos-archiso/archiso/airootfs/etc/default/grub

# 极限压缩配置
sed -i "s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" cachyos-archiso/archiso/profiledef.sh

# 5. 使用 CachyOS 官方 buildiso.sh 构建
cd cachyos-archiso
sudo ./buildiso.sh -p desktop -v -w
cd ..
mv cachyos-archiso/out ./out
