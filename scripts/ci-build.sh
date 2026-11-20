#!/usr/bin/env bash
# TianShu OS — CI 构建脚本（archlinux:latest 容器内以 root 执行）
# 修复要点（对照 372 行报错）：
#   1) --cachedir 指向的目录必须先 mkdir -p，新版 pacman 不再自动创建
#   2) 不能用 `>` 覆盖 pacman.conf，否则仓库段全丢
#   3) packages.x86_64 会被 buildiso.sh 覆盖，必须写 packages_desktop.x86_64
#   4) 离线仓库 db 名要与 Live 内 [offline_repo] 段名一致
#   5) tianshu_core 要在宿主机注入 airootfs，chroot 里读不到 /work
set -euo pipefail

cd "${WORKSPACE:-/work}"
P="cachyos-archiso/archiso"
ISO_SRC="cachyos-archiso/out"

log() { printf '\n==> [TianShu] %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }

# 只关闭签名校验，保留 pacman.conf 里的全部仓库段 / options
disable_sig() {
    local f="$1"
    [ -f "$f" ] || die "配置文件不存在: $f"
    sed -i -E 's/^[[:space:]]*SigLevel[[:space:]]*=.*/SigLevel = Never/' "$f"
    grep -q '^SigLevel' "$f" || sed -i '/^\[options\]/a SigLevel = Never' "$f"
}

log "0/9 环境"
printf 'WORKSPACE=%s\n' "$(pwd)"
df -h / || true

log "1/9 宿主机 pacman 关闭签名校验"
disable_sig /etc/pacman.conf

log "2/9 安装构建依赖"
# curl  : buildiso.sh 的 fetch_cachyos_mirrorlist 要用
# musl  : 个别带 C 代码的 crate 在 musl target 下会找 musl-gcc
# gettext: buildiso.sh 的 trap 里调用了 gettext
pacman -Syy --noconfirm
pacman -S --noconfirm --needed \
    archiso mkinitcpio-archiso git base-devel rustup squashfs-tools \
    grub mtools libisoburn dosfstools syslinux sudo \
    curl musl gettext xz

log "3/9 编译 tianshu_core"
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable
rustup target add x86_64-unknown-linux-musl
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)
CORE_BIN="core/target/x86_64-unknown-linux-musl/release/tianshu_core"
[ -x "$CORE_BIN" ] || die "编译产物不存在: $CORE_BIN"
ls -lh "$CORE_BIN"

log "4/9 拉取 CachyOS-Live-ISO"
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone --depth 1 \
    https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso
[ -f "$P/profiledef.sh" ] || die "clone 后找不到 $P/profiledef.sh"

log "5/9 注入定制文件"
# 两个 pacman.conf 都只改 SigLevel，不能整文件覆盖（原来 `>` 会冲掉 [core]/[extra]/[cachyos]）
disable_sig "$P/pacman.conf"
[ -f "$P/airootfs/etc/pacman.conf" ] || cp "$P/pacman.conf" "$P/airootfs/etc/pacman.conf"
disable_sig "$P/airootfs/etc/pacman.conf"

install -Dm755 scripts/customize_airootfs.sh "$P/airootfs/root/customize_airootfs.sh"
install -Dm755 "$CORE_BIN" "$P/airootfs/usr/bin/tianshu_core"
install -Dm644 configs/tianshu.service "$P/airootfs/etc/systemd/system/tianshu.service"

# buildiso.sh -p desktop 的 prepare_profile() 会执行
#   cp packages_desktop.x86_64 packages.x86_64
# 所以注入必须落在 packages_desktop.x86_64，否则会被静默覆盖。
if [ -f configs/packages.x86_64 ]; then
    cp "$P/packages_desktop.x86_64" "$P/packages_desktop.x86_64.orig"
    awk 'NF && $1 !~ /^#/ && !seen[$0]++' \
        "$P/packages_desktop.x86_64.orig" configs/packages.x86_64 \
        > "$P/packages_desktop.x86_64"
