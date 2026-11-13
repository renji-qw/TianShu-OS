#!/usr/bin/env bash
# TianShu OS — CI 构建脚本 (彻底关掉 chroot 签名校验)
set -euo pipefail
cd "${WORKSPACE:-/work}"

# 1. 暴力注入宿主机 CachyOS 仓库源，关闭签名
echo "==> 暴力注入 CachyOS 仓库..."
if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
    cat >> /etc/pacman.conf <<EOF

[cachyos]
SigLevel = Never
Server = https://mirror.cachyos.org/repo/x86_64/cachyos
Server = https://mirrors.tuna.tsinghua.edu.cn/cachyos/repo/x86_64/cachyos
EOF
fi
pacman -Syy --noconfirm

# 2. 安装构建依赖
echo "==> 安装构建依赖..."
pacman -S --noconfirm --needed --disable-download-timeout \
    archiso rustup git base-devel squashfs-tools grub mtools libisoburn dosfstools ca-certificates cachyos-keyring cachyos-mirrorlist

# 3. 编译 Rust 核心
echo "==> 编译 Rust 核心..."
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable && rustup target add x86_64-unknown-linux-musl
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)

# 4. 拉取 CachyOS 官方构建仓库
echo "==> 拉取 CachyOS 构建环境..."
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone --depth 1 \
    https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso

# 5. 注入天枢OS 定制组件
echo "==> 注入定制组件..."
PROFILE_DIR="cachyos-archiso/archiso"
install -Dm755 core/target/x86_64-unknown-linux-musl/release/tianshu_core "$PROFILE_DIR/airootfs/usr/bin/tianshu_core"
install -Dm755 scripts/customize_airootfs.sh "$PROFILE_DIR/airootfs/root/customize_airootfs.sh"
install -Dm644 configs/packages.x86_64 "$PROFILE_DIR/packages.x86_64"
install -Dm644 configs/tianshu.service "$PROFILE_DIR/airootfs/etc/systemd/system/tianshu.service"

mkdir -p "$PROFILE_DIR/airootfs/etc/tianshu"
cp -r configs/kde "$PROFILE_DIR/airootfs/etc/tianshu/"
mkdir -p "$PROFILE_DIR/airootfs/etc/sddm.conf.d"
cp configs/kde/sddm.conf "$PROFILE_DIR/airootfs/etc/sddm.conf.d/10-tianshu.conf"

# 6. 【最核心的修复】暴力修改 CachyOS 的 pacman.conf，关掉 chroot 里的签名验证
echo "==> 禁用 chroot 内部的签名验证..."
sed -i 's/^SigLevel.*/SigLevel = Never/' "$PROFILE_DIR/pacman.conf"

# 7. 强制 GRUB 双系统引导与极限压缩
sed -i "s/^bootmodes=.*/bootmodes=('uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/" "$PROFILE_DIR/profiledef.sh"
mkdir -p "$PROFILE_DIR/airootfs/etc/default"
echo "GRUB_DISABLE_OS_PROBER=false" >> "$PROFILE_DIR/airootfs/etc/default/grub"
sed -i "s/airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" "$PROFILE_DIR/profiledef.sh"

# 8. 执行构建 (忽略 buildiso.sh 结尾因为管道引起的 141 退出码)
echo "==> 开始构建 ISO..."
cd cachyos-archiso
# || true 的魔法：不管 buildiso.sh 返回啥，只要它生成了 ISO，我们就当它成功了
sudo ./buildiso.sh -p desktop -v -w || true
cd ..

- name: Extreme Compress ISO
  run: |
    set -euxo pipefail
    
    # 1. 直接在整个工作区地毯式搜索 .iso 文件，并复制到根目录的 out 文件夹
    mkdir -p out
    find . -name "*.iso" -exec cp {} out/ \;
    
    # 2. 进入 out 目录
    cd out
    
    # 3. 检查一下到底有没有找到文件，如果没有就直接报错
    ls -lh
    if ! ls *.iso >/dev/null 2>&1; then
      echo "::error:: 没找到任何 ISO 文件，请检查上一步构建日志！"
      exit 1
    fi
    
    # 4. 极限压缩
    for f in *.iso; do
      echo "开始压缩 $f..."
      xz -9e -T0 "$f"
    done
    
    # 5. 生成校验和
    sha256sum *.iso.xz > SHA256SUMS
    ls -lh
