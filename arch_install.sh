#!/bin/bash

# Install dialog if it's not installed
if ! command -v dialog &> /dev/null
then
    sudo pacman -S --noconfirm dialog
fi

# Colors for styling
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Branding and welcome message
dialog --title "Welcome to Arch Linux Installer" --msgbox "\nWelcome to the Arch Linux Installer by binxmadisonjr!\n\nLet's get started with your Arch Linux setup!" 10 50

# Variables (you can update these based on your setup)
DISK="/dev/nvme0n1"          # Disk to install Arch Linux on
LOGFILE="/var/log/arch_install.log"
BOOT_PARTITION="${DISK}p1"    # EFI partition
ROOT_PARTITION="${DISK}p2"    # Root partition
SWAP_PARTITION="${DISK}p3"    # Swap partition (optional)
LOCALE="en_US.UTF-8"
TIMEZONE="America/Chicago"   # Hardcoded timezone

# Helper function for error handling
handle_error() {
    dialog --title "Error" --msgbox "Error occurred at line $1. Check the log file for details: $LOGFILE" 8 50
    exit 1
}

# Set trap to catch errors and log them
trap 'handle_error $LINENO' ERR

# Start logging with timestamps
exec > >(tee -a $LOGFILE) 2> >(tee -a $LOGFILE >&2)
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting installation" >> $LOGFILE

# Manually set mirrors for pacman
echo "$(date '+%Y-%m-%d %H:%M:%S') - Setting custom mirrors" >> $LOGFILE
cat <<EOF > /etc/pacman.d/mirrorlist
Server = https://mirrors.rutgers.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.liquidweb.com/archlinux/\$repo/os/\$arch
Server = https://ca.us.mirror.archlinux-br.org/\$repo/os/\$arch
Server = https://mirror.kaminski.io/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.square-r00t.net/\$repo/os/\$arch
Server = https://mirrors.radwebhosting.com/archlinux/\$repo/os/\$arch
Server = https://mirror.stjschools.org/arch/\$repo/os/\$arch
Server = https://archlinux.macame.com/\$repo/os/\$arch
EOF

# Wipe and create new partitions using parted (with adjusted partition sizes)
dialog --infobox "Wiping and partitioning disk ${DISK}..." 5 50
parted ${DISK} --script mklabel gpt   # Ensure GPT partition table

# Create 512 MB EFI partition
parted ${DISK} --script mkpart primary fat32 1MiB 513MiB
parted ${DISK} --script set 1 esp on

# Create Root Partition
parted ${DISK} --script mkpart primary ext4 513MiB 100%   # The rest of the space goes to root partition

# Format partitions
dialog --infobox "Formatting partitions..." 5 50
mkfs.fat -F32 ${DISK}p1
mkfs.ext4 ${DISK}p2

# Mount partitions
dialog --infobox "Mounting partitions..." 5 50
mount ${DISK}p2 /mnt
mkdir -p /mnt/boot/efi
mount ${DISK}p1 /mnt/boot/efi

# Install base system with LTS kernel, KDE Plasma, and SDDM
dialog --gauge "Installing base system, LTS kernel, KDE Plasma, and SDDM..." 10 60 <(
    pacstrap /mnt base linux linux-lts linux-firmware nano networkmanager grub efibootmgr plasma kde-applications sddm > /dev/null 2>> $LOGFILE
)

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab 2>> $LOGFILE || echo "Failed to generate fstab" | tee -a $LOGFILE

# Chroot into the new system to configure
arch-chroot /mnt <<EOF
    echo "Setting up in chroot environment..."

    # Set timezone
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    hwclock --systohc

    # Set locale
    echo "$LOCALE UTF-8" > /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE" > /etc/locale.conf

    # Set hostname
    echo "binxmadisonjr" > /etc/hostname

    # Enable NetworkManager
    systemctl enable NetworkManager

    # Enable SDDM (KDE display manager)
    systemctl enable sddm

    # Set root password
    echo "root:password" | chpasswd

    # Create user and give sudo access
    useradd -m -G wheel -s /bin/bash binxmadisonjr
    echo "binxmadisonjr:password" | chpasswd
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

    # Install and configure bootloader (GRUB)
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Unmount and reboot
dialog --infobox "Arch Linux installation complete! Unmounting partitions..." 5 50
umount -R /mnt
dialog --infobox "Rebooting in 10 seconds..." 5 50
sleep 10
reboot