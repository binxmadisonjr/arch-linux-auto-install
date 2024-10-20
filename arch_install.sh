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

# Start logging
exec > >(tee -i $LOGFILE) 2>&1

# Prompt for necessary information
dialog --inputbox "Please enter the hostname:" 8 50 2> /tmp/hostname
HOSTNAME=$(< /tmp/hostname)

# Confirm Root Password
while true; do
    dialog --passwordbox "Please enter the root password:" 8 50 2> /tmp/root_password
    ROOT_PASSWORD=$(< /tmp/root_password)

    dialog --passwordbox "Confirm the root password:" 8 50 2> /tmp/root_password_confirm
    ROOT_PASSWORD_CONFIRM=$(< /tmp/root_password_confirm)

    if [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]; then
        dialog --msgbox "Root passwords do not match! Please try again." 8 50
    else
        break
    fi
done

dialog --inputbox "Please enter the user name:" 8 50 2> /tmp/username
USER_NAME=$(< /tmp/username)

# Confirm User Password
while true; do
    dialog --passwordbox "Please enter the password for user [$USER_NAME]:" 8 50 2> /tmp/user_password
    USER_PASSWORD=$(< /tmp/user_password)

    dialog --passwordbox "Confirm the password for user [$USER_NAME]:" 8 50 2> /tmp/user_password_confirm
    USER_PASSWORD_CONFIRM=$(< /tmp/user_password_confirm)

    if [ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]; then
        dialog --msgbox "User passwords do not match! Please try again." 8 50
    else
        break
    fi
done

# Manually set mirrors for pacman
echo "Setting custom mirrors..."
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

# Wipe and create new partitions using parted
dialog --infobox "Wiping and partitioning disk ${DISK}..." 5 50
parted ${DISK} --script mklabel gpt # Ensure GPT partition table
parted ${DISK} --script mkpart primary fat32 1MiB 513MiB
parted ${DISK} --script set 1 esp on
parted ${DISK} --script mkpart primary ext4 513MiB 100%
parted ${DISK} --script mkpart primary linux-swap 100% 104GiB

# Format partitions
dialog --infobox "Formatting partitions..." 5 50
mkfs.fat -F32 ${DISK}p1
mkfs.ext4 ${DISK}p2
mkswap ${DISK}p3

# Mount partitions
dialog --infobox "Mounting partitions..." 5 50
mount ${DISK}p2 /mnt
mkdir -p /mnt/boot/efi
mount ${DISK}p1 /mnt/boot/efi
swapon ${DISK}p3

# Install base system with LTS kernel, KDE Plasma, and SDDM
dialog --gauge "Installing base system, LTS kernel, KDE Plasma, and SDDM..." 10 60 < <(
    pacstrap /mnt base linux linux-lts linux-firmware nano networkmanager grub efibootmgr plasma kde-applications sddm &> /dev/null &
    pid=$!
    while kill -0 $pid 2>/dev/null; do
        echo $((RANDOM % 100))
        sleep 1
    done
)

# Generate fstab
dialog --infobox "Generating fstab..." 5 50
genfstab -U /mnt >> /mnt/etc/fstab &> /dev/null

# Chroot into the new system
dialog --infobox "Chrooting and configuring the system..." 5 50
arch-chroot /mnt <<EOF

# Set time zone (hardcoded to America/Chicago)
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime &> /dev/null
hwclock --systohc &> /dev/null

# Set locale
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen &> /dev/null
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Enable NetworkManager for wireless and network management
systemctl enable NetworkManager &> /dev/null

# Enable SDDM for graphical login with KDE Plasma
systemctl enable sddm &> /dev/null

# Set root password
echo "root:$ROOT_PASSWORD" | chpasswd &> /dev/null

# Create initial user with sudo access
useradd -m -G wheel -s /bin/bash "$USER_NAME" &> /dev/null
echo "$USER_NAME:$USER_PASSWORD" | chpasswd &> /dev/null

# Give the user full sudo access by modifying the sudoers file
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers &> /dev/null

# Install and configure bootloader (GRUB)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB &> /dev/null
grub-mkconfig -o /boot/grub/grub.cfg &> /dev/null

EOF

# Unmount partitions and shutdown with a 10-second delay
dialog --infobox "Unmounting partitions and shutting down..." 5 50
umount -R /mnt &> /dev/null
sleep 10
shutdown now

# End the timer
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

# Display total time taken
dialog --msgbox "Installation completed in $(($elapsed_time / 60)) minutes and $(($elapsed_time % 60)) seconds!" 8 50

clear