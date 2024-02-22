#!/bin/bash

error_exit() {
    echo "$1"
    exit 1
}

pacman -Sy --noconfirm dialog || error_exit "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"

clear
lsblk -d | sed 's/0 disk/0 disk\\n/;s/POINT/POINT\\n/'
read -rp "Press any key to continue"

dialog --no-cancel --inputbox "Enter the drive you want do install Arch Linux for the VIDEOPC on." 10 60 2>drive

test -d /sys/firmware/efi/efivars || error_exit "Error: Please boot in UEFI mode. No efi vars detected."

DRIVE=$(cat drive)
PVALUE=$(echo "${DRIVE}" | grep "^nvme" | sed 's/.*[0-9]/p/')

cat <<EOF | fdisk -W always /dev/"${DRIVE}"
g
n
p


+1024M
t
1
n
p



p
w
EOF
partprobe

mkfs.fat -F32 /dev/"${DRIVE}${PVALUE}"1
yes | mkfs.ext4 /dev/"${DRIVE}${PVALUE}"2
mount /dev/"${DRIVE}${PVALUE}"2 /mnt

pacman -Sy --noconfirm archlinux-keyring

pacstrap /mnt base linux networkmanager sbctl amd-ucode efibootmgr

genfstab -U /mnt >> /mnt/etc/fstab
mv drive /mnt
echo "videopc" > /mnt/etc/hostname

cp chroot.sh /mnt
arch-chroot /mnt bash chroot.sh
rm /mnt/chroot.sh

cp videopc-bootstrap.sh /mnt
arch-chroot /mnt bash videopc-bootstrap.sh
rm /mnt/videopc-bootstrap.sh
