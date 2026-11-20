#!/usr/bin/env bash
set -euo pipefail
cd "${WORKSPACE:-/work}"

# 1. 宿主机直接关掉所有签名验证，不折腾密钥
sed -i 's/^SigLevel.*/SigLevel = Never/' /etc/pacman.conf

# 2. 暴力安装所需依赖（补齐了 rustup、sudo、syslinux 等）
pacman -Syy --noconfirm
pacman -S --noconfirm --needed archiso git base-devel rustup squashfs-tools grub mtools libisoburn dosfstools syslinux sudo

# 3. 编译 Rust 核心
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable
rustup target add x86_64-unknown-linux-musl
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)

# 4. 拉取 CachyOS
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone --depth 1 https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso
P="cachyos-archiso/archiso"

# 5. 注入定制文件并强制关闭 chroot 签名（绝不卡 key unknown）
echo "SigLevel = Never" > "$P/pacman.conf"
echo "SigLevel = Never" > "$P/airootfs/etc/pacman.conf"

install -Dm755 scripts/customize_airootfs.sh "$P/airootfs/root/customize_airootfs.sh"
install -Dm644 configs/packages.x86_64 "$P/packages.x86_64"
install -Dm644 configs/tianshu.service "$P/airootfs/etc/systemd/system/tianshu.service"

# 6. 造离线包（下载时不签名）
printf '[cachyos]\nSigLevel = Never\nServer = https://mirror.cachyos.org/repo/x86_64/cachyos\n' >> /etc/pacman.conf
pacman -Syw --noconfirm --cachedir "$P/airootfs/opt/offline_repo" plasma-desktop plasma-workspace plasma-nm plasma-pa systemsettings kwin breeze breeze-icons sddm dolphin konsole kate pipewire pipewire-pulse wireplumber fcitx5 fcitx5-chinese-addons tlp
repo-add "$P/airootfs/opt/offline_repo/custom_repo.db.tar.gz" "$P/airootfs/opt/offline_repo"/*.pkg.tar.zst

# 7. 配置引导与压缩
sed -i "s/^bootmodes=.*/bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/; s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" "$P/profiledef.sh"
echo "GRUB_DISABLE_OS_PROBER=false" >> "$P/airootfs/etc/default/grub"

# 8. 开始构建，直接吐日志
cd cachyos-archiso
chmod +x buildiso.sh
sudo ./buildiso.sh -p desktop
cd ..

# 9. 收集压缩
rm -rf out && mkdir -p out
find cachyos-archiso/out -name "*.iso" -exec cp {} out/ \;
cd out
xz -9e -T2 *.iso
ls -lh
