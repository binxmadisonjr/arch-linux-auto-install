#!/bin/bash

# Arch Linux Installation Script

# Colors
DIALOGRC="/etc/dialorc"
echo "use_shadow = OFF
title_color = (BLACK,WHITE,OFF)
button_label_active_color = (WHITE,BLACK,ON)
button_label_inactive_color = (BLACK,WHITE,OFF)
tag_color = (BLACK,WHITE,OFF)
tag_selected_color = (WHITE,BLACK,ON)
tag_key_color = (BLACK,WHITE,OFF)
tag_key_selected_color = (WHITE,BLACK,ON)
check_color = tag_color
check_selected_color = tag_selected_color" > $DIALOGRC

# Ensure dialog is installed
if ! command -v dialog &> /dev/null
then
    echo "dialog could not be found, installing it."
    pacman -S --noconfirm dialog
fi

# Disk partitioning
partition_disk() {
    clear
    echo "Partitioning the disk..."
    parted /dev/sda -- mklabel gpt
    parted /dev/sda -- mkpart primary 512MiB 100%
    parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
    parted /dev/sda -- set 2 esp on
}

# Formatting partitions
format_partitions() {
    clear
    echo "Formatting the partitions..."
    mkfs.ext4 /dev/sda1
    mkfs.fat -F32 /dev/sda2
}

# Mounting partitions
mount_partitions() {
    clear
    echo "Mounting the partitions..."
    mount /dev/sda1 /mnt
    mkdir /mnt/boot
    mount /dev/sda2 /mnt/boot
}

# Base installation
install_base() {
    clear
    echo "Installing base system..."
    pacstrap /mnt base linux linux-firmware
}

# Generating fstab
generate_fstab() {
    clear
    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Setting up the system
configure_system() {
    clear
    echo "Configuring system..."

    arch-chroot /mnt /bin/bash -e <<EOF
    ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
    hwclock --systohc
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "KEYMAP=us" > /etc/vconsole.conf
    echo "archlinux" > /etc/hostname
    echo -e "127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\tarchlinux.localdomain\tarchlinux" > /etc/hosts
    passwd root
EOF
}

# Installing bootloader
install_bootloader() {
    clear
    echo "Installing GRUB..."
    arch-chroot /mnt pacman -S grub --noconfirm
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

# User creation
create_user() {
    clear
    echo "Creating user..."
    arch-chroot /mnt /bin/bash -e <<EOF
    useradd -m -G wheel -s /bin/bash kosta
    passwd kosta
    echo "kosta ALL=(ALL) ALL" >> /etc/sudoers
EOF
}

# Unmounting and finishing installation
finish_installation() {
    clear
    echo "Unmounting and finishing up..."
    umount -R /mnt
    reboot
}

# Installation flow
partition_disk
format_partitions
mount_partitions
install_base
generate_fstab
configure_system
install_bootloader
create_user
finish_installation