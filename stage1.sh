#!/bin/bash

error_exit() {
    echo "$1"
    exit 1
}

pacman -Sy --noconfirm dialog || error_exit "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n"

clear
lsblk
read -rp "After deciding which drive to install the system on, press any key to continue"

dialog --no-cancel --inputbox "Enter the drive you want do install Arch Linux for the VIDEOPC on." 10 60 2>drive

dialog --no-cancel --inputbox "Enter the RTMP key (only alphanumeric values allowed):" 10 60 2> videopc_rtmp_key
dialog --no-cancel --inputbox "Enter the API key (only alphanumeric values allowed):" 10 60 2> videopc_api_key

test -d /sys/firmware/efi/efivars || error_exit "Error: Please boot in UEFI mode. No efi vars detected."

DRIVE=$(cat drive)

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

mkfs.fat -F32 /dev/"$DRIVE"1

while true; do
    cryptsetup luksFormat -q /dev/"$DRIVE"2 && break
done

while true; do
    cryptsetup open /dev/"$DRIVE"2 cryptroot && break
done

yes | mkfs.ext4 /dev/mapper/cryptroot
mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/efi
mount /dev/"$DRIVE"1 /mnt/efi

pacman -Sy --noconfirm archlinux-keyring

pacstrap /mnt base linux linux-firmware networkmanager sbctl amd-ucode efibootmgr tpm2-tss

genfstab -U /mnt >> /mnt/etc/fstab
mv drive /mnt
mv videopc_api_key videopc_rtmp_key /mnt/etc
echo "videopc" > /mnt/etc/hostname

curl -LO https://raw.githubusercontent.com/noahvogt/videopc-infra/master/chroot.sh --output-dir /mnt
curl -LO https://raw.githubusercontent.com/noahvogt/videopc-infra/master/stage2.sh --output-dir /mnt || error_exit "Error: Failed to install stage2 script."
arch-chroot /mnt bash chroot.sh || error_exit "Error: Installation failed."
rm /mnt/chroot.sh

systemctl reboot --firmware