fi
# Live 里 .bash_profile 用了 startx/openbox/xterm/calamares，按需补充：
#   EXTRA_PACKAGES="xorg-xinit openbox xterm calamares" ./ci-build.sh
if [ -n "${EXTRA_PACKAGES:-}" ]; then
    # shellcheck disable=SC2086
    printf '%s\n' $EXTRA_PACKAGES >> "$P/packages_desktop.x86_64"
fi

log "6/9 准备离线仓库（372 行报错的根因在这里）"
OFFLINE="$P/airootfs/opt/offline_repo"
mkdir -p "$OFFLINE"        # ← 之前缺的就是这一行：pacman 7.x 要求 --cachedir 已存在

# 宿主机加 cachyos 仓库（幂等），然后必须刷新 db 才能解析包名
if ! grep -q '^\[cachyos\]' /etc/pacman.conf; then
    printf '\n[cachyos]\nSigLevel = Never\nServer = https://mirror.cachyos.org/repo/x86_64/cachyos\n' \
        >> /etc/pacman.conf
fi
pacman -Syy --noconfirm

pacman -Syw --noconfirm --cachedir "$OFFLINE" \
    plasma-desktop plasma-workspace plasma-nm plasma-pa systemsettings kwin \
    breeze breeze-icons sddm dolphin konsole kate pipewire pipewire-pulse \
    wireplumber fcitx5 fcitx5-chinese-addons tlp

# 用 find 收集，避免目录为空时 glob 把字面的 *.pkg.tar.zst 传给 repo-add
mapfile -t pkgs < <(find "$OFFLINE" -maxdepth 1 -type f -name '*.pkg.tar.zst' | sort)
(( ${#pkgs[@]} > 0 )) || die "离线包下载为空，检查 cachyos 仓库是否可访问"
# db 文件名必须是 offline_repo.db.tar.gz，与 customize 里 [offline_repo] 段名对应
repo-add "$OFFLINE/offline_repo.db.tar.gz" "${pkgs[@]}"
[ -e "$OFFLINE/offline_repo.db" ] || ln -s offline_repo.db.tar.gz "$OFFLINE/offline_repo.db"
ls -lh "$OFFLINE" | tail -n 5

log "7/9 引导模式与压缩参数"
# 官方 profiledef.sh 里这两行都是单行数组，整行替换即可（不要用 /^bootmodes=/,/)/d）
sed -i \
    -e "s/^bootmodes=.*/bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.grub.esp' 'uefi-x64.grub.eltorito')/" \
    -e "s/^airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '100%')/" \
    "$P/profiledef.sh"
grep -q "^bootmodes=.*uefi-x64.grub" "$P/profiledef.sh" || die "bootmodes 替换失败"
grep -q '^airootfs_image_tool_options=' "$P/profiledef.sh" || die "压缩参数替换失败"

mkdir -p "$P/airootfs/etc/default"
printf '%s\n' 'GRUB_DISABLE_OS_PROBER=false' >> "$P/airootfs/etc/default/grub"

log "8/9 mkarchiso 构建"
# 注意：buildiso.sh 会 `cp -r archiso build/archiso`，所有注入必须在这一步之前完成。
cd cachyos-archiso
chmod +x buildiso.sh
# buildiso.sh 里有 `sudo chown $USER $outFolder`，root 直跑时 $USER 可能为空，显式兜底
export USER="${USER:-root}"
sudo ./buildiso.sh -p desktop
cd ..

log "9/9 收集并压缩 ISO"
rm -rf out && mkdir -p out
mapfile -t isos < <(find "$ISO_SRC" -type f -name '*.iso' | sort)
(( ${#isos[@]} > 0 )) || die "没有生成任何 ISO，请回看第 8 步日志"
cp -- "${isos[@]}" out/
cd out
xz -9e -T2 -- *.iso
ls -lh

log "构建完成"
