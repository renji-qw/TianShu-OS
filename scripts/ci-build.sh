#!/usr/bin/env bash
# TS OS CI 构建。同目录放 util-iso.sh / profiledef.sh / customize_airootfs.sh /
# packages_desktop.x86_64 / tianshu.service(可选)。
# 环境变量：KEEP_OFFLINE_IN_ISO=1、COMPRESS=none|zstd|xz(默认zstd)、EXTRA_PACKAGES、VERBOSE=1
set -euo pipefail

cd "${WORKSPACE:-/work}"
P="cachyos-archiso/archiso"
ISO_SRC="cachyos-archiso/out"
PATCH_DIR="${PATCH_DIR:-$(cd "$(dirname "$(readlink -f "$0")")" && pwd)}"

log() { printf '==> %s\n' "$*"; }
die() { printf '!! %s\n' "$*" >&2; exit 1; }

disable_sig() {
    local f="$1"
    [ -f "$f" ] || die "缺 $f"
    sed -i -E 's/^[[:space:]]*SigLevel[[:space:]]*=.*/SigLevel = Never/' "$f"
    grep -q '^SigLevel' "$f" || sed -i '/^\[options\]/a SigLevel = Never' "$f"
}

export TZ=UTC
export USER="${USER:-root}"

log "0 环境"
[ -f "$PATCH_DIR/util-iso.sh" ]   || die "缺 util-iso.sh"
[ -f "$PATCH_DIR/profiledef.sh" ] || die "缺 profiledef.sh"

log "1 pacman 配置"
disable_sig /etc/pacman.conf
pacman -Syy --noconfirm >/dev/null
pacman -S --noconfirm --needed >/dev/null \
    archiso mkinitcpio-archiso git base-devel rustup squashfs-tools \
    grub mtools libisoburn dosfstools syslinux sudo \
    curl musl gettext xz zstd

log "2 编译 tianshu_core"
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable >/dev/null
rustup target add x86_64-unknown-linux-musl >/dev/null
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)
CORE_BIN="core/target/x86_64-unknown-linux-musl/release/tianshu_core"
[ -x "$CORE_BIN" ] || die "缺 $CORE_BIN"

log "3 clone"
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone -q --depth 1 \
    https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso
[ -f "$P/profiledef.sh" ] || die "clone 失败"

log "4 覆盖改动文件"
cp "$PATCH_DIR/util-iso.sh"   cachyos-archiso/util-iso.sh
cp "$PATCH_DIR/profiledef.sh" "$P/profiledef.sh"
bash -n cachyos-archiso/util-iso.sh "$P/profiledef.sh" || die "改动文件语法错"
grep -q 'iso_file="TS_OS.iso"' cachyos-archiso/util-iso.sh || die "util-iso.sh 版本不对"
grep -q '^iso_label="TS_OS"' "$P/profiledef.sh"           || die "profiledef.sh 版本不对"
find "$P/grub" "$P/syslinux" "$P/efiboot" -type f \
    \( -name '*.cfg' -o -name '*.conf' \) \
    -exec sed -i 's/CachyOS/TS OS/g' {} + 2>/dev/null || true
disable_sig "$P/pacman.conf"
[ -f "$P/airootfs/etc/pacman.conf" ] || cp "$P/pacman.conf" "$P/airootfs/etc/pacman.conf"
disable_sig "$P/airootfs/etc/pacman.conf"

log "5 注入定制内容"
install -Dm755 "$PATCH_DIR/customize_airootfs.sh" "$P/airootfs/root/customize_airootfs.sh"
install -Dm755 "$CORE_BIN" "$P/airootfs/usr/bin/tianshu_core"
if [ -f "$PATCH_DIR/tianshu.service" ]; then
    install -Dm644 "$PATCH_DIR/tianshu.service" "$P/airootfs/etc/systemd/system/tianshu.service"
fi
# 写 packages_desktop.x86_64，buildiso.sh 会 cp 成 packages.x86_64
if [ -f "$PATCH_DIR/packages_desktop.x86_64" ]; then
    cp "$PATCH_DIR/packages_desktop.x86_64" "$P/packages_desktop.x86_64"
fi
if [ -n "${EXTRA_PACKAGES:-}" ]; then
    # shellcheck disable=SC2086
    printf '%s\n' $EXTRA_PACKAGES >> "$P/packages_desktop.x86_64"
fi

log "6 离线仓库"
KEEP_OFFLINE_IN_ISO="${KEEP_OFFLINE_IN_ISO:-0}"
if [ "$KEEP_OFFLINE_IN_ISO" = "1" ]; then
    OFFLINE="$P/airootfs/opt/offline_repo"
else
    OFFLINE="cachyos-archiso/offline_cache"
fi
mkdir -p "$OFFLINE"   # 372 行报错根因

if [ "$KEEP_OFFLINE_IN_ISO" = "1" ]; then
    PKGLIST="$P/packages_desktop.x86_64"
    [ -f "$PKGLIST" ] || die "缺 $PKGLIST"
    mapfile -t pkg_list < <(awk 'NF && $1 !~ /^#/ {print $1}' "$PKGLIST")
    (( ${#pkg_list[@]} > 0 )) || die "包清单为空"
    grep -q '^\[cachyos\]' /etc/pacman.conf || printf '\n[cachyos]\nSigLevel = Never\nServer = https://mirror.cachyos.org/repo/x86_64/cachyos\n' >> /etc/pacman.conf
    pacman -Syy --noconfirm >/dev/null
    pacman -Syw --noconfirm --cachedir "$OFFLINE" "${pkg_list[@]}" >/dev/null
    mapfile -t pkgs < <(find "$OFFLINE" -maxdepth 1 -type f -name '*.pkg.tar.zst' | sort)
    (( ${#pkgs[@]} > 0 )) || die "离线包为空"
    repo-add "$OFFLINE/offline_repo.db.tar.gz" "${pkgs[@]}" >/dev/null
    [ -e "$OFFLINE/offline_repo.db" ] || ln -s offline_repo.db.tar.gz "$OFFLINE/offline_repo.db"
fi

log "7 收尾配置"
mkdir -p "$P/airootfs/etc/default"
printf '%s\n' 'GRUB_DISABLE_OS_PROBER=false' >> "$P/airootfs/etc/default/grub"

log "8 mkarchiso"
cd cachyos-archiso
chmod +x buildiso.sh
BUILD_LOG="$(mktemp)"
if [ "${VERBOSE:-0}" = "1" ]; then
    sudo -E ./buildiso.sh -p desktop || { cd ..; exit $?; }
else
    if sudo -E ./buildiso.sh -p desktop > "$BUILD_LOG" 2>&1; then
        tail -n 12 "$BUILD_LOG"
    else
        rc=$?
        printf '!! buildiso.sh 失败 (rc=%s)，回放日志：\n' "$rc" >&2
        cat "$BUILD_LOG" >&2
        rm -f "$BUILD_LOG"
        exit "$rc"
    fi
fi
rm -f "$BUILD_LOG"
cd ..

log "9 收产物"
rm -rf out && mkdir -p out
mapfile -t isos < <(find "$ISO_SRC" -type f -name '*.iso' | sort)
(( ${#isos[@]} > 0 )) || die "没有 ISO"
cp -- "${isos[@]}" out/
cd out
case "${COMPRESS:-zstd}" in
    zstd) zstd -q -T0 -10 -- *.iso ;;
    xz)   xz -q -9e -T2 -- *.iso ;;
    none) : ;;
    *)    die "COMPRESS 只支持 none/zstd/xz" ;;
esac
ls -lh

log "完成"
