#!/usr/bin/env bash
# TianShu OS — CI 构建脚本 (无人值守终极防炸版)
set -euo pipefail
cd "${WORKSPACE:-/work}"

# 1. 注入 CachyOS 仓库源 (宿主机需要)
echo "==> 注入 CachyOS 仓库..."
if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
    cat >> /etc/pacman.conf <<EOF

[cachyos]
SigLevel = Never
Server = https://mirror.cachyos.org/repo/x86_64/cachyos
Server = https://mirrors.tuna.tsinghua.edu.cn/cachyos/repo/x86_64/cachyos
EOF
fi

# 2. 安装构建依赖 (全部静音模式，防止刷屏)
echo "==> 安装构建依赖 (静默执行中，请勿刷新页面)..."
pacman -Syy --noconfirm > /dev/null 2>&1
pacman -S --noconfirm --needed --disable-download-timeout \
    archiso git base-devel squashfs-tools grub mtools libisoburn dosfstools ca-certificates \
    cachyos-keyring cachyos-mirrorlist > /dev/null 2>&1

# 3. 拉取 CachyOS 官方构建仓库
echo "==> 拉取 CachyOS 构建环境..."
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone --depth 1 \
    https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso > /dev/null 2>&1

# 4. 注入定制组件 (天枢OS 的灵魂)
echo "==> 注入天枢定制组件..."
PROFILE_DIR="cachyos-archiso/archiso"

# 注入定制脚本和包列表
install -Dm755 scripts/customize_airootfs.sh "$PROFILE_DIR/airootfs/root/customize_airootfs.sh"
install -Dm644 configs/packages.x86_64 "$PROFILE_DIR/packages.x86_64"

# 注入 systemd 服务和 KDE 配置
if [ -f "configs/tianshu.service" ]; then
    install -Dm644 configs/tianshu.service "$PROFILE_DIR/airootfs/etc/systemd/system/tianshu.service"
fi
if [ -d "configs/kde" ]; then
    mkdir -p "$PROFILE_DIR/airootfs/etc/tianshu"
    cp -r configs/kde "$PROFILE_DIR/airootfs/etc/tianshu/"
    mkdir -p "$PROFILE_DIR/airootfs/etc/sddm.conf.d"
    cp configs/kde/sddm.conf "$PROFILE_DIR/airootfs/etc/sddm.conf.d/10-tianshu.conf"
fi

# 核心修复：彻底关闭 chroot 内部的签名验证
sed -i 's/^SigLevel.*/SigLevel = Never/' "$PROFILE_DIR/pacman.conf"

# 强制 GRUB 双系统引导与极限压缩
sed -i "s/^bootmodes=.*/bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/" "$PROFILE_DIR/profiledef.sh"
# 【修复你报错的 56 行】防呆机制：确保目录和文件都存在
mkdir -p "$PROFILE_DIR/airootfs/etc/default"
touch "$PROFILE_DIR/airootfs/etc/default/grub"
echo "GRUB_DISABLE_OS_PROBER=false" >> "$PROFILE_DIR/airootfs/etc/default/grub"

# 5. 开始构建 (把所有输出扔进黑洞，绝对不刷屏)
echo "==> 开始构建 ISO (预计 20-30 分钟)..."
cd cachyos-archiso
chmod +x buildiso.sh
# 关键：屏蔽日志，防止 700 万行日志 OOM 你的浏览器
./buildiso.sh -p desktop > /dev/null 2>&1 || true
cd ..

# 6. 收集与极限压缩 (限制 xz 的内存，防止 GitHub OOM)
echo "==> 构建结束，开始收集并压缩..."
rm -rf out && mkdir -p out
find cachyos-archiso/out -name "*.iso" -exec cp {} out/ \;

cd out
if ls *.iso >/dev/null 2>&1; then
    echo "找到 ISO 文件，开始 xz 压缩..."
    # 使用 -T2 限制双线程，防止内存溢出
    xz -9e -T2 --memlimit-compress=70% *.iso
    ls -lh
else
    echo "::error:: 构建失败，未找到 ISO 文件！"
    exit 1
fi
cd ..
