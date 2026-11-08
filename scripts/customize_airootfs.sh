#!/usr/bin/env bash
# TianShu OS — airootfs 定制脚本（在 archiso chroot 内以 root 执行）
set -u

echo "==> [TianShu] 清理运行环境（减小 squashfs 体积）"
rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* 2>/dev/null || true
rm -rf /var/cache/pacman/pkg/* /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* /tmp/* 2>/dev/null || true
rm -f /etc/pacman.d/mirrorlist.pacnew 2>/dev/null || true

echo "==> [TianShu] 中文本地化"
echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

echo "==> [TianShu] zram 交换（低内存 / 笔记本形态自适应）"
mkdir -p /etc/systemd
cat > /etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF

echo "==> [TianShu] TLP 电源策略（台式机 / 笔记本双形态）"
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

echo "==> [TianShu] 内核参数调优：swappiness / BBR / 大页"
cat > /etc/sysctl.d/99-tianshu.conf <<'EOF'
vm.swappiness=10
vm.nr_hugepages=128
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
sysctl --system >/dev/null 2>&1 || true

echo "==> [TianShu] 屏蔽无关服务"
for unit in cups cups-browsed avahi-daemon bluetooth baloo_file; do
    systemctl mask "${unit}.service" 2>/dev/null || true
done

echo "==> [TianShu] 镜像源测速"
if command -v reflector >/dev/null 2>&1; then
    timeout 120 reflector --latest 20 --sort rate --protocol https \
        --save /etc/pacman.d/mirrorlist 2>/dev/null \
        || echo "    reflector 超时或离线，保留原镜像列表"
fi

echo "==> [TianShu] 紫罗兰 KDE 配置注入 /etc/skel"
if [ -d /etc/tianshu/skel ]; then
    mkdir -p /etc/skel/.config
    cp -rf /etc/tianshu/skel/. /etc/skel/
    chown -R root:root /etc/skel
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

echo "==> [TianShu] 清理包缓存与构建残留（为 squashfs 腾出空间）"
rm -rf /var/cache/pacman/pkg/* 2>/dev/null || true
rm -rf /var/lib/pacman/sync/* 2>/dev/null || true
rm -rf /root/.cache/* /tmp/* 2>/dev/null || true
rm -f /etc/pacman.d/mirrorlist.pacnew 2>/dev/null || true

echo "==> [TianShu] 定制完成"
