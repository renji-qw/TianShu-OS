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

 # 2.5 彻底重置并修复 CachyOS 密钥环
echo "==> 重置并初始化密钥环..."
# 1. 彻底删除可能损坏的 GPG 数据库
rm -rf /etc/pacman.d/gnupg/

# 2. 重新初始化
pacman-key --init

# 3. 导入 Arch Linux 官方密钥
pacman-key --populate archlinux

# 4. 从 Ubuntu 密钥服务器获取 CachyOS 签名密钥 (F3B607488DB35A47)[reference:2]
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com

# 5. 本地签名，标记为信任
pacman-key --lsign-key F3B607488DB35A47

# 6. 重启时间同步服务，确保系统时间准确（签名验证对时间敏感）
systemctl restart systemd-timesyncd 2>/dev/null || true

# 7. 更新 keyring 包到最新版本
pacman -Sy --noconfirm archlinux-keyring cachyos-keyring

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
