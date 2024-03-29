#!/bin/bash

error_exit() {
    echo "$1"
    exit 1
}

mkdir /etc/systemd/system/getty@tty1.service.d
echo '[Service]
ExecStart=
ExecStart=-/sbin/agetty -o "-p -f -- \\u" --noclear --autologin root %I $TERM' > /etc/systemd/system/getty@tty1.service.d/autologin.conf

DRIVE=$(cat drive)

ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime

hwclock --systohc

echo "LANG=en_GB.UTF-8" >> /etc/locale.conf
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

systemctl enable NetworkManager

mkdir -p /efi/EFI/Linux
test -d /efi/EFI || error_exit "Error: EFI partition could not be mounted correctly."

sed -i 's/block filesystems/block encrypt filesystems/' /etc/mkinitcpio.conf

root_uuid="$(grep ext4 /etc/fstab | sed 's/^UUID=//; s/\s\/.*$//')"
drive2_uuid="$(blkid | grep "$DRIVE"2 | tr ' ' '\n' | grep ^UUID= | sed 's/^UUID="//; s/"//')"

echo "pti=on page_alloc.shuffle=1 BOOT_IMAGE=/boot/vmlinuz-linux root=UUID=$root_uuid rw cryptdevice=UUID=$drive2_uuid:cryptroot loglevel=7" > /etc/kernel/cmdline
chmod +w /etc/kernel/cmdline

sb_status="$(sbctl status)"
echo "$sb_status" | grep "^Setup Mode:" | grep -q "Enabled" || error_exit "Error: Secure Boot not in Setup Mode. Please change UEFI settings."
echo "$sb_status" | grep "^Secure Boot:" | grep -q "Disabled" || error_exit "Error: Secure Boot enabled. Please change UEFI settings."
echo "$sb_status" | grep "^Vendor Keys:" | grep -q "none" || error_exit "Error: Vendor Keys present. Please change UEFI settings."

sbctl bundle -s \
    -a /boot/amd-ucode.img \
    -k /boot/vmlinuz-linux \
    -f /boot/initramfs-linux.img \
    -c /etc/kernel/cmdline \
    /efi/EFI/Linux/ArchBundle.efi

sbctl create-keys
sbctl generate-bundles --sign
sbctl enroll-keys -m || error_exit "Error: Could not enroll secure boot keys to UEFI."

efibootmgr --create \
    --disk /dev/"$DRIVE" \
    --part 1 \
    --label "videopc signed efi bundle" \
    --loader /EFI/Linux/ArchBundle.efi || error_exit "Error: Could not create efi boot entry."

mkinitcpio -P

rm drive
