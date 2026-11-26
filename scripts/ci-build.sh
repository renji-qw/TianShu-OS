#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 紫枢联合组织 / TianShu OS Project
#
# 天枢 OS —— 构建脚本（Debian stable/trixie + live-build，全白牌）
#
#   容器：debian:trixie
#   流程：lb config → 放 package-lists / hooks / 白牌资源 → lb build
#   产出：out/tianshu-<edition>-<ver>.iso.xz（幻境版先出，轻量版随后）
#
# 与旧版（CachyOS/archiso）的差别：
#   * 不再有 pacman / SigLevel / mirrorlist / archiso / mkinitcpio / clone CachyOS-Live-ISO
#   * 不再有改 util-iso.sh、util.sh、profiledef.sh 的 python 脏活
#   * core 一律 rustup + RsProxy 编 x86_64-unknown-linux-musl 静态产物，不用 apt 的 rustc
set -euo pipefail

R="$(cd "${WORKSPACE:-/work}" && pwd)"
OUT="$R/out"
LIVE="$R/.live"          # live-build 工作区（临时，不入库）
STAGE="$R/.stage"        # 脚本生成的白牌资源（临时，不入库）
VER="2.0.0-debian-alpha"
CORE=""

log(){ printf '==> %s\n' "$*"; }
warn(){ printf '!! %s\n' "$*" >&2; }
die(){ printf '!! %s\n' "$*" >&2; exit 1; }

export TZ=UTC USER="${USER:-root}"
export DEBIAN_FRONTEND=noninteractive
cd "$R"

# ---------------------------------------------------------------- 0 自检
log "0 环境自检"
for f in configs/tianshu.service \
         config/package-lists/tianshu-base.list.chroot \
         config/package-lists/tianshu-huanjing.list.chroot \
         config/package-lists/tianshu-qingliang.list.chroot \
         config/hooks/normal/0100-tianshu.chroot \
         config/hooks/normal/0200-tianshu-grub.binary; do
    [ -f "$f" ] || die "缺 $f"
done
[ -d configs/kde ] || die "缺 configs/kde"

# ---------------------------------------------------------------- 1 依赖（apt 源走 USTC）
log "1 依赖（apt 源 → USTC）"
# 注：海外跑机到 USTC 的 TLS 链路常被干扰（证书校验失败），apt 仓完整性由
# InRelease 的 GPG 签名保证，故源走 http；USTC 取不到索引时回落 deb.debian.org。
set_apt_sources() { # $1=debian 源  $2=security 源
    local f
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [ -f "$f" ] || continue
        sed -i -E \
            -e "s|https?://deb\\.debian\\.org/debian-security|$2|g" \
            -e "s|https?://security\\.debian\\.org/debian-security|$2|g" \
            -e "s|https?://mirrors\\.ustc\\.edu\\.cn/debian-security|$2|g" \
            -e "s|https?://deb\\.debian\\.org/debian|$1|g" \
            -e "s|https?://security\\.debian\\.org/debian|$1|g" \
            -e "s|https?://mirrors\\.ustc\\.edu\\.cn/debian|$1|g" "$f"
    done
}
MIRROR="http://mirrors.ustc.edu.cn/debian"
MIRROR_SEC="http://mirrors.ustc.edu.cn/debian-security"
set_apt_sources "$MIRROR" "$MIRROR_SEC"
apt-get update -qq || true
if ! apt-cache show live-build >/dev/null 2>&1; then
    warn "USTC 源取不到索引，回落 deb.debian.org"
    MIRROR="http://deb.debian.org/debian"
    MIRROR_SEC="http://deb.debian.org/debian-security"
    set_apt_sources "$MIRROR" "$MIRROR_SEC"
    apt-get update -qq || die "apt 源均不可用"
fi
# live-build + 构建工具链 + 开机动画 + logo 生成（PIL/CJK 字体）
# 说明：apt 的 rustc 一概不用，core 走 rustup。
# libc6-dev 必须显式装：trixie 的 gcc 不硬依赖它，而宿主 build script 链接
# 需要它提供的 crt 对象（Scrt1.o/crti.o/crtn.o）与 libc.so 桩。
apt-get install -y --no-install-recommends \
    live-build debootstrap squashfs-tools xorriso grub2-common grub-efi-amd64-bin \
    mtools dosfstools plymouth plymouth-themes \
    python3 python3-pil python3-fonttools fonts-noto-cjk \
    gcc libc6-dev musl-tools ca-certificates curl xz-utils

