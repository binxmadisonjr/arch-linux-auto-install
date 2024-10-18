#!/bin/bash

# Log file
LOGFILE="/var/log/arch_install.log"
exec > >(tee -a $LOGFILE) 2>&1

# Variables (update based on your setup)
BOOT_PARTITION="/dev/nvme0n1p5"
ROOT_PARTITION="/dev/nvme0n1p6"
SWAP_PARTITION="/dev/nvme0n1p7"
EFI_PARTITION="/dev/nvme0n1p1"
HOSTNAME="archlinux"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"

# Function to check and handle errors
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error encountered, exiting..."
        exit 1
    fi
}

# Update system clock
timedatectl set-ntp true
check_error

# Partition formatting
echo "Formatting partitions..."
mkfs.fat -F32 $BOOT_PARTITION
check_error
mkfs.ext4 -F $ROOT_PARTITION
check_error
mkswap $SWAP_PARTITION
check_error

# Mount partitions
echo "Mounting partitions..."
mount $ROOT_PARTITION /mnt
check_error
mkdir /mnt/boot /mnt/boot/efi
mount $BOOT_PARTITION /mnt/boot
check_error
swapon $SWAP_PARTITION
check_error
mount $EFI_PARTITION /mnt/boot/efi
check_error

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware nano iwd dhcpcd netctl
check_error

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
check_error

# Chroot into the new system
arch-chroot /mnt /bin/bash -c "
# Set time zone
echo 'Setting time zone...'
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set locale
echo 'Setting locale...'
echo '$LOCALE UTF-8' > /etc/locale.gen
locale-gen
echo 'LANG=$LOCALE' > /etc/locale.conf

# Set hostname
echo 'Setting hostname...'
echo '$HOSTNAME' > /etc/hostname

# Enable iwd for wireless management
echo 'Enabling iwd...'
systemctl enable iwd
systemctl start iwd

# Enable DHCP for network management
echo 'Enabling DHCP...'
systemctl enable dhcpcd
systemctl start dhcpcd

# Install and configure bootloader (GRUB)
echo 'Installing GRUB...'
pacman -S grub efibootmgr os-prober ntfs-3g --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

# Ensure os-prober is enabled in GRUB
sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

# Manually run os-prober to detect Windows
echo 'Running os-prober...'
os-prober
check_error

# Generate GRUB config
echo 'Generating GRUB configuration...'
grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
echo 'Setting root password...'
echo 'root:root' | chpasswd

# Enable systemd-resolved to manage resolv.conf (before adding custom DNS)
echo 'Enabling systemd-resolved...'
rm /etc/resolv.conf
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl enable systemd-resolved
systemctl start systemd-resolved

# Configure DNS (Google DNS)
echo 'Configuring DNS...'
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf
"

# Unmount partitions and reboot
echo "Finishing installation..."
umount -R /mnt
shutdown now
