#!/bin/bash

# Set up custom dialog color scheme (black and yellow)
echo "use_shadow = OFF
title_color = (BLACK,YELLOW,OFF)
button_label_active_color = (BLACK,YELLOW,ON)
button_label_inactive_color = (BLACK,YELLOW,OFF)
tag_color = (BLACK,YELLOW,OFF)
tag_selected_color = (BLACK,YELLOW,ON)
tag_key_color = (BLACK,YELLOW,OFF)
tag_key_selected_color = (BLACK,YELLOW,ON)
check_color = tag_color
check_selected_color = tag_selected_color" > ~/.dialogrc

export DIALOGRC=~/.dialogrc

# Ensure dialog is installed
if ! command -v dialog &> /dev/null; then
  echo "dialog is not installed. Installing dialog..."
  pacman -Sy --noconfirm dialog || { echo "Failed to install dialog"; exit 1; }
fi

# Function to display messages with dialog
show_msg() {
  dialog --backtitle "Arch Linux Installation" --msgbox "$1" 0 0
}

# Set up basic UI with dialog
dialog --title "Arch Linux Installation" --msgbox "Welcome to the Arch Linux Installer" 10 60

# Prompt user for hostname
hostname=$(dialog --inputbox "Please enter the hostname for the system:" 10 60 "archlinux" 3>&1 1>&2 2>&3)

# Prompt for root password
root_password=$(dialog --passwordbox "Please enter the root password:" 10 60 3>&1 1>&2 2>&3)

# Prompt for new user creation
username=$(dialog --inputbox "Please enter a username for the new user profile:" 10 60 3>&1 1>&2 2>&3)

# Prompt for user password
user_password=$(dialog --passwordbox "Please enter the password for $username:" 10 60 3>&1 1>&2 2>&3)

# Confirm user selections
dialog --title "Confirm Selections" --yesno "Hostname: $hostname\nRoot Password: ********\nUsername: $username\nUser Password: ********\n\nProceed with installation?" 10 60
if [ $? -ne 0 ]; then
  dialog --msgbox "Installation canceled!" 10 60
  clear
  exit 1
fi

# Set up variables for partition sizes
efi_size=512M
swap_size=$(awk '/MemTotal/ {print int($2/1024)"M"}' /proc/meminfo)

# Select disk to partition (use first available disk)
disk=$(lsblk -nd -e 7,11 -o NAME | head -n 1)
disk="/dev/$disk"

# Create GPT partitions
show_msg "Creating partitions..."
parted --script $disk \
  mklabel gpt \
  mkpart primary fat32 1MiB $efi_size \
  set 1 esp on \
  mkpart primary linux-swap $efi_size $(awk -v efi=$efi_size -v swap=$swap_size 'BEGIN {print efi + swap}') \
  mkpart primary ext4 $(awk -v efi=$efi_size -v swap=$swap_size 'BEGIN {print efi + swap}') 100% || { show_msg "Failed to create partitions"; exit 1; }

# Format partitions
show_msg "Formatting partitions..."
mkfs.fat -F32 "${disk}1" || { show_msg "Failed to format EFI partition"; exit 1; }
mkswap "${disk}2" || { show_msg "Failed to format swap partition"; exit 1; }
mkfs.ext4 "${disk}3" || { show_msg "Failed to format root partition"; exit 1; }

# Mount partitions
show_msg "Mounting partitions..."
mount "${disk}3" /mnt || { show_msg "Failed to mount root partition"; exit 1; }
mkdir /mnt/boot
mount "${disk}1" /mnt/boot || { show_msg "Failed to mount EFI partition"; exit 1; }
swapon "${disk}2" || { show_msg "Failed to enable swap"; exit 1; }

# Ensure system is up to date
show_msg "Updating system..."
pacman -Syu --noconfirm || { show_msg "System update failed"; exit 1; }

# Install base system and kernels
show_msg "Installing base system..."
pacstrap /mnt base linux linux-lts linux-firmware || { show_msg "Failed to install base system"; exit 1; }

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab || { show_msg "Failed to generate fstab"; exit 1; }

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set up time and locale
ln -sf /usr/share/zoneinfo/$(curl -s ipinfo.io/timezone) /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname and hosts
echo "$hostname" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts

# Set root password
echo "root:$root_password" | chpasswd

# Create a new user profile
useradd -m -G wheel -s /bin/bash $username
echo "$username:$user_password" | chpasswd
echo "$username ALL=(ALL) ALL" >> /etc/sudoers

# Install KDE Plasma, SDDM, and necessary packages
pacman -S --noconfirm plasma kde-applications sddm sddm-kcm networkmanager || { echo "Failed to install KDE Plasma"; exit 1; }

# Enable services
systemctl enable sddm || { echo "Failed to enable SDDM"; exit 1; }
systemctl enable NetworkManager || { echo "Failed to enable NetworkManager"; exit 1; }

# Install bootloader (GRUB)
pacman -S --noconfirm grub efibootmgr || { echo "Failed to install GRUB"; exit 1; }
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB || { echo "Failed to install GRUB bootloader"; exit 1; }
grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to configure GRUB"; exit 1; }

EOF

# Unmount partitions and reboot
umount -R /mnt
swapoff -a
dialog --msgbox "Installation complete! The system will now reboot." 10 60
reboot