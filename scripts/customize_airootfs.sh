#!/usr/bin/env bash
# TianShu OS — airootfs 定制脚本（mkarchiso 的 chroot 内以 root 执行）
# 刻意只用 set -uo pipefail：chroot 里个别非关键命令失败不应中断整个 ISO 构建，
# 需要关注的地方用 warn 单独打出来。
set -uo pipefail

say()  { printf '[TianShu] %s\n' "$*"; }
warn() { printf '[TianShu][warn] %s\n' "$*" >&2; }

say "清理文档与缓存（减小 squashfs 体积）"
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null || true
rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* /tmp/* 2>/dev/null || true
# 不要动 /etc/mkinitcpio.conf 的 HOOKS，也不要在这里跑 mkinitcpio -P。
# CachyOS 的 archiso hooks 放在 /etc/mkinitcpio.conf.d/archiso.conf：
#   HOOKS=(base udev microcode modconf memdisk archiso archiso_loop_mnt ...)
# 旧脚本把 HOOKS 改成普通桌面配置并重建 initramfs，会丢掉 archiso hook，
# Live 启动时挂不上 airootfs。保持官方 drop-in 配置不动即可。

say "中文本地化 / 时区 / 系统标识"
echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
locale-gen >/dev/null 2>&1 || warn "locale-gen 失败"
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
printf 'NAME="TianShu OS"\nID=tianshu\nID_LIKE=arch\n' > /etc/os-release

say "boost_python 兼容软链"
L="$(ls /usr/lib/libboost_python3*.so* 2>/dev/null | head -n 1 || true)"
if [ -n "$L" ]; then
    ln -sf "/usr/lib/$(basename "$L")" /usr/lib/libboost_python314.so.1.91 2>/dev/null \
        || warn "boost_python 软链创建失败"
fi

say "注册离线仓库"
# 段名 [offline_repo] 必须与 ci-build.sh 里 repo-add 生成的
# offline_repo.db.tar.gz 对应，否则 pacman 找不到仓库数据库。
if [ -d /opt/offline_repo ] && ! grep -q '^\[offline_repo\]' /etc/pacman.conf; then
    printf '\n[offline_repo]\nSigLevel = Optional TrustAll\nServer = file:///opt/offline_repo\n' \
        >> /etc/pacman.conf
fi

say "tty1 自动登录"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

say "生成桌面安装引导"
# 用带引号的 heredoc，避开多层 printf 转义（原版 .xinitrc 会写出多余反斜杠）
cat > /root/.bash_profile <<'PROFILE'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    clear
    cat > /root/.xinitrc <<'XINITRC'
#!/bin/sh
openbox-session &
sudo calamares
xterm -hold -e "echo '安装器已退出。请重启电脑。'"
XINITRC
    chmod +x /root/.xinitrc
    startx
fi
PROFILE

say "启用系统服务"
# tianshu_core 已由 ci-build.sh 在宿主机注入 airootfs/usr/bin/，
# chroot 里没有 /work，原来的 install /work/... 必然失败且被 || true 吞掉。
if [ -x /usr/bin/tianshu_core ]; then
    say "tianshu_core 已就位"
else
    warn "缺少 /usr/bin/tianshu_core，tianshu.service 会启动失败"
fi
systemctl enable tianshu.service 2>/dev/null || warn "tianshu.service 启用失败"
systemctl enable NetworkManager 2>/dev/null || warn "NetworkManager 启用失败"
systemctl enable systemd-zram-setup@zram0.service 2>/dev/null \
    || warn "zram 单元启用失败（缺 zram-generator 时属正常）"

say "收尾清理"
rm -rf /var/cache/pacman/pkg/* /tmp/* /root/.cache/* 2>/dev/null || true
