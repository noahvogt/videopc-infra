#!/bin/bash

# ASSUMED STATE OF TARGET SYSTEM:
# - internet access
# - root user login
# - ~10 GB of free disk space
# working 1.) base 2.) linux/kernel packages

error_exit() {
    echo -e "\e[0;30;101m $1\e[0m"
    exit 1
}

pacman_error_exit() {
    error_exit "Error: Pacman command was not successfull. Exiting ..."
}

cd_error_exit() {
    echo -e "\e[0;30;46m Current working directory: \e[0m"
    pwd
    error_exit "\e[0;30;101m Error: Could not change into '$1'. Exiting ...\e[0m"
}

cd_into() {
    cd "$1" || cd_error_exit "$1"
}

sb_status="$(sbctl status)"
echo "$sb_status" | grep "^Setup Mode:" | grep -q "Disabled" || error_exit "Error: Secure Boot in Setup Mode. Please change UEFI settings."
echo "$sb_status" | grep "^Secure Boot:" | grep -q "Enabled" || error_exit "Error: Secure Boot disabled. Please change UEFI settings."
# TODO: re-enable this after stopping the rollout of vendor keys
# echo "$sb_status" | grep "^Vendor Keys:" | grep -q "none" || error_exit "Error: Vendor Keys present. Please change UEFI settings."

grep -q "^2$" /sys/class/tpm/tpm*/tpm_version_major || error_exit "Error: No tpm2 devices found."

systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+7 /dev/sda2 || error_exit "Error: Failed to enroll luks2 key into tpm2"

sed -i 's/block encrypt/block sd-encrypt/' /etc/mkinitcpio.conf
sed -i 's/base udev/base systemd/' /etc/mkinitcpio.conf
sed -i 's/keyboard keymap consolefont/keyboard sd-vconsole/' /etc/mkinitcpio.conf

sda2_uuid="$(blkid | grep sda2 | tr ' ' '\n' | grep ^UUID= | sed 's/^UUID="//; s/"//')"
sed -i "s/cryptdevice=\/dev\/sda2:cryptroot/rd.luks.name=$sda2_uuid=cryptroot/" /etc/kernel/cmdline

mkinitcpio -P || error_exit "Error: Failed to update mkinitcpio"

# install git, vim, stow, opendoas and (base-devel minus sudo)
echo -e "\e[0;30;34mInstalling some initial packages ...\e[0m"
pacman -Sy --noconfirm --needed git vim opendoas autoconf automake binutils bison fakeroot file findutils flex gawk gcc gettext grep groff gzip libtool m4 make pacman patch pkgconf sed texinfo which libxft stow || error_exit "Error at script start:\n\nAre you sure you're running this as the root user?\n\t(Tip: run 'whoami' to check)\n\nAre you sure you have an internet connection?\n\t(Tip: run 'ip a' to check)\n\e[0m"


setup_temporary_doas() {
    echo -e "\e[0;30;34mSetting up temporary doas config ...\e[0m"
    printf "permit nopass :wheel
permit nopass root as %s\n" "$username" > /etc/doas.conf
    chown -c root:root /etc/doas.conf
    chmod -c 0400 /etc/doas.conf
}

create_videopc_user() {
    if ls /home/ | grep -q "^$username$"; then
        return
    fi

    echo -e "\e[0;30;34mCreating videopc user ...\e[0m"
    username="videopc"
    useradd -m -g users -G wheel "$username"
    while true; do
        passwd "$username" && break
    done
}

set_rtmp_key() {
    echo -e "\e[0;30;34mSetting rtmp key... \e[0m"
    while true; do
    echo -e "\e[0;30;42m Enter in your RTMP key \e[0m"
    read -rp " >>> " rtmp_key
        echo "$rtmp_key" > /etc/videopc_rtmp_key
        [ -n "$rtmp_key" ] && break
    done
}

set_api_key() {
    echo -e "\e[0;30;34mSetting api key... \e[0m"
    while true; do
    echo -e "\e[0;30;42m Enter in your API key \e[0m"
    read -rp " >>> " api_key
        echo "$api_key" > /etc/videopc_api_key
        [ -n "$api_key" ] && break
    done
}

