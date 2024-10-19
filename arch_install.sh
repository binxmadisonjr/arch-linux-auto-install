#!/bin/bash

# Variables (you can update these based on your setup)
BOOT_PARTITION="/dev/nvme0n1p5"
ROOT_PARTITION="/dev/nvme0n1p6"
SWAP_PARTITION="/dev/nvme0n1p7"
USER_NAME="user"
LOGFILE="/var/log/arch_install.log"
WIRELESS_DEVICE="wlan0"  # Change based on your wireless interface name

# Prompt for necessary information
echo "Please enter the hostname:"
read HOSTNAME

echo "Please enter the time zone (e.g., America/Chicago):"
read TIMEZONE

echo "Please enter the root password:"
read -s ROOT_PASSWORD

echo "Please enter the password for user $USER_NAME:"
read -s USER_PASSWORD

# Helper function for error handling
handle_error() {
    echo "Error occurred at line $1. Check the log file for details: $LOGFILE"
    exit 1
}

# Set trap to catch errors and log them
trap 'handle_error $LINENO' ERR

# Clear or create the log file
echo "Starting Arch Linux installation..." > $LOGFILE

# Unmount all mounted partitions and deactivate swap
echo "Unmounting all partitions and deactivating swap if active..." | tee -a $LOGFILE
swapoff $SWAP_PARTITION > /dev/null 2>> $LOGFILE
umount -R /mnt > /dev/null 2>> $LOGFILE
umount $BOOT_PARTITION > /dev/null 2>> $LOGFILE

# Update system clock
echo "Updating system clock..." | tee -a $LOGFILE
timedatectl set-ntp true > /dev/null 2>> $LOGFILE

# Partition formatting
echo "Formatting partitions..." | tee -a $LOGFILE
mkfs.fat -F32 $BOOT_PARTITION > /dev/null 2>> $LOGFILE
mkfs.ext4 -F $ROOT_PARTITION > /dev/null 2>> $LOGFILE
mkswap $SWAP_PARTITION > /dev/null 2>> $LOGFILE

# Mount partitions
echo "Mounting partitions..." | tee -a $LOGFILE
mount $ROOT_PARTITION /mnt > /dev/null 2>> $LOGFILE
mkdir -p /mnt/boot/efi > /dev/null 2>> $LOGFILE  # Ensure EFI directory is created
mount $BOOT_PARTITION /mnt/boot/efi > /dev/null 2>> $LOGFILE
swapon $SWAP_PARTITION > /dev/null 2>> $LOGFILE

# Install base system
echo "Installing base system..." | tee -a $LOGFILE
pacstrap /mnt base linux linux-firmware nano networkmanager dhcpcd base-devel gcc make bison flex perl > /dev/null 2>> $LOGFILE  # Added development tools for LFS

# Generate fstab
echo "Generating fstab..." | tee -a $LOGFILE
genfstab -U /mnt >> /mnt/etc/fstab 2>> $LOGFILE

# Chroot into the new system
echo "Entering chroot environment..." | tee -a $LOGFILE
arch-chroot /mnt <<EOF

# Set time zone
echo "Setting time zone..." | tee -a $LOGFILE
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime > /dev/null 2>> $LOGFILE
hwclock --systohc > /dev/null 2>> $LOGFILE

# Set locale
echo "Setting locale..." | tee -a $LOGFILE
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen > /dev/null 2>> $LOGFILE
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
echo "Setting hostname..." | tee -a $LOGFILE
echo "$HOSTNAME" > /etc/hostname

# Set keymap (optional)
echo "Setting keymap..." | tee -a $LOGFILE
echo "KEYMAP=us" > /etc/vconsole.conf

# Enable NetworkManager for wireless and network management
echo "Enabling NetworkManager..." | tee -a $LOGFILE
systemctl enable NetworkManager > /dev/null 2>> $LOGFILE
systemctl start NetworkManager > /dev/null 2>> $LOGFILE

# Wireless setup if interface exists
if [ -n "$WIRELESS_DEVICE" ]; then
    echo "Configuring wireless network..." | tee -a $LOGFILE
    echo "Please enter your Wi-Fi SSID:"
    read WIFI_SSID
    echo "Please enter your Wi-Fi password:"
    read -s WIFI_PASSWORD
    nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD"
fi

# Set root password
echo "Setting root password..." | tee -a $LOGFILE
echo "root:$ROOT_PASSWORD" | chpasswd > /dev/null 2>> $LOGFILE

# Create initial user
echo "Creating initial user..." | tee -a $LOGFILE
useradd -m -G wheel -s /bin/bash "$USER_NAME" > /dev/null 2>> $LOGFILE
echo "$USER_NAME:$USER_PASSWORD" | chpasswd > /dev/null 2>> $LOGFILE

EOF

# Unmount partitions and reboot
echo "Finishing installation..." | tee -a $LOGFILE
umount -R /mnt > /dev/null 2>> $LOGFILE
shutdown now
