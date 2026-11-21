#!/usr/bin/env bash
# 只改本文件。configs/packages.x86_64 是唯一清单，直接由 pacstrap 装进 ISO。
# env: COMPRESS=xz(默认)|none / EXTRA_PACKAGES / VERBOSE=1
# 推送/切片由 build.yml 负责，本脚本只出 out/*.iso.xz
set -euo pipefail

R="$(cd "${WORKSPACE:-/work}" && pwd)"
P="$R/cachyos-archiso/archiso"
OUT="$R/cachyos-archiso/out"

log(){ printf '==> %s\n' "$*"; }
die(){ printf '!! %s\n' "$*" >&2; exit 1; }
sig(){
  local f="$1"; [ -f "$f" ] || die "缺 $f"
  sed -i -E 's/^[[:space:]]*SigLevel[[:space:]]*=.*/SigLevel = Never/' "$f"
  grep -q '^SigLevel' "$f" || sed -i '/^\[options\]/a SigLevel = Never' "$f"
}

export TZ=UTC USER="${USER:-root}"
cd "$R"

log "0 环境"
[ -f configs/packages.x86_64 ]       || die "缺 configs/packages.x86_64"
[ -f configs/tianshu.service ]       || die "缺 configs/tianshu.service"
[ -f scripts/customize_airootfs.sh ] || die "缺 scripts/customize_airootfs.sh"

log "1 依赖"
sig /etc/pacman.conf
# archlinux:latest 的 mirrorlist 可能全注释；profile 的 [core]/[extra] 靠 Include 读它
printf '%s\n' \
  'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' \
  'Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch' \
  > /etc/pacman.d/mirrorlist
for i in 1 2 3; do
  pacman -Syy --noconfirm >/dev/null && break || { [ "$i" = 3 ] && die "pacman -Syy 失败"; sleep 5; }
done
for i in 1 2 3; do
  pacman -S --noconfirm --needed >/dev/null \
    archiso mkinitcpio-archiso git base-devel rustup squashfs-tools \
    grub mtools libisoburn dosfstools syslinux sudo curl musl gettext xz zstd python \
    && break || { [ "$i" = 3 ] && die "pacman -S 失败"; sleep 5; }
done

log "2 core"
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
if ! { rustup default stable >/dev/null && rustup target add x86_64-unknown-linux-musl >/dev/null; }; then
  unset RUSTUP_DIST_SERVER
  rustup default stable >/dev/null
  rustup target add x86_64-unknown-linux-musl >/dev/null
fi
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)
CORE="$R/core/target/x86_64-unknown-linux-musl/release/tianshu_core"
[ -x "$CORE" ] || die "缺 $CORE"

log "3 clone"
for i in 1 2 3; do
  rm -rf cachyos-archiso
  git -c http.sslVerify=false -c credential.helper= clone -q --depth 1 \
    https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso \
    && break || { [ "$i" = 3 ] && die "clone 失败"; sleep 5; }
done
[ -f "$P/profiledef.sh" ] || die "clone 失败"
# 上游仓库不带 cachyos-mirrorlist，prepare_profile 靠 curl 拉 GitHub raw，失败会写空文件
mkdir -p "$P/airootfs/etc/pacman.d"
printf '%s\n' 'Server = https://mirror.cachyos.org/repo/$arch/$repo' \
  > "$P/airootfs/etc/pacman.d/cachyos-mirrorlist"

log "4 现场改上游"
python3 - cachyos-archiso <<'PY'
import pathlib, re, sys
r = pathlib.Path(sys.argv[1])

u = r/"util-iso.sh"; s = u.read_text()
s = s.replace('    iso_file=$(gen_iso_fn).iso', '    iso_file="TS_OS.iso"')
ls = s.splitlines()
for i, l in enumerate(ls):
    if l.lstrip().startswith('mv ') and 'cachyos-$(date' in l and 'iso_file' in l:
        ls[i] = '\n'.join([
            '    local _src',
            '    _src="$(find "$outFolder/$_profile" -maxdepth 1 -type f -name \'*.iso\' -printf \'%T@ %p\\n\' | sort -rn | head -1 | cut -d\' \' -f2-)"',
            '    [ -n "$_src" ] || { echo "!! 没找到生成的 ISO" >&2; exit 1; }',
            '    if [ "$_src" != "$outFolder/$_profile/${iso_file}" ]; then',
            '        mv -f "$_src" "$outFolder/$_profile/${iso_file}"',
            '    fi',
        ])
s = "\n".join(ls) + "\n"
s = s.replace('    curl -sSL "${_mirrorlist_url}" > ${src_dir}/archiso/airootfs/etc/pacman.d/cachyos-mirrorlist',
              '    : # mirrorlist 由 ci-build.sh 预置')
s = s.replace('        cp ${src_dir}/archiso/packages_desktop.x86_64 ${src_dir}/archiso/packages.x86_64',
              '        : # packages.x86_64 由 ci-build.sh 直接写入')
s = s.replace('        ln -sf /usr/lib/systemd/system/plasmalogin.service ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service',
              '        : # 不建悬空 display-manager（清单里是 openbox）')