# ---------------------------------------------------------------- 2 core（rustup + RsProxy）
log "2 core（rustup + RsProxy → x86_64-unknown-linux-musl）"
export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
if ! command -v rustup >/dev/null 2>&1 && [ ! -x /root/.cargo/bin/rustup ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://rsproxy.cn/rustup-init.sh -o /tmp/rustup-init.sh \
        || curl -sSf https://sh.rustup.rs -o /tmp/rustup-init.sh
    # 只装 rustup 本体；工具链交给下面带回落的 install_toolchain，
    # 避免 init 阶段 RsProxy 被跨境链路重置时整个构建暴毙
    sh /tmp/rustup-init.sh -y --no-modify-path --profile minimal --default-toolchain none
fi
export PATH="/root/.cargo/bin:${PATH}"
install_toolchain() {
    rustup default stable && rustup target add x86_64-unknown-linux-musl
}
# RsProxy 跨境链路可能被 TLS 干扰/连接重置：先重试，仍不行回落官方源（仍走 rustup，不用 apt 的 rustc）
ok=0
for try in 1 2 3; do
    if install_toolchain; then ok=1; break; fi
    warn "rustup 工具链安装失败（第 ${try} 次）"
    sleep 5
done
if [ "$ok" != 1 ]; then
    warn "RsProxy 不可用，rustup 回落官方源"
    export RUSTUP_DIST_SERVER="https://static.rust-lang.org"
    export RUSTUP_UPDATE_ROOT="https://static.rust-lang.org/rustup"
    install_toolchain || die "rustup 工具链安装失败（官方源也不可用）"
fi
if ! (cd core && RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl); then
    # musl 链接器兜底（部分环境需要显式 musl-gcc）
    (cd core && CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=musl-gcc \
        RUSTFLAGS="-C target-cpu=x86-64" cargo build --release --target x86_64-unknown-linux-musl)
fi
CORE="$R/core/target/x86_64-unknown-linux-musl/release/tianshu_core"
[ -x "$CORE" ] || die "缺 $CORE"

# ---------------------------------------------------------------- 3 生成天枢标识
log "3 生成天枢标识（脚本生成，不依赖外部素材）"
rm -rf "$STAGE"
mkdir -p "$STAGE"
TIANSHU_REPO="$R" python3 - "$STAGE" <<'PY'
import os, sys, shutil
from PIL import Image, ImageDraw, ImageFont

STAGE = sys.argv[1]
REPO  = os.environ.get("TIANSHU_REPO", ".")

V1 = (226, 208, 232)   # #E2D0E8 第一阶
V2 = (216, 209, 230)   # #D8D1E6 第二阶
V3 = (206, 197, 219)   # #CEC5DB 第三阶
INK = (42, 36, 56)     # #2A2438 墨

def font_candidates():
    # 优先仓库内手写体（后续放入，须为 OFL 等自由授权）
    cands = [os.path.join(REPO, "assets", "tianshu-font.ttf")]
    cands += [
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
        "/usr/share/fonts/truetype/arphic/uming.ttc",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    return [c for c in cands if os.path.exists(c)]

def load_font(size):
    for path in font_candidates():
        for idx in (2, 1, 0):
            try:
                return ImageFont.truetype(path, size, index=idx), path
            except Exception:
                continue
        try:
            return ImageFont.truetype(path, size), path
        except Exception:
            continue
    return None, None

def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGB", (1, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(h - 1, 1)
        if t < 0.55:
            u = t / 0.55
            c = tuple(int(top[i] + (bottom[i] - top[i]) * u) for i in range(3))
        else:
            u = (t - 0.55) / 0.45
            c = tuple(int(V2[i] + (V3[i] - V2[i]) * u) for i in range(3))
        d.point((0, y), fill=c)
    return img.resize((w, h), Image.BICUBIC)

def seal_mark(draw, cx, cy, r, color):
    # 无字体时的几何兜底：方印构图（不含任何拉丁字母）
    draw.rectangle([cx - r, cy - r, cx + r, cy + r], outline=color, width=3)
    draw.line([cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5], fill=color, width=3)
    draw.line([cx + r * 0.5, cy - r * 0.5, cx - r * 0.5, cy + r * 0.5], fill=color, width=3)

def draw_logo(path, size):
    w, h = size
    img = gradient(size, V1, V3).convert("RGBA")
    d = ImageDraw.Draw(img)
    # 柔性光晕
    halo = Image.new("RGBA", size, (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse([w * 0.18, h * 0.10, w * 0.82, h * 0.90], fill=(255, 255, 255, 46))
    img = Image.alpha_composite(img, halo)
    d = ImageDraw.Draw(img)

    glyph = int(h * 0.26)
    font, path_used = load_font(glyph)
    cx = w // 2
    if font is None:
        seal_mark(d, cx, h // 2, int(h * 0.16), INK)
    else:
        step = int(glyph * 1.08)
        total = step * 2
        top = h // 2 - total // 2
        for i, ch in enumerate("天枢"):
            bb = d.textbbox((0, 0), ch, font=font)
            gw, gh = bb[2] - bb[0], bb[3] - bb[1]
            d.text((cx - gw / 2 - bb[0], top + i * step - bb[1]), ch, font=font, fill=INK)
    img.save(path)
    return path_used

def dot(path, color, size=32):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = size // 2
    d.ellipse([4, 4, size - 5, size - 5], fill=color)
    img.save(path)

def password_field(path, size=(380, 56)):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=12,
                        fill=(255, 255, 255, 190), outline=V2 + (235,), width=3)
    d.line([18, size[1] - 18, size[0] - 18, size[1] - 18], fill=INK + (110,), width=2)
    img.save(path)

ply = os.path.join(STAGE, "usr/share/plymouth/themes/tianshu")
cal = os.path.join(STAGE, "usr/share/calamares/branding/tianshu")
bg  = os.path.join(STAGE, "usr/share/backgrounds")
ico = os.path.join(STAGE, "usr/share/icons/hicolor/256x256/apps")
th  = os.path.join(STAGE, "boot/grub/themes/tianshu")
spl = os.path.join(STAGE, "bootloaders")
for p in (ply, cal, bg, ico, th, spl):
    os.makedirs(p, exist_ok=True)

used_font = draw_logo(os.path.join(ply, "tianshu-logo.png"), (640, 480))
draw_logo(os.path.join(spl, "splash.png"), (800, 600))
shutil.copy(os.path.join(ply, "tianshu-logo.png"), os.path.join(bg, "tianshu-logo.png"))
shutil.copy(os.path.join(ply, "tianshu-logo.png"), os.path.join(cal, "logo.png"))
shutil.copy(os.path.join(ply, "tianshu-logo.png"), os.path.join(ico, "tianshu-logo.png"))
shutil.copy(os.path.join(ply, "tianshu-logo.png"), os.path.join(th, "tianshu-logo.png"))

dot(os.path.join(ply, "progress_dot_on.png"),  INK + (255,))
dot(os.path.join(ply, "progress_dot_off.png"), V3 + (255,))
password_field(os.path.join(ply, "password_field.png"))

# 安装后的系统所用 GRUB 主题（/boot/grub/themes/tianshu）
with open(os.path.join(th, "theme.txt"), "w", encoding="utf-8") as f:
    f.write(
        'desktop-image: "tianshu-logo.png"\n'
        'title-color: "#2A2438"\n'
        'title-font: "Unifont Regular 16"\n'
        'title-text: "天枢 OS"\n'
        'message-font: "Unifont Regular 16"\n'
        'terminal-font: "Unifont Regular 16"\n'
        '+ boot_menu {\n'
        '        left = 10%\n'
        '        width = 80%\n'
        '        top = 52%\n'
        '        height = 48%-80\n'
        '        item_color = "#2A2438"\n'
        '        selected_item_color = "#2A2438"\n'
        '        item_height = 16\n'
        '        item_padding = 0\n'
        '        item_spacing = 4\n'
        '}\n'
    )

# 开机动画所需的中文字体：仓库手写体优先，否则系统 CJK 字体做子集（只留「天枢」二字）
def subset_font(dest):
    src = None
    repo_font = os.path.join(REPO, "assets", "tianshu-font.ttf")
    cands = [repo_font] + [c for c in font_candidates() if c != repo_font]
    for c in cands:
        if os.path.exists(c):
            src = c
            break
    if src is None:
        return None
    try:
        from fontTools import subset
        options = subset.Options()
        options.font_number = 0
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.name_legacy = True
        options.name_languages = ["*"]
        options.notdef_outline = True
        options.recalc_bounds = True
        options.drop_tables = []
        font = subset.load_font(src, options)
        s = subset.Subsetter(options=options)
        s.populate(text="天枢")
        s.subset(font)
        subset.save_font(font, dest, options)
        return src
    except Exception:
        shutil.copy(src, dest)
        return src

# ---- 内核早期 fallback（无 KMS）：16×16 单色 PPM + 帧缓冲控制台横幅 ----
# tianshu-logo.ppm 为纯黑白 P3；有则登录横幅用其衍生图形，无则退文字模式。
tsd = os.path.join(STAGE, "usr/share/tianshu")
os.makedirs(tsd, exist_ok=True)
N = 16
grid = [[0] * N for _ in range(N)]
mono = Image.new("L", (N, N), 0)
md = ImageDraw.Draw(mono)
md.rectangle([0, 0, N - 1, N - 1], outline=255)
font16, _ = load_font(7)
if font16 is not None:
    for i, ch in enumerate("天枢"):
        bb = md.textbbox((0, 0), ch, font=font16)
        gw, gh = bb[2] - bb[0], bb[3] - bb[1]
        md.text(((N - gw) / 2 - bb[0], 1 + i * 7 - bb[1]), ch, font=font16, fill=255)
else:
    # 方印几何兜底（不含任何拉丁字母）
    md.line([3, 4, 12, 4], fill=255)
    md.line([3, 6, 12, 6], fill=255)
    md.line([7, 2, 7, 13], fill=255)
    md.line([3, 10, 12, 10], fill=255)
    md.point([(4, 12), (5, 12), (10, 12), (11, 12)], fill=255)
mp = mono.load()
for y in range(N):
    for x in range(N):
        grid[y][x] = 1 if mp[x, y] >= 128 else 0
with open(os.path.join(tsd, "tianshu-logo.ppm"), "w", encoding="ascii") as f:
    f.write("P3\n%d %d\n255\n" % (N, N))
    for y in range(N):
        f.write(" ".join("255 255 255" if grid[y][x] else "0 0 0" for x in range(N)) + "\n")
# 登录横幅由同一 16×16 位图衍生（半块字符，纯文本，帧缓冲控制台可见）
rows = []
for y in range(0, N, 2):
    row = ""
    for x in range(N):
        t, b = grid[y][x], grid[y + 1][x]
        row += "█" if (t and b) else "▀" if t else "▄" if b else " "
    rows.append(row)
with open(os.path.join(tsd, "issue.banner"), "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")

font_src = subset_font(os.path.join(ply, "tianshu-cjk.ttf"))
print("[TianShu] 标识字体：%s" % (font_src if font_src else "未找到（退化为几何方印）"))
PY
[ -f "$STAGE/usr/share/plymouth/themes/tianshu/tianshu-logo.png" ] || die "标识生成失败"

# ---------------------------------------------------------------- 4 双版构建
build_edition() {
    local ed="$1" label="$2" listfile="$3"
    log "4 [$label] lb config"
    cd "$LIVE"
    lb clean >/dev/null 2>&1 || true
    rm -rf config
    lb config \
        --architectures amd64 \
        --distribution trixie \
        --archive-areas "main contrib non-free non-free-firmware" \
        --binary-images iso-hybrid \
        --bootloaders "grub-efi,grub-pc" \
        --debian-installer none \
        --source false \
        --apt-indices false \
        --linux-flavours amd64 \
        --iso-application "TianShu OS" \
        --iso-publisher "Zishu Alliance" \
        --iso-volume "TIANSHU_OS" \
        --image-name "tianshu-$ed-$VER" \
        --bootappend-live "boot=live components quiet splash username=tianshu hostname=tianshu locales=zh_CN.UTF-8 timezone=Asia/Shanghai" \
        --mirror-bootstrap "${MIRROR}/" \
        --mirror-chroot "${MIRROR}/" \
        --mirror-chroot-security "${MIRROR_SEC}/" \
        --mirror-binary "${MIRROR}/" \
        --mirror-binary-security "${MIRROR_SEC}/"

    log "4 [$label] 放 package-lists / hooks / 白牌资源"
    mkdir -p config/package-lists config/hooks/normal config/bootloaders
    install -Dm644 "$R/config/package-lists/tianshu-base.list.chroot" \
        "config/package-lists/00-tianshu-base.list.chroot"
    install -Dm644 "$R/config/package-lists/$listfile" "config/package-lists/10-$listfile"
    install -Dm755 "$R/config/hooks/normal/0100-tianshu.chroot" \
        "config/hooks/normal/0100-tianshu.chroot"
    install -Dm755 "$R/config/hooks/normal/0200-tianshu-grub.binary" \
        "config/hooks/normal/0200-tianshu-grub.binary"

    # 白牌资源：仓库内 includes.chroot + 脚本生成物
    rm -rf config/includes.chroot
    cp -a "$R/config/includes.chroot" config/includes.chroot
    cp -a "$STAGE/." config/includes.chroot/

    # 三阶紫罗兰视觉：configs/kde 原样投放，一字不改
    install -Dm644 "$R/configs/kde/kdeglobals"            config/includes.chroot/etc/xdg/kdeglobals
    install -Dm644 "$R/configs/kde/kwinrc"                config/includes.chroot/etc/xdg/kwinrc
    install -Dm644 "$R/configs/kde/TianShuPurple.colors"  config/includes.chroot/usr/share/color-schemes/TianShuPurple.colors
    install -Dm644 "$R/configs/kde/sddm.conf"             config/includes.chroot/etc/sddm.conf.d/00-tianshu.conf
    install -Dm644 "$R/configs/kde/sddm/Main.qml"         config/includes.chroot/usr/share/sddm/themes/tianshu/Main.qml
    install -Dm644 "$R/configs/kde/sddm/theme.conf"       config/includes.chroot/usr/share/sddm/themes/tianshu/theme.conf
    install -Dm644 "$R/configs/kde/latte/TianShuViolet.layout" \
        config/includes.chroot/etc/skel/.config/latte/TianShuViolet.layout

    # core 与用户态服务
    install -Dm755 "$CORE" config/includes.chroot/usr/bin/tianshu_core
    install -Dm644 "$R/configs/tianshu.service" config/includes.chroot/usr/lib/systemd/user/tianshu.service

    # GRUB 白牌模板 + 启动画面
    rm -rf config/bootloaders/grub-pc
    cp -a "$R/config/bootloaders/grub-pc" config/bootloaders/grub-pc
    install -Dm644 "$STAGE/bootloaders/splash.png" config/bootloaders/grub-pc/splash.png

    # 逐版策略：幻境版不挂 memguard，轻量版默认挂
    case "$ed" in
        huanjing) sed -i 's/^ENABLED=.*/ENABLED=0/' config/includes.chroot/etc/tianshu/memguard.conf ;;
        qingliang) sed -i 's/^ENABLED=.*/ENABLED=1/' config/includes.chroot/etc/tianshu/memguard.conf ;;
    esac

    log "4 [$label] lb build"
    if [ "${VERBOSE:-0}" = "1" ]; then
        lb build
    else
        local blog="/tmp/ts-lb-$ed.log"
        if ! lb build >"$blog" 2>&1; then
            printf '!! lb build 失败（%s），日志尾部：\n' "$label" >&2
            tail -n 60 "$blog" >&2
            exit 1
        fi
        tail -n 6 "$blog"
    fi

    log "4 [$label] 收产物"
    local iso
    # 产物落 live-build 工作区根：tianshu-<ed>-<ver>-amd64.hybrid.iso
    iso="$(find "$LIVE" -maxdepth 1 -type f \( -name '*.iso' -o -name '*.hybrid.iso' \) 2>/dev/null | sort | head -1)"
    [ -n "$iso" ] || die "没有 ISO 产出（$label）"
    cp -f "$iso" "$OUT/tianshu-$ed-$VER.iso"
    rm -f "$iso"
    # 立刻压缩并释放空间（workflow 切片逻辑针对 *.iso.xz）
    (cd "$OUT" && xz -q -3 -T2 -- "tianshu-$ed-$VER.iso")
    rm -f "$OUT/tianshu-$ed-$VER.iso"
}

mkdir -p "$OUT" "$LIVE"
rm -rf "$OUT"/*
build_edition huanjing  "幻境版" tianshu-huanjing.list.chroot
build_edition qingliang "轻量版" tianshu-qingliang.list.chroot

# ---------------------------------------------------------------- 5 收尾
log "5 产物"
cd "$OUT"
ls -lh
shopt -s nullglob
isos=( *.iso.xz )
((${#isos[@]} > 0)) || die "out/ 里没有产物"
log "完成"
