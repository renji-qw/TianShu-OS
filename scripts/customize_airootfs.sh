#!/usr/bin/env bash
# TianShu OS — airootfs 定制脚本（在 archiso chroot 内以 root 执行）
set -uo pipefail

echo "==> [TianShu] 清理运行环境（减小 squashfs 体积）"
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null || true
rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* /tmp/* 2>/dev/null || true
rm -f /etc/pacman.d/mirrorlist.pacnew 2>/dev/null || true

echo "==> [TianShu] 禁用 fallback initramfs（省空间）"
rm -f /boot/initramfs-linux-fallback.img 2>/dev/null || true
sed -i 's/^PRESETS=(.*)/PRESETS=("default")/' /etc/mkinitcpio.d/linux.preset 2>/dev/null || true

echo "==> [TianShu] 中文本地化"
echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen
locale-gen

echo "==> [TianShu] 写入系统身份证 (OS Release)"
cat > /etc/os-release <<'EOF'
NAME="TianShu OS"
PRETTY_NAME="TianShu OS (Lilac) 1.0.1-beta"
ID=tianshu
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;226;208;232"
HOME_URL="https://github.com/renji-qw/TianShu-OS"
VERSION_ID=1.0.1-beta
VERSION="1.0.1-beta (Lilac)"
VERSION_CODENAME=lilac
EOF

mkdir -p /etc/xdg
cat > /etc/xdg/kcm-about-distrorc <<'EOF'
[General]
Name=TianShu OS
Website=https://github.com/renji-qw/TianShu-OS
LogoPath=/usr/share/pixmaps/tianshu-logo.png
EOF

echo "==> [TianShu] 内核参数极限调优 (修复了 HugePages 内存炸弹)"
cat > /etc/sysctl.d/99-tianshu.conf <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=5
vm.dirty_background_ratio=2
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system >/dev/null 2>&1 || true

echo "==> [TianShu] 限制日志体积"
mkdir -p /etc/systemd
cat > /etc/systemd/journald.conf <<'EOF'
[Journal]
SystemMaxUse=50M
SystemKeepFree=100M
RuntimeMaxUse=50M
EOF

echo "==> [TianShu] zram 交换"
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
EOF

echo "==> [TianShu] 屏蔽无关服务"
for unit in cups cups-browsed avahi-daemon bluetooth baloo_file; do
    systemctl mask "${unit}.service" 2>/dev/null || true
done

echo "==> [TianShu] 注入紫罗兰 KDE 配置与赛博彩蛋"
if [ -d /etc/tianshu/skel ]; then
    mkdir -p /etc/skel/.config
    cp -rf /etc/tianshu/skel/. /etc/skel/
    chown -R root:root /etc/skel
    chmod -R a+rX /etc/skel
fi
mkdir -p /etc/sddm.conf.d
[ -f /etc/tianshu/sddm.conf ] && cp -f /etc/tianshu/sddm.conf /etc/sddm.conf.d/10-tianshu.conf

cat > /etc/motd <<'EOF'

  \033[38;2;226;208;232m欢迎来到天枢OS (TianShu OS)\033[0m
  "让这朵紫丁香，在每一块垂死的硅片上重新绽放。"

EOF
echo -e '\necho -e "\\033[38;2;226;208;232m[天枢引擎已就绪] 讲不通物理，就用物理来讲。\\033[0m"' >> /etc/skel/.bashrc

echo "==> [TianShu] 启用系统服务 (仅启用非 Live 专属服务)"
systemctl enable tianshu.service
systemctl enable NetworkManager
systemctl enable tlp.service
systemctl enable systemd-zram-setup@zram0.service 2>/dev/null || true
systemctl enable fstrim.timer 2>/dev/null || true
# 不在 Live 环境启用 sddm
systemctl disable sddm 2>/dev/null || true

echo "==> [TianShu] 配置 Live 环境自动登录"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
EOF

echo "==> [TianShu] 注入灵动安装引导和快捷命令"
cat > /usr/local/bin/start-desktop <<'EOF'
#!/bin/bash
echo "正在启动紫罗兰 KDE 桌面..."
systemctl start sddm
EOF
chmod +x /usr/local/bin/start-desktop

cat > /root/.bash_profile <<'EOF'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    clear
    for i in {1..3}; do
        echo -e "\033[38;2;100;80;120m  ·  ·  ·\r"
        sleep 0.2
        echo -e "\033[38;2;180;150;200m  ✦  ✦  ✦\r"
        sleep 0.2
        echo -e "\033[38;2;226;208;232m  ✧  ✧  ✧\r"
        sleep 0.2
    done
    
    clear
    echo -e "\033[38;2;226;208;232m"
    msg="[ 正在唤醒天枢OS 涌现式动力学引擎... ]"
    for ((i=0; i<${#msg}; i++)); do echo -n "${msg:$i:1}"; sleep 0.02; done
    echo -e "\n"
    msg2="[ 引擎已启动，开始物理超度准备 ]"
    for ((i=0; i<${#msg2}; i++)); do echo -n "${msg2:$i:1}"; sleep 0.02; done
    echo -e "\n\033[0m"
    
    # 智能探测镜像源
    echo -e "正在寻找最快的软件源..."
    M1="https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch"
    M2="https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch"
    M3="https://mirrors.aliyun.com/archlinux/\$repo/os/\$arch"
    
    T1=$(curl -o /dev/null -s -m 2 -w "%{time_total}" "$M1" || echo 99)
    T2=$(curl -o /dev/null -s -m 2 -w "%{time_total}" "$M2" || echo 99)
    T3=$(curl -o /dev/null -s -m 2 -w "%{time_total}" "$M3" || echo 99)
    
    if (( $(echo "$T1 <= $T2 && $T1 <= $T3" | bc -l) )); then
        echo "Server = $M1" > /etc/pacman.d/mirrorlist
        echo -e "已切换至 清华大学源 (延迟: ${T1}s)"
    elif (( $(echo "$T2 <= $T1 && $T2 <= $T3" | bc -l) )); then
        echo "Server = $M2" > /etc/pacman.d/mirrorlist
        echo -e "已切换至 中科大源 (延迟: ${T2}s)"
    else
        echo "Server = $M3" > /etc/pacman.d/mirrorlist
        echo -e "已切换至 阿里云源 (延迟: ${T3}s)"
    fi
    
    echo -e "\n\033[38;2;180;150;200m----------------------------------------------------"
    echo -e " 💡 提示：如果没网，请按 Ctrl+C 退出，输入 nmtui 联网"
    echo -e " 💡 提示：想预览紫罗兰桌面？按 Ctrl+C 退出，输入 start-desktop"
    echo -e "----------------------------------------------------\033[0m\n"
    
    sleep 1
    clear
    archinstall
    
    echo -e "\n\033[38;2;226;208;232m"
    echo "----------------------------------------------------"
    echo " 天枢OS 安装引导已结束。输入 'archinstall' 重新启动。"
    echo -e "----------------------------------------------------\033[0m"
fi
EOF

echo "==> [TianShu] 极限清理残留"
rm -rf /var/cache/pacman/pkg/* 2>/dev/null || true
rm -rf /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* /tmp/* 2>/dev/null || true
