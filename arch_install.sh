#!/bin/bash

# Clear the screen to start with a clean slate
clear

# Variables (you can update these based on your setup)
DISK="/dev/nvme0n1"
BOOT_PARTITION="${DISK}p1"
ROOT_PARTITION="${DISK}p2"
SWAP_PARTITION="${DISK}p3"
LOCALE="en_US.UTF-8"
TIMEZONE="America/Chicago"
HOSTNAME="archlinux"
USER_NAME="binxmadisonjr"

# Prompt for passwords
echo "Please enter the root password:"
read -s ROOT_PASSWORD
clear
echo "Please confirm the root password:"
read -s ROOT_PASSWORD_CONFIRM
clear

if [[ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]]; then
    echo "Passwords do not match. Exiting..."
    exit 1
fi

echo "Please enter the password for user [$USER_NAME]:"
read -s USER_PASSWORD
clear
echo "Please confirm the password for user [$USER_NAME]:"
read -s USER_PASSWORD_CONFIRM
clear

if [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]]; then
    echo "Passwords do not match. Exiting..."
    exit 1
fi

# Update system clock
timedatectl set-ntp true || { echo "Failed to update system clock"; exit 1; }

# Wiping and partitioning disk
echo "Wiping and partitioning disk $DISK..."
sgdisk -Z $DISK || { echo "Failed to wipe disk"; exit 1; }
sgdisk -o $DISK || { echo "Failed to create new GPT on disk"; exit 1; }

# Create partitions: 512MB EFI, rest for root, and 4GB for swap (optional)
echo "Creating partitions..."
sgdisk -n 1:0:+512M -t 1:ef00 $DISK || { echo "Failed to create boot partition"; exit 1; }
sgdisk -n 2:0:+50G -t 2:8300 $DISK || { echo "Failed to create root partition"; exit 1; }
sgdisk -n 3:0:+4G -t 3:8200 $DISK || { echo "Failed to create swap partition"; exit 1; }

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 $BOOT_PARTITION || { echo "Failed to format boot partition"; exit 1; }
mkfs.ext4 -F $ROOT_PARTITION || { echo "Failed to format root partition"; exit 1; }
mkswap $SWAP_PARTITION || { echo "Failed to create swap"; exit 1; }

# Mount partitions
echo "Mounting partitions..."
mount $ROOT_PARTITION /mnt || { echo "Failed to mount root partition"; exit 1; }
mkdir -p /mnt/boot/efi || { echo "Failed to create /mnt/boot/efi"; exit 1; }
mount $BOOT_PARTITION /mnt/boot/efi || { echo "Failed to mount boot partition"; exit 1; }
swapon $SWAP_PARTITION || { echo "Failed to enable swap"; exit 1; }

# Install base system with LTS kernel, KDE Plasma, and SDDM
echo "Installing base system, LTS kernel, KDE Plasma, and SDDM..."
pacstrap /mnt base linux linux-lts linux-firmware nano networkmanager grub efibootmgr plasma kde-applications sddm || { echo "Failed to install base system"; exit 1; }

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab || { echo "Failed to generate fstab"; exit 1; }

# Chroot into the new system
echo "Configuring the system..."
arch-chroot /mnt <<EOF
# Set time zone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime || { echo "Failed to set time zone"; exit 1; }
hwclock --systohc || { echo "Failed to set hardware clock"; exit 1; }

# Set locale
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen || { echo "Failed to generate locale"; exit 1; }
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Set keymap (optional)
echo "KEYMAP=us" > /etc/vconsole.conf

# Enable NetworkManager
systemctl enable NetworkManager || { echo "Failed to enable NetworkManager"; exit 1; }

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd || { echo "Failed to set root password"; exit 1; }

# Create user with sudo access
useradd -m -G wheel -s /bin/bash "$USER_NAME" || { echo "Failed to create user $USER_NAME"; exit 1; }
echo "$USER_NAME:$USER_PASSWORD" | chpasswd || { echo "Failed to set password for user $USER_NAME"; exit 1; }

# Grant sudo access to the user
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers || { echo "Failed to update sudoers"; exit 1; }

# Install and configure bootloader (GRUB)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB || { echo "Failed to install GRUB"; exit 1; }
grub-mkconfig -o /boot/grub/grub.cfg || { echo "Failed to generate GRUB config"; exit 1; }

# Enable SDDM
systemctl enable sddm || { echo "Failed to enable SDDM"; exit 1; }
EOF

# Unmount partitions and reboot
echo "Unmounting partitions and rebooting..."
umount -R /mnt || { echo "Failed to unmount partitions"; exit 1; }
reboot