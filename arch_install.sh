#!/bin/bash

# Clear the screen
clear

# Variables
DISK="/dev/nvme0n1"
BOOT_PARTITION="${DISK}p1"
ROOT_PARTITION="${DISK}p2"
SWAP_PARTITION="${DISK}p3"
LOGFILE="/var/log/arch_install.log"
LOCALE="en_US.UTF-8"
TIMEZONE="America/Chicago"

# Prompt for necessary information
echo "Please enter the hostname:"
read HOSTNAME

echo "Please enter the root password:"
read -s ROOT_PASSWORD
echo "Please confirm the root password:"
read -s CONFIRM_ROOT_PASSWORD
if [ "$ROOT_PASSWORD" != "$CONFIRM_ROOT_PASSWORD" ]; then
    echo "Passwords do not match. Exiting."
    exit 1
fi

echo "Please enter the user name:"
read USER_NAME

echo "Please enter the password for user [$USER_NAME]:"
read -s USER_PASSWORD
echo "Please confirm the password for user [$USER_NAME]:"
read -s CONFIRM_USER_PASSWORD
if [ "$USER_PASSWORD" != "$CONFIRM_USER_PASSWORD" ]; then
    echo "Passwords do not match. Exiting."
    exit 1
fi

# Unmount any mounted partitions
echo "Unmounting any mounted partitions..." | tee -a $LOGFILE
umount -R /mnt || true

# Update system clock
echo "Updating system clock..." | tee -a $LOGFILE
timedatectl set-ntp true

# Wipe disk and create new partitions
echo "Wiping and partitioning disk $DISK..." | tee -a $LOGFILE
sgdisk -Z $DISK >> $LOGFILE 2>&1
sgdisk -o $DISK >> $LOGFILE 2>&1
sgdisk -n 1:0:+512M -t 1:ef00 $DISK >> $LOGFILE 2>&1 # EFI partition
sgdisk -n 2:0:+100G -t 2:8300 $DISK >> $LOGFILE 2>&1 # Root partition
sgdisk -n 3:0:+4G -t 3:8200 $DISK >> $LOGFILE 2>&1 # Swap partition

# Format partitions
echo "Formatting partitions..." | tee -a $LOGFILE
mkfs.fat -F32 $BOOT_PARTITION >> $LOGFILE 2>&1
mkfs.ext4 -F $ROOT_PARTITION >> $LOGFILE 2>&1
mkswap $SWAP_PARTITION >> $LOGFILE 2>&1

# Mount partitions
echo "Mounting partitions..." | tee -a $LOGFILE
mount $ROOT_PARTITION /mnt
mkdir -p /mnt/boot/efi
mount $BOOT_PARTITION /mnt/boot/efi
swapon $SWAP_PARTITION

# Install base system
echo "Installing base system, LTS kernel, KDE Plasma, and SDDM..." | tee -a $LOGFILE
pacstrap /mnt base linux linux-lts linux-firmware nano networkmanager grub efibootmgr plasma kde-applications sddm

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set time zone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set locale
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd

# Create initial user
useradd -m -G wheel -s /bin/bash $USER_NAME
echo "$USER_NAME:$USER_PASSWORD" | chpasswd

# Enable sudo for the user
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Enable NetworkManager
systemctl enable NetworkManager

# Install and configure bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Enable SDDM
systemctl enable sddm

EOF

# Unmount partitions and reboot
echo "Installation complete. Unmounting partitions and rebooting..." | tee -a $LOGFILE
umount -R /mnt
swapoff $SWAP_PARTITION
reboot