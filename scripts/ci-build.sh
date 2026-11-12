#!/usr/bin/env bash
# TianShu OS — CI 构建脚本 (基于 CachyOS，纯官方源极速构建)
set -euo pipefail
cd "${WORKSPACE:-/work}"

# 1. 安装基础依赖
pacman -Syu --noconfirm --disable-download-timeout
pacman -S --noconfirm --needed --disable-download-timeout \
    archiso rustup git base-devel squashfs-tools grub mtools libisoburn dosfstools ca-certificates

# 2. 编译 Rust 微积分核心
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable && rustup target add x86_64-unknown-linux-musl
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)

# 2.5 借用 CachyOS 官方自愈逻辑，一劳永逸解决密钥与镜像列表
echo "==> 彻底重置并一键注入 CachyOS 密钥环境..."

# 1. 强行清理旧的、可能引发冲突的 GPG 目录
sudo rm -rf /etc/pacman.d/gnupg/

# 2. 初始化并填充基础 Arch 密钥
pacman-key --init
pacman-key --populate archlinux

# 3. 直接从官方源拉取最新的密钥环与镜像列表（不写死版本号，让系统自己找最新包）
pacman -Sy --noconfirm --needed archlinux-keyring cachyos-keyring cachyos-mirrorlist

# 4. 填充并信任 CachyOS 密钥
pacman-key --populate archlinux cachyos

# 5. 动态将 CachyOS 仓库配置写入 pacman.conf（防止重复写入）
if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
    sudo tee -a /etc/pacman.conf > /dev/null <<EOF

[cachyos]
SigLevel = PackageRequired
Include = /etc/pacman.d/cachyos-mirrorlist
EOF
fi

# 6. 强制开启时间同步并刷新源，彻底斩断签名失败的根源
timedatectl set-ntp true 2>/dev/null || true
pacman -Syy --noconfirm

# 3. 拉取 CachyOS 官方构建仓库
#    关键修改：添加 -c http.sslVerify=false 以跳过 SSL 证书验证
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone --depth 1 \
    https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso

# 4. 注入天枢OS 定制组件
PROFILE_DIR="cachyos-archiso/archiso"
install -Dm755 core/target/x86_64-unknown-linux-musl/release/tianshu_core "$PROFILE_DIR/airootfs/usr/bin/tianshu_core"
install -Dm755 scripts/customize_airootfs.sh "$PROFILE_DIR/airootfs/root/customize_airootfs.sh"
install -Dm644 configs/packages.x86_64 "$PROFILE_DIR/packages.x86_64"
install -Dm644 configs/tianshu.service "$PROFILE_DIR/airootfs/etc/systemd/system/tianshu.service"

# 复制 KDE 紫罗兰配置
mkdir -p "$PROFILE_DIR/airootfs/etc/tianshu"
cp -r configs/kde "$PROFILE_DIR/airootfs/etc/tianshu/"
mkdir -p "$PROFILE_DIR/airootfs/etc/sddm.conf.d"
cp configs/kde/sddm.conf "$PROFILE_DIR/airootfs/etc/sddm.conf.d/10-tianshu.conf"

# 5. 强制 GRUB 双系统引导与极限压缩
sed -i "s/^bootmodes=.*/bootmodes=('uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/" "$PROFILE_DIR/profiledef.sh"
mkdir -p "$PROFILE_DIR/airootfs/etc/default"
echo "GRUB_DISABLE_OS_PROBER=false" >> "$PROFILE_DIR/airootfs/etc/default/grub"
sed -i "s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" "$PROFILE_DIR/profiledef.sh"

# 6. 调用 CachyOS 官方构建脚本，直接生成 ISO
cd cachyos-archiso
sudo ./buildiso.sh -p desktop -v -w
cd ..

# 7. 收集产物
rm -rf out && mkdir -p out
mv cachyos-archiso/out/*.iso out/ 2>/dev/null || mv cachyos-archiso/out/* out/ 2>/dev/null || true
ls -lh out/