u.write_text(s)

# 无 GPG key 时 sign_with_key 会读 /etc/makepkg.conf，在 buildiso.sh 的 ERR trap 下有风险
sh = r/"util.sh"; t = sh.read_text()
t = t.replace('sign_with_key() {\n',
              'sign_with_key() {\n    return 0  # ci-build.sh: CI 无 GPG key，跳过签名\n', 1)
sh.write_text(t)

p = r/"archiso/profiledef.sh"; d = p.read_text()
for k, v in {'iso_name':'tianshu','iso_label':'TS_OS','iso_publisher':'TS OS',
             'iso_application':'TS OS Live ISO','iso_version':'1.0'}.items():
    d = re.sub(r'^'+k+r'=.*$', k+'="'+v+'"', d, count=1, flags=re.M)
p.write_text(d)

# 清单里只有 linux-cachyos，上游 preset 与引导项全指向不存在的 lts 内核 →
# mkinitcpio 生成 initramfs 必挂。统一改指主内核。
paths = [r/"archiso/airootfs/etc/mkinitcpio.d/linux.preset",
         r/"archiso/grub/grub.cfg", r/"archiso/grub/loopback.cfg"]
paths += sorted((r/"archiso/syslinux").glob("*.cfg"))
paths += sorted((r/"archiso/efiboot/loader/entries").glob("*.conf"))
for f in paths:
    if f.exists():
        f.write_text(f.read_text().replace("linux-cachyos-lts", "linux-cachyos"))
PY
# file_permissions 里唯一上游缺失的文件，补空占位避免 archiso 版本变严时报错
: > "$P/airootfs/usr/local/bin/nvidia-module-loader"
chmod 755 "$P/airootfs/usr/local/bin/nvidia-module-loader"
bash -n cachyos-archiso/util-iso.sh cachyos-archiso/util.sh "$P/profiledef.sh" || die "patch 后语法错"
grep -q 'TS_OS.iso' cachyos-archiso/util-iso.sh || die "util-iso.sh patch 失败"
grep -q '^iso_label="TS_OS"' "$P/profiledef.sh" || die "profiledef.sh patch 失败"
grep -q 'vmlinuz-linux-cachyos' "$P/airootfs/etc/mkinitcpio.d/linux.preset" || die "preset patch 失败"
! grep -rq 'linux-cachyos-lts' "$P/airootfs/etc/mkinitcpio.d" "$P/grub" "$P/syslinux" "$P/efiboot" || die "lts 残留"

log "5 注入"
# 文件名就是 configs/packages.x86_64 → $P/packages.x86_64（上游 cp 已在第 4 步短路）
install -Dm644 configs/packages.x86_64 "$P/packages.x86_64"
if [ -n "${EXTRA_PACKAGES:-}" ]; then
  # shellcheck disable=SC2086
  printf '%s\n' $EXTRA_PACKAGES >> "$P/packages.x86_64"
fi
install -Dm755 scripts/customize_airootfs.sh "$P/airootfs/root/customize_airootfs.sh"
install -Dm755 "$CORE" "$P/airootfs/usr/bin/tianshu_core"
install -Dm644 configs/tianshu.service "$P/airootfs/etc/systemd/system/tianshu.service"
sig "$P/pacman.conf"
[ -f "$P/airootfs/etc/pacman.conf" ] || cp "$P/pacman.conf" "$P/airootfs/etc/pacman.conf"
sig "$P/airootfs/etc/pacman.conf"
find "$P/grub" "$P/syslinux" "$P/efiboot" -type f \
  \( -name '*.cfg' -o -name '*.conf' \) \
  -exec sed -i 's/CachyOS/TS OS/g' {} + 2>/dev/null || true

log "6 收尾"
mkdir -p "$P/airootfs/etc/default"
printf '%s\n' 'GRUB_DISABLE_OS_PROBER=false' >> "$P/airootfs/etc/default/grub"

log "7 mkarchiso"
cd cachyos-archiso
chmod +x buildiso.sh
BL="$(mktemp)"
if [ "${VERBOSE:-0}" = "1" ]; then
  sudo -E ./buildiso.sh -p desktop
else
  if sudo -E ./buildiso.sh -p desktop > "$BL" 2>&1; then
    tail -n 12 "$BL"
  else
    rc=$?; printf '!! buildiso.sh 失败 rc=%s\n' "$rc" >&2
    cat "$BL" >&2; rm -f "$BL"; exit "$rc"
  fi
fi
rm -f "$BL"
cd ..

log "8 收产物"
rm -rf out && mkdir -p out
mapfile -t isos < <(find "$OUT" -type f -name '*.iso' | sort)
(( ${#isos[@]} > 0 )) || die "没有 ISO"
cp -- "${isos[@]}" out/
cd out
case "${COMPRESS:-xz}" in
  xz)   xz -q -9e -T2 -- *.iso ;;
  none) : ;;
  *)    die "COMPRESS 只支持 xz/none" ;;
esac
ls -lh
log "完成"
