#!/bin/bash

error_exit() {
    echo "$1"
    exit 1

}
while true; do
    passwd && break
done

DRIVE=$(cat drive)

ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime

hwclock --systohc

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

systemctl enable NetworkManager

# mount /dev/"$DRIVE"1 /efi
mkdir -p /efi/EFI/Linux
test -d /efi/EFI || error_exit "Error: EFI partition could not be mounted correctly."

# cat /proc/cmdline > /etc/kernel/cmdline
echo "BOOT_IMAGE=/boot/vmlinuz-linux root=/dev/sda2 rw loglevel=3 quiet" > /etc/kernel/cmdline
chmod +w /etc/kernel/cmdline

sb_status="$(sbctl status)"
echo "$sb_status" | grep "^Setup Mode:" | grep -q "Enabled" || error_exit "Error: Secure Boot not in Setup Mode. Please chane UEFI settings."
echo "$sb_status" | grep "^Secure Boot:" | grep -q "Disabled" || error_exit "Error: Secure Boot enabled. Please chane UEFI settings."
echo "$sb_status" | grep "^Vendor Keys:" | grep -q "none" || error_exit "Error: Vendor Keys present. Please change UEFI settings."

sbctl bundle -s \
    -a /boot/amd-ucode.img \
    -k /boot/vmlinuz-linux \
    -f /boot/initramfs-linux.img \
    -c /etc/kernel/cmdline \
    /efi/EFI/Linux/ArchBundle.efi

sbctl create-keys
sbctl generate-bundles --sign
sbctl enroll-keys -m

efibootmgr --create \
    --disk /dev/"$DRIVE" \
    --part 1 \
    --label "videopc signed efi bundle" \
    --loader /EFI/Linux/ArchBundle.efi

pacman -S linux

# sed -i 's/^\s*GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub
# sed -i 's/^\s*GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=0 quiet udev.log_level=3"/' /etc/default/grub

# grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=grub /dev/"${DRIVE}" --recheck
# grub-mkconfig -o /boot/grub/grub.cfg

rm drive
