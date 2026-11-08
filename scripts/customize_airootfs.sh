#!/usr/bin/env bash
# TianShu OS — airootfs 定制脚本（在 archiso chroot 内以 root 执行）
set -uo pipefail

echo "==> [TianShu] 清理运行环境（减小 squashfs 体积）"
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null || true
rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* /tmp/* 2>/dev/null || true
rm -f /etc/pacman.d/mirrorlist.pacnew 2>/dev/null || true

echo "==> [TianShu] 中文本地化"
echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

echo "==> [TianShu] 写入系统身份证 (OS Release)"
cat > /etc/os-release <<'EOF'
NAME="TianShu OS"
PRETTY_NAME="TianShu OS (Lilac) 1.0beta"
ID=tianshu
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;226;208;232"
HOME_URL="https://github.com/renji-qw/TianShu-OS"
VERSION_ID=1.0beta
VERSION="1.0beta (Lilac)"
VERSION_CODENAME=lilac
EOF

mkdir -p /etc/xdg
cat > /etc/xdg/kcm-about-distrorc <<'EOF'
[General]
Name=TianShu OS
Website=https://github.com/renji-qw/TianShu-OS
LogoPath=/usr/share/pixmaps/tianshu-logo.png
EOF

echo "==> [TianShu] 内核参数极限调优 (专为老旧硬件优化)"
cat > /etc/sysctl.d/99-tianshu.conf <<'EOF'
# 内存与交换（配合ZRAM）
vm.swappiness=10
vm.vfs_cache_pressure=50
# 磁盘IO优化（防老机械硬盘/廉价固态卡死）
vm.dirty_ratio=5
vm.dirty_background_ratio=2
# 网络与内存大页
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
vm.nr_hugepages=128
EOF
sysctl --system >/dev/null 2>&1 || true

echo "==> [TianShu] 限制日志体积（死保16G固态不被日志塞满）"
mkdir -p /etc/systemd
cat > /etc/systemd/journald.conf <<'EOF'
[Journal]
SystemMaxUse=50M
SystemKeepFree=100M
RuntimeMaxUse=50M
EOF

echo "==> [TianShu] zram 交换（双形态自适应）"
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

echo "==> [TianShu] TLP 电源策略"
mkdir -p /etc/tlp.d
cat > /etc/tlp.d/00-tianshu.conf <<'EOF'
TLP_ENABLE=1
TLP_DEFAULT_MODE=AC
CPU_SCALING_GOVERNOR_ON_AC=schedutil
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
EOF

echo "==> [TianShu] 屏蔽无关服务（彻底斩断资源消耗）"
for unit in cups cups-browsed avahi-daemon bluetooth baloo_file; do
    systemctl mask "${unit}.service" 2>/dev/null || true
done

echo "==> [TianShu] 镜像源测速优选"
if command -v reflector >/dev/null 2>&1; then
    timeout 60 reflector --country China --latest 20 --sort rate --protocol https --save /etc/pacman.d/mirrorlist 2>/dev/null \
        || echo "    reflector 超时或离线，保留原镜像列表"
fi

echo "==> [TianShu] 紫罗兰 KDE 配置注入 /etc/skel"
if [ -d /etc/tianshu/skel ]; then
    mkdir -p /etc/skel/.config
    cp -rf /etc/tianshu/skel/. /etc/skel/
    chown -R root:root /etc/skel
    chmod -R a+rX /etc/skel
fi
mkdir -p /etc/sddm.conf.d
[ -f /etc/tianshu/sddm.conf ] && cp -f /etc/tianshu/sddm.conf /etc/sddm.conf.d/10-tianshu.conf

echo "==> [TianShu] 启用系统服务"
systemctl enable tianshu.service
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable tlp.service
systemctl enable systemd-zram-setup@zram0.service 2>/dev/null || true
systemctl enable fstrim.timer 2>/dev/null || true

echo "==> [TianShu] 极限清理残留"
rm -rf /var/cache/pacman/pkg/* 2>/dev/null || true
rm -rf /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* /tmp/* 2>/dev/null || true

echo "==> [TianShu] 配置 Live 环境：开机直进安装器"

# 1. 禁用 SDDM，Live 环境不需要它
systemctl disable sddm

# 2. 让 tty1 终端自动以 root 登录
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

# 3. 配置 root 用户登录后，自动启动图形界面并拉起安装器
cat > /root/.bash_profile <<'EOF'
# 如果还没进入图形界面，就执行 startx
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx /usr/bin/calamares
fi
EOF
