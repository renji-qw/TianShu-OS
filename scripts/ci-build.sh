#!/usr/bin/env bash
# 只改本文件。输入只用仓库现成的 configs/ scripts/ core/，不新增任何文件。
# env: COMPRESS=xz(默认)|none / EXTRA_PACKAGES / VERBOSE=1 / KEEP_OFFLINE_IN_ISO=0(才关)
# 推送/切片由 build.yml 的 Split & Release 负责，本脚本只出 out/*.iso.xz
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
pacman -Syy --noconfirm >/dev/null
pacman -S --noconfirm --needed >/dev/null \
  archiso mkinitcpio-archiso git base-devel rustup squashfs-tools \
  grub mtools libisoburn dosfstools syslinux sudo curl musl gettext xz zstd python3

log "2 core"
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
rustup default stable >/dev/null
rustup target add x86_64-unknown-linux-musl >/dev/null
(cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)
CORE="$R/core/target/x86_64-unknown-linux-musl/release/tianshu_core"
[ -x "$CORE" ] || die "缺 $CORE"

log "3 clone"
rm -rf cachyos-archiso
git -c http.sslVerify=false -c credential.helper= clone -q --depth 1 \
  https://github.com/CachyOS/CachyOS-Live-ISO.git cachyos-archiso
[ -f "$P/profiledef.sh" ] || die "clone 失败"

log "4 现场改上游"
python3 - cachyos-archiso <<'PY'
import pathlib, re, sys
r = pathlib.Path(sys.argv[1])
u = r/"util-iso.sh"; s = u.read_text()
s = s.replace('    iso_file=$(gen_iso_fn).iso', '    iso_file="TS_OS.iso"')
ls = s.splitlines()
for i, l in enumerate(ls):
    if l.lstrip().startswith('mv ') and 'cachyos-$(date' in l and 'iso_file' in l:
        ls[i] = '    mv -f "$(find "$outFolder/$_profile" -maxdepth 1 -name "*.iso" -printf "%T@ %p\\n" | sort -rn | head -1 | cut -d" " -f2-)" "$outFolder/$_profile/${iso_file}"'
u.write_text("\n".join(ls) + "\n")
p = r/"archiso/profiledef.sh"; s = p.read_text()
for k, v in {'iso_name':'tianshu','iso_label':'TS_OS','iso_publisher':'TS OS',
             'iso_application':'TS OS Live ISO','iso_version':'1.0'}.items():
    s = re.sub(r'^'+k+r'=.*$', k+'="'+v+'"', s, count=1, flags=re.M)
p.write_text(s)
PY
bash -n cachyos-archiso/util-iso.sh "$P/profiledef.sh" || die "patch 后语法错"
grep -q 'TS_OS.iso' cachyos-archiso/util-iso.sh || die "util-iso.sh patch 失败"
grep -q '^iso_label="TS_OS"' "$P/profiledef.sh" || die "profiledef.sh patch 失败"

log "5 注入"
# prepare_profile 会 cp packages_desktop.x86_64 → packages.x86_64，故写前者
cp configs/packages.x86_64 "$P/packages_desktop.x86_64"
install -Dm755 scripts/customize_airootfs.sh "$P/airootfs/root/customize_airootfs.sh"
install -Dm755 "$CORE" "$P/airootfs/usr/bin/tianshu_core"
install -Dm644 configs/tianshu.service "$P/airootfs/etc/systemd/system/tianshu.service"
if [ -n "${EXTRA_PACKAGES:-}" ]; then
  # shellcheck disable=SC2086
  printf '%s\n' $EXTRA_PACKAGES >> "$P/packages_desktop.x86_64"
fi
sig "$P/pacman.conf"
[ -f "$P/airootfs/etc/pacman.conf" ] || cp "$P/pacman.conf" "$P/airootfs/etc/pacman.conf"
sig "$P/airootfs/etc/pacman.conf"
find "$P/grub" "$P/syslinux" "$P/efiboot" -type f \
  \( -name '*.cfg' -o -name '*.conf' \) \
  -exec sed -i 's/CachyOS/TS OS/g' {} + 2>/dev/null || true

log "6 离线仓库(进ISO)"
K="${KEEP_OFFLINE_IN_ISO:-1}"
if [ "$K" = "1" ]; then OFF="$P/airootfs/opt/offline_repo"
else OFF="$R/cachyos-archiso/offline_cache"; fi
mkdir -p "$OFF"   # 372 行根因
if [ "$K" = "1" ]; then
  mapfile -t pl < <(awk 'NF && $1 !~ /^#/ {print $1}' "$P/packages_desktop.x86_64")
  (( ${#pl[@]} > 0 )) || die "包清单为空"
  # 宿主默认只有 Arch 官方仓库，cachyos-* 及桌面依赖链解析不全 → could not satisfy dependencies
  # 直接用 clone 出来的官方完整配置（buildiso.sh 自己就用它）
  cp "$P/pacman.conf" /etc/pacman.conf
  [ -d "$P/airootfs/etc/pacman.d" ] && cp -r "$P/airootfs/etc/pacman.d/." /etc/pacman.d/ 2>/dev/null || true
  sig /etc/pacman.conf
  pacman -Syy --noconfirm >/dev/null || die "刷新仓库失败"
  pacman -Syw --noconfirm --cachedir "$OFF" "${pl[@]}"
  mapfile -t ps < <(find "$OFF" -maxdepth 1 -name '*.pkg.tar.zst' | sort)
  (( ${#ps[@]} > 0 )) || die "离线包为空"
  repo-add "$OFF/offline_repo.db.tar.gz" "${ps[@]}" >/dev/null
  [ -e "$OFF/offline_repo.db" ] || ln -s offline_repo.db.tar.gz "$OFF/offline_repo.db"
fi

log "7 收尾"
mkdir -p "$P/airootfs/etc/default"
printf '%s\n' 'GRUB_DISABLE_OS_PROBER=false' >> "$P/airootfs/etc/default/grub"

log "8 mkarchiso"
cd cachyos-archiso
chmod +x buildiso.sh
BL="$(mktemp)"
if [ "${VERBOSE:-0}" = "1" ]; then
  sudo -E ./buildiso.sh -p desktop || { cd ..; exit $?; }
elif sudo -E ./buildiso.sh -p desktop > "$BL" 2>&1; then
  tail -n 12 "$BL"
else
  rc=$?; printf '!! buildiso.sh 失败 rc=%s\n' "$rc" >&2
  cat "$BL" >&2; rm -f "$BL"; exit "$rc"
fi
rm -f "$BL"
cd ..

log "9 收产物"
rm -rf out && mkdir -p out
mapfile -t isos < <(find "$OUT" -type f -name '*.iso' | sort)
(( ${#isos[@]} > 0 )) || die "没有 ISO"
cp -- "${isos[@]}" out/
cd out
# 必须出 *.iso.xz：build.yml 的 Split & Release 只 find 这个后缀
case "${COMPRESS:-xz}" in
  xz)   xz -q -9e -T2 -- *.iso ;;
  none) : ;;
  *)    die "COMPRESS 只支持 xz/none" ;;
esac
ls -lh
log "完成"
