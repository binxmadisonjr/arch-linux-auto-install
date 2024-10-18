#!/bin/bash

# Variables (you can update these based on your setup)
BOOT_PARTITION="/dev/nvme0n1p5"
ROOT_PARTITION="/dev/nvme0n1p6"
SWAP_PARTITION="/dev/nvme0n1p7"
EFI_PARTITION="/dev/nvme0n1p1"  # Update this as needed
HOSTNAME="archlinux"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"

# Update system clock
timedatectl set-ntp true

# Partition formatting
echo "Formatting partitions..."
mkfs.fat -F32 $BOOT_PARTITION
mkfs.ext4 -F $ROOT_PARTITION
mkswap $SWAP_PARTITION

# Mount partitions
echo "Mounting partitions..."
mount $ROOT_PARTITION /mnt
mkdir -p /mnt/boot/efi   # Ensure the /boot/efi directory exists
mount $BOOT_PARTITION /mnt/boot/efi
swapon $SWAP_PARTITION

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware nano iwd dhcpcd netctl

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt <<EOF

# Set time zone
echo "Setting time zone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set locale
echo "Setting locale..."
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

# Enable iwd for wireless management
echo "Enabling iwd..."
systemctl enable iwd
systemctl start iwd

# Enable DHCP for network management
echo "Enabling DHCP..."
systemctl enable dhcpcd
systemctl start dhcpcd

# Install and configure bootloader (GRUB)
echo "Installing GRUB..."
pacman -S grub efibootmgr os-prober ntfs-3g --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

# Enable OS Prober in GRUB
sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

# Manually run os-prober
os-prober

# Generate GRUB config
echo "Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg

# Set root password
echo "Setting root password..."
echo "root:root" | chpasswd

EOF

# Unmount partitions and reboot
echo "Finishing installation..."
umount -R /mnt
shutdown now