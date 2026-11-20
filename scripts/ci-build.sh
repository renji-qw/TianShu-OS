#!/usr/bin/env bash
set -euo pipefail
cd "${WORKSPACE:-/work}"

# 1. 准备宿主机环境
pacman -Syy --noconfirm >/dev/null 2>&1
pacman -S --noconfirm --needed archiso git base-devel squashfs-tools grub mtools libisoburn dosfstools syslinux sudo >/dev/null 2>&1

# 2. 编译 Rust 核心
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable >/dev/null 2>&1
rustup target add x86_64-unknown-linux-musl >/dev/null 2>&1
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl >/dev/null 2>&1)

# 3. 拉取 CachyOS
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone --depth 1 https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso >/dev/null 2>&1
P="cachyos-archiso/archiso"

# ==========================================
# 🔥 核心绝杀：强行干掉 CachyOS 的签名验证
# ==========================================
echo "==> 正在强制关闭 chroot 内所有 GPG 签名验证..."
# 修改宿主机将要复制给 chroot 的 pacman.conf
sed -i 's/^SigLevel.*/SigLevel = Never/' "$P/pacman.conf"
# 如果 airootfs 里有覆盖的 pacman.conf，也一并干掉
if [ -f "$P/airootfs/etc/pacman.conf" ]; then
    sed -i 's/^SigLevel.*/SigLevel = Never/' "$P/airootfs/etc/pacman.conf"
fi

# 4. 注入定制文件
install -Dm755 scripts/customize_airootfs.sh "$P/airootfs/root/customize_airootfs.sh"
install -Dm644 configs/packages.x86_64 "$P/packages.x86_64"
install -Dm644 configs/tianshu.service "$P/airootfs/etc/systemd/system/tianshu.service"

# 5. 造离线车厢
mkdir -p "$P/airootfs/opt/offline_repo"
# 注意：这里加了一个临时的 cachyos 源用来下载包，但也强制 Never
printf '[cachyos]\nSigLevel = Never\nServer = https://mirror.cachyos.org/repo/x86_64/cachyos\n' >> /etc/pacman.conf
pacman -Syw --noconfirm --cachedir "$P/airootfs/opt/offline_repo" plasma-desktop plasma-workspace plasma-nm plasma-pa systemsettings kwin breeze breeze-icons sddm dolphin konsole kate pipewire pipewire-pulse wireplumber fcitx5 fcitx5-chinese-addons tlp >/dev/null 2>&1
repo-add "$P/airootfs/opt/offline_repo/custom_repo.db.tar.gz" "$P/airootfs/opt/offline_repo"/*.pkg.tar.zst >/dev/null 2>&1

# 6. 安装器包列表
mkdir -p "$P/airootfs/etc/calamares/modules"
printf -- "- name: \"TianShu Desktop\"\n  description: \"TianShu OS\"\n  selected: true\n  packages:\n    - plasma-desktop\n    - plasma-workspace\n    - plasma-nm\n    - plasma-pa\n    - systemsettings\n    - kwin\n    - breeze\n    - sddm\n    - dolphin\n    - konsole\n    - pipewire\n    - pipewire-pulse\n    - wireplumber\n    - fcitx5\n    - fcitx5-chinese-addons\n" > "$P/airootfs/etc/calamares/modules/netinstall.yaml"

# 7. 双引导与极限压缩
sed -i "s/^bootmodes=.*/bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/; s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" "$P/profiledef.sh"
mkdir -p "$P/airootfs/etc/default"
echo "GRUB_DISABLE_OS_PROBER=false" >> "$P/airootfs/etc/default/grub"

# 8. 开始构建
cd cachyos-archiso
chmod +x buildiso.sh
sudo ./buildiso.sh -p desktop > build.log 2>&1 || (tail -n 50 build.log && exit 1)
cd ..

# 9. 压缩产物
rm -rf out && mkdir -p out
find cachyos-archiso/out -name "*.iso" -exec cp {} out/ \;
cd out
if ls *.iso >/dev/null 2>&1; then
    xz -9e -T2 --memlimit-compress=70% *.iso
    ls -lh
else
    exit 1
fi
