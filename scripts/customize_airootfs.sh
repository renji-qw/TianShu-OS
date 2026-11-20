#!/usr/bin/env bash
set -uo pipefail

rm -rf /usr/share/doc/* /var/cache/pacman/pkg/* && sed -i 's/^HOOKS=.*/HOOKS=(base udev modconf block lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf && mkinitcpio -P >/dev/null 2>&1

echo "zh_CN.UTF-8 UTF-8" > /etc/locale.gen && locale-gen >/dev/null 2>&1 && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo "NAME=\"TianShu OS\" ID=tianshu" > /etc/os-release

L=$(ls /usr/lib/libboost_python3*.so* 2>/dev/null | head -n 1) && [ -n "$L" ] && ln -sf "/usr/lib/$(basename "$L")" "/usr/lib/libboost_python314.so.1.91" || true

grep -q "\[offline_repo\]" /etc/pacman.conf || sed -i '1s/^/[offline_repo]\nSigLevel = Optional TrustAll\nServer = file:\/\/\/opt\/offline_repo\n\n/' /etc/pacman.conf

mkdir -p /etc/systemd/system/getty@tty1.service.d && printf "[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin root --noclear %%I \$TERM\n" > /etc/systemd/system/getty@tty1.service.d/autologin.conf

printf "if [ -z \"\$DISPLAY\" ] && [ \"\$(tty)\" = \"/dev/tty1\" ]; then\n  clear\n  printf '#!/bin/sh\nopenbox-session &\nsudo calamares\nxterm -hold -e \"echo \\\"安装器已退出。请重启电脑。\\\"\"\n' > /root/.xinitrc\n  chmod +x /root/.xinitrc\n  startx\nfi\n" > /root/.bash_profile

install -Dm755 /work/core/target/x86_64-unknown-linux-musl/release/tianshu_core /usr/bin/tianshu_core && systemctl enable tianshu.service NetworkManager systemd-zram-setup@zram0.service >/dev/null 2>&1 || true

rm -rf /var/cache/pacman/pkg/* /tmp/*
