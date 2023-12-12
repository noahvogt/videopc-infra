#!/bin/bash

while true; do
    passwd && break
done

DRIVE=$(cat drive)
PVALUE=$(echo "${DRIVE}" | grep "^nvme" | sed 's/.*[0-9]/p/')

ln -sf /usr/share/zoneinfo/"$(cat tzfinal.tmp)" /etc/localtime

hwclock --systohc

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

systemctl enable NetworkManager

sed -i 's/^\s*GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/^\s*GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=0 quiet udev.log_level=3"/' /etc/default/grub

mkdir /boot/efi
mount /dev/"${DRIVE}${PVALUE}"1 /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub /dev/"${DRIVE}" --recheck

grub-mkconfig -o /boot/grub/grub.cfg

rm drive tzfinal.tmp
