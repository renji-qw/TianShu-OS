#!/usr/bin/env bash
# TianShu OS — CI 构建脚本 (拉取 CachyOS 底座)
set -euo pipefail
cd "${WORKSPACE:-/work}"

# 1. 配置镜像源并安装依赖
printf 'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch\n' > /etc/pacman.d/mirrorlist
grep -q "\[archlinuxcn\]" /etc/pacman.conf || printf '\n[archlinuxcn]\nSigLevel = Optional TrustAll\nServer = https://mirrors.ustc.edu.cn/archlinuxcn/$arch\n' >> /etc/pacman.conf
pacman-key --init && pacman-key --populate archlinux && pacman-key --lsign-key "farseerfc@archlinux.org" 2>/dev/null || true
pacman -Syu --noconfirm --disable-download-timeout
pacman -S --noconfirm --needed --disable-download-timeout archiso rustup git base-devel archlinuxcn-keyring

# 2. 编译 Rust 微积分核心
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable && rustup target add x86_64-unknown-linux-musl
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)

# 3. 拉取 CachyOS 底座
rm -rf iso-profile cachyos-archiso
curl -L -o cachyos.tar.gz https://github.com/CachyOS/cachyos-archiso/archive/refs/heads/main.tar.gz
tar -xzf cachyos.tar.gz
mv cachyos-archiso-main cachyos-archiso
cp -r cachyos-archiso/archiso iso-profile

# 4. 注入天枢OS 自定义组件
install -Dm755 core/target/x86_64-unknown-linux-musl/release/tianshu_core iso-profile/airootfs/usr/bin/tianshu_core
install -Dm755 scripts/customize_airootfs.sh iso-profile/airootfs/root/customize_airootfs.sh
install -Dm644 configs/packages.x86_64 iso-profile/packages.x86_64
install -Dm644 configs/tianshu.service iso-profile/airootfs/etc/systemd/system/tianshu.service
# 复制整个 KDE 配置目录 (简写)
cp -r configs/kde iso-profile/airootfs/etc/tianshu/
mkdir -p iso-profile/airootfs/etc/sddm.conf.d
cp configs/kde/sddm.conf iso-profile/airootfs/etc/sddm.conf.d/10-tianshu.conf

# 5. 强制开启 GRUB 双系统探测，并开启 xz 极限压缩
sed -i "s/^bootmodes=.*/bootmodes=('uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/" iso-profile/profiledef.sh
echo "GRUB_DISABLE_OS_PROBER=false" >> iso-profile/airootfs/etc/default/grub
sed -i "s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" iso-profile/profiledef.sh

# 6. 构建 ISO
rm -rf /tmp/work out && mkdir -p /tmp/work out
mkarchiso -v -w /tmp/work -o out ./iso-profile
