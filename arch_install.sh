#!/bin/bash

# Clear the screen to start fresh
clear

# Variables (you can update these based on your setup)
BOOT_PARTITION="/dev/nvme0n1p1"
ROOT_PARTITION="/dev/nvme0n1p2"
SWAP_PARTITION="/dev/nvme0n1p3"
DISK="/dev/nvme0n1"
LOGFILE="/var/log/arch_install.log"
LOCALE="en_US.UTF-8"
TIMEZONE="America/Chicago"

# Prompt for hostname
echo "Please enter the hostname:"
read HOSTNAME

# Root password confirmation
while true; do
    echo "Please enter the root password:"
    read -s ROOT_PASSWORD
    echo "Please confirm the root password:"
    read -s ROOT_PASSWORD_CONFIRM
    if [ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "Passwords do not match, please try again."
    fi
done

# User creation and password confirmation
echo "Please enter the user name:"
read USER_NAME

while true; do
    echo "Please enter the password for user [$USER_NAME]:"
    read -s USER_PASSWORD
    echo "Please confirm the password for user [$USER_NAME]:"
    read -s USER_PASSWORD_CONFIRM
    if [ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]; then
        break
    else
        echo "Passwords do not match, please try again."
    fi
done

# Set up error handling and logging
handle_error() {
    echo "Error occurred at line $1. Check the log file for details: $LOGFILE"
    exit 1
}
trap 'handle_error $LINENO' ERR
echo "Starting Arch Linux installation..." > $LOGFILE

# Unmount partitions if mounted
echo "Unmounting any mounted partitions..." | tee -a $LOGFILE
umount -R /mnt 2> /dev/null || true
swapoff -a 2> /dev/null || true

# Update system clock
echo "Updating system clock..." | tee -a $LOGFILE
timedatectl set-ntp true >> $LOGFILE 2>&1

# Wipe disk and create new partitions
echo "Wiping and partitioning disk $DISK..." | tee -a $LOGFILE
sgdisk -Z $DISK >> $LOGFILE 2>&1
sgdisk -o $DISK >> $LOGFILE 2>&1
sgdisk -n 1:0:+512M -t 1:ef00 $DISK >> $LOGFILE 2>&1 # EFI partition
sgdisk -n 2:0:0 -t 2:8300 $DISK >> $LOGFILE 2>&1 # Root partition
sgdisk -n 3:0:+4G -t 3:8200 $DISK >> $LOGFILE 2>&1 # Swap partition

# Format partitions
echo "Formatting partitions..." | tee -a $LOGFILE
mkfs.fat -F32 $BOOT_PARTITION >> $LOGFILE 2>&1
mkfs.ext4 -F $ROOT_PARTITION >> $LOGFILE 2>&1
mkswap $SWAP_PARTITION >> $LOGFILE 2>&1

# Mount partitions
echo "Mounting partitions..." | tee -a $LOGFILE
mount $ROOT_PARTITION /mnt >> $LOGFILE 2>&1
mkdir -p /mnt/boot/efi >> $LOGFILE 2>&1
mount $BOOT_PARTITION /mnt/boot/efi >> $LOGFILE 2>&1
swapon $SWAP_PARTITION >> $LOGFILE 2>&1

# Rank and select the fastest mirrors
echo "Ranking and selecting the fastest mirrors..." | tee -a $LOGFILE
reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist >> $LOGFILE 2>&1

# Install base system with both Linux and LTS kernel, KDE Plasma, and SDDM
echo "Installing base system, Linux and LTS kernel, KDE Plasma, and SDDM..." | tee -a $LOGFILE
pacstrap /mnt base linux linux-lts linux-firmware nano networkmanager grub efibootmgr plasma kde-applications sddm --noconfirm >> $LOGFILE 2>&1

# Generate fstab
echo "Generating fstab..." | tee -a $LOGFILE
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
echo "Configuring the system inside chroot..." | tee -a $LOGFILE
arch-chroot /mnt <<EOF

# Set time zone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime >> $LOGFILE 2>&1
hwclock --systohc >> $LOGFILE 2>&1

# Set locale
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen >> $LOGFILE 2>&1
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Enable NetworkManager
systemctl enable NetworkManager >> $LOGFILE 2>&1

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd >> $LOGFILE 2>&1

# Create a new user and set password
useradd -m -G wheel -s /bin/bash "$USER_NAME" >> $LOGFILE 2>&1
echo "$USER_NAME:$USER_PASSWORD" | chpasswd >> $LOGFILE 2>&1

# Grant sudo privileges to the user
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers >> $LOGFILE 2>&1

# Install GRUB bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB >> $LOGFILE 2>&1
grub-mkconfig -o /boot/grub/grub.cfg >> $LOGFILE 2>&1

# Enable SDDM
systemctl enable sddm >> $LOGFILE 2>&1
EOF

# Unmount partitions and shutdown with a 10-second delay
echo "Unmounting partitions and finishing installation..." | tee -a $LOGFILE
umount -R /mnt >> $LOGFILE 2>&1
swapoff $SWAP_PARTITION >> $LOGFILE 2>&1
echo "System will shut down in 10 seconds..." | tee -a $LOGFILE
sleep 10
shutdown now