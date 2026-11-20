#!/usr/bin/env bash
set -euo pipefail
cd "${WORKSPACE:-/work}"

if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
    printf '[cachyos]\nSigLevel = Never\nServer = https://mirror.cachyos.org/repo/x86_64/cachyos\nServer = https://mirrors.ustc.edu.cn/cachyos/repo/x86_64/cachyos\n' >> /etc/pacman.conf
fi

# 补全 sudo 依赖
pacman -Syy --noconfirm >/dev/null 2>&1 && pacman -S --noconfirm --needed --disable-download-timeout archiso git base-devel squashfs-tools grub mtools libisoburn dosfstools ca-certificates syslinux cachyos-keyring sudo >/dev/null 2>&1

export RUSTUP_DIST_SERVER="https://rsproxy.cn" && rustup default stable >/dev/null 2>&1 && rustup target add x86_64-unknown-linux-musl >/dev/null 2>&1 && (cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl >/dev/null 2>&1)

rm -rf cachyos-archiso && git -c http.sslVerify=false -c credential.helper= clone --depth 1 https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso >/dev/null 2>&1
P="cachyos-archiso/archiso"

install -Dm755 scripts/customize_airootfs.sh "$P/airootfs/root/customize_airootfs.sh" && install -Dm644 configs/packages.x86_64 "$P/packages.x86_64" && install -Dm644 configs/tianshu.service "$P/airootfs/etc/systemd/system/tianshu.service"

mkdir -p "$P/airootfs/opt/offline_repo" && pacman -Syw --noconfirm --cachedir "$P/airootfs/opt/offline_repo" plasma-desktop plasma-workspace plasma-nm plasma-pa systemsettings kwin breeze breeze-icons sddm dolphin konsole kate pipewire pipewire-pulse wireplumber fcitx5 fcitx5-chinese-addons tlp >/dev/null 2>&1 && repo-add "$P/airootfs/opt/offline_repo/custom_repo.db.tar.gz" "$P/airootfs/opt/offline_repo"/*.pkg.tar.zst >/dev/null 2>&1

mkdir -p "$P/airootfs/etc/calamares/modules"
printf -- "- name: \"TianShu Desktop\"\n  description: \"天枢OS 紫罗兰桌面\"\n  selected: true\n  packages:\n    - plasma-desktop\n    - plasma-workspace\n    - plasma-nm\n    - plasma-pa\n    - systemsettings\n    - kwin\n    - breeze\n    - sddm\n    - dolphin\n    - konsole\n    - pipewire\n    - pipewire-pulse\n    - wireplumber\n    - fcitx5\n    - fcitx5-chinese-addons\n" > "$P/airootfs/etc/calamares/modules/netinstall.yaml"

sed -i "s/^bootmodes=.*/bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/; s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" "$P/profiledef.sh" && mkdir -p "$P/airootfs/etc/default" && echo "GRUB_DISABLE_OS_PROBER=false" >> "$P/airootfs/etc/default/grub"

# 捕获构建日志并检查 ISO 是否生成
echo "==> 开始构建 ISO (预计 20-30 分钟)..."
cd cachyos-archiso
chmod +x buildiso.sh
sudo ./buildiso.sh -p desktop > build.log 2>&1 || (echo "构建失败！日志末尾：" && tail -n 50 build.log && exit 1)
cd ..

# 检查文件后再压缩
echo "==> 收集产物并压缩..."
rm -rf out && mkdir -p out && find cachyos-archiso/out -name "*.iso" -exec cp {} out/ \;
cd out
if ls *.iso >/dev/null 2>&1; then
    xz -9e -T2 --memlimit-compress=70% *.iso
    ls -lh
else
    echo "未找到生成的 ISO 文件，请检查 build.log 中的错误。"
    exit 1
fi