add_user_to_groups() {
    if ! groups "$username" | grep "input" | grep -q "video"; then
        echo -e "\e[0;30;34mAdding $username to video and input groups ... \e[0m"
        usermod -aG video "$username"
        usermod -aG input "$username"
    fi
}


make_user_owner_of_HOME_and_mnt_dirs() {
    echo -e "\e[0;30;34mChanging ownership of /home/$username + /mnt ...\e[0m"
    chown -R "$username":users /home/"$username"/
    chown -R "$username":users /mnt/
}

create_videopc_user

# create ~/ directories
echo -e "\e[0;30;34mCreating ~/ directories ...\e[0m"
mkdir -vp /home/"$username"/dox /home/"$username"/pix /home/"$username"/dl
mkdir -vp /home/"$username"/vids /home/"$username"/mus
mkdir -vp /home/"$username"/.local/bin /home/"$username"/.config
mkdir -vp /home/"$username"/.local/share /home/"$username"/.local/src

echo -e "\e[0;30;34mChanging ownership of /home/$username ...\e[0m"
chown -R "$username":users /home/"$username"/* /home/"$username"/.*

setup_temporary_doas

add_user_to_groups

# add xdg-repo
if ! grep -q "^\s*\[xdg-repo\]\s*$" /etc/pacman.conf; then
    echo -e "\e[0;30;34mAdding Noah's xdg-repo ...\e[0m"
    pacman-key --recv-keys 7FA7BB604F2A4346 --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 7FA7BB604F2A4346
    echo "[xdg-repo]
Server = https://noahvogt.com/\$repo/\$arch" >> /etc/pacman.conf
fi

# add chaotic-aur
if ! grep -q "^\s*\[chaotic-aur\]\s*$" /etc/pacman.conf; then
    echo -e "\e[0;30;34mAdding the chaotic aur repo ...\e[0m"
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm --needed 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo "[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf
fi

# fetch + apply dotfiles
if [ ! -d /home/"$username"/.local/src/dotfiles ]; then
    echo -e "\e[0;30;34mFetching dotfiles ...\e[0m"
    cd_into /home/"$username"/.local/src
    while true; do
        git clone https://git.noahvogt.com/noah/videopc-infra.git && break
    done
else
    echo -e "\e[0;30;34mUpdating dotfiles ...\e[0m"
    cd_into /home/"$username"/.local/src/dotfiles
    while true; do
        git pull && break
    done
fi
mv /home/"$username"/.local/src/videopc-infra /home/"$username"/.local/src/dotfiles
cd_into /home/"$username"/.local/src/dotfiles
echo -e "\e[0;30;34mApplying dotfiles ...\e[0m"
doas -u "$username" /home/"$username"/.local/src/dotfiles/apply-dotfiles

set_rtmp_key
set_api_key

# download packages from the official repos
echo -e "\e[0;30;34mInstalling packages from repos ...\e[0m"
pacman -Sy --noconfirm --needed neovim ffmpeg pulseaudio-alsa mpv xf86-video-amdgpu xf86-video-intel xf86-video-nouveau coreutils curl hyprland kitty opendoas-sudo adwaita-fake-cursors greetd-agreety openssh uvicorn python-fastapi paru || pacman_error_exit

# install aur packages
echo -e "\e[0;30;34mInstalling packages from AUR ...\e[0m"
doas -u "$username" paru -S --noconfirm --needed mediamtx-bin || pacman_error_exit

# enable mediamtx service
echo -e "\e[0;30;34mEnabling mediamtx daemon ...\e[0m"
systemctl enable mediamtx

make_user_owner_of_HOME_and_mnt_dirs

# setup autologin
echo -e "\e[0;30;34mSetting up Autologin ...\e[0m"
systemctl enable greetd
if ! grep -q "\[initial_session\]" /etc/greetd/config.toml; then
    echo '[initial_session]
command = "Hyprland"
user = "videopc"' >> /etc/greetd/config.toml
fi

# enable sshd daemon
echo -e "\e[0;30;34mEnabling sshd daemon ...\e[0m"
systemctl enable sshd

# ~ cleanup
echo -e "\e[0;30;34mCleaning up \$HOME ...\e[0m"
for f in /home/"$username"/.bash*; do
    [ -f "$f" ] && rm "$f"
done
for f in /home/"$username"/.less*; do
    [ -f "$f" ] && rm "$f"
done
