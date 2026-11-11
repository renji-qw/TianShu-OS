#!/usr/bin/env bash
# TianShu OS — airootfs 定制脚本
set -uo pipefail

# 1. 系统级清理与内核修复 (合并为一行)
rm -rf /usr/share/doc/* /usr/share/man/* /var/cache/pacman/pkg/* /tmp/* && rm -f /boot/initramfs-linux-fallback.img
sed -i 's/^HOOKS=.*/HOOKS=(base udev modconf block lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf && mkinitcpio -P

# 2. 基础配置写入
echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
echo "NAME=\"TianShu OS\" PRETTY_NAME=\"TianShu OS (Lilac) 1.0.1-beta\" ID=tianshu" > /etc/os-release
printf 'vm.swappiness=10\nvm.vfs_cache_pressure=50\n' > /etc/sysctl.d/99-tianshu.conf
printf '[zram0]\nzram-size = min(ram / 2, 4096)\n' > /etc/systemd/zram-generator.conf
systemctl enable sddm tianshu.service NetworkManager && systemctl set-default graphical.target

# 3. 配置 Live 自动登录
echo -e "[Autologin]\nUser=liveuser\nSession=plasma" > /etc/sddm.conf.d/autologin.conf
[ -d /etc/tianshu/skel ] && cp -rf /etc/tianshu/skel/* /etc/skel/ && chown -R root:root /etc/skel

# 4. 🌟 注入 Calamares 安装器，自动下载生态包
NETINSTALL_CONF="/etc/calamares/modules/netinstall.yaml"
if [ -f "$NETINSTALL_CONF" ]; then
    cat > "$NETINSTALL_CONF" <<EOF
- name: "TianShu Ecosystem"
  description: "天枢OS 自动生态 (输入法/蓝牙/打印/商店)"
  selected: true
  packages:
    - fcitx5
    - fcitx5-chinese-addons
    - bluez
    - bluez-utils
    - cups
    - cups-pdf
    - pamac-aur
    - archlinuxcn-keyring
EOF
fi

# 5. 在桌面放置安装图标 (一键拉起图形安装器)
mkdir -p /home/liveuser/Desktop
printf '[Desktop Entry]\nType=Application\nName=安装 TianShu OS\nExec=sudo -E dbus-launch calamares -D6\nIcon=system-software-install\nTerminal=false\n' > /home/liveuser/Desktop/install.desktop
chmod +x /home/liveuser/Desktop/install.desktop && chown -R liveuser:liveuser /home/liveuser/Desktop

# 6. 终端彩蛋引导 (TTY 打字机)
cat > /root/.bash_profile <<EOF
if [ "\$(tty)" = "/dev/tty1" ]; then
    clear
    echo -e "\033[38;2;226;208;232m"
    echo "[ 正在唤醒天枢OS 涌现式动力学引擎... ]"
    echo -e "\033[0m 提示: 按 Ctrl+Alt+F2 返回紫罗兰图形桌面安装。"
fi
EOF

# 7. 终极清理
rm -rf /var/cache/pacman/pkg/* /tmp/* 2>/dev/null || true
