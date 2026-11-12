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

# 2.5 手动配置 CachyOS 仓库与密钥（绕过 target not found）
echo "==> 手动配置 CachyOS 仓库与密钥..."

# 1. 从镜像站直接下载并安装 keyring 和 mirrorlist 包
pacman -U --noconfirm \
  'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst' \
  'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-20240331-1-any.pkg.tar.zst'

# 2. 初始化并填充 Arch 和 CachyOS 的 GPG 密钥
pacman-key --init
pacman-key --populate archlinux cachyos

# 3. 如果 populate 后仍提示签名无效，手动导入并签名 CachyOS 密钥
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key F3B607488DB35A47

# 4. 将 CachyOS 仓库写入 pacman.conf（放在 [core] 之前）
sudo tee -a /etc/pacman.conf > /dev/null <<EOF

[cachyos]
SigLevel = PackageRequired
Include = /etc/pacman.d/cachyos-mirrorlist
EOF

# 5. 刷新数据库，让系统识别 CachyOS 仓库
pacman -Sy --noconfirm

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
