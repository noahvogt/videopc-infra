#!/bin/bash

while true; do
    passwd && break
done

DRIVE=$(cat drive)

ln -sf /usr/share/zoneinfo/"$(cat tzfinal.tmp)" /etc/localtime

hwclock --systohc

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

systemctl enable NetworkManager

sed -i 's/^\s*GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/^\s*GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=0 quiet udev.log_level=3"/' /etc/default/grub

grub-install /dev/"$DRIVE"
grub-mkconfig -o /boot/grub/grub.cfg

rm drive tzfinal.tmp
