#!/bin/bash

# Variables (you can update these based on your setup)
BOOT_PARTITION="/dev/nvme0n1p5"
ROOT_PARTITION="/dev/nvme0n1p6"
SWAP_PARTITION="/dev/nvme0n1p7"
HOSTNAME="archlinux"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"

# Update system clock
timedatectl set-ntp true > /dev/null

# Partition formatting
echo "Formatting partitions..."
mkfs.fat -F32 $BOOT_PARTITION > /dev/null
mkfs.ext4 -F $ROOT_PARTITION > /dev/null # Force format the root partition
mkswap $SWAP_PARTITION > /dev/null

# Mount partitions
echo "Mounting partitions..."
mount $ROOT_PARTITION /mnt > /dev/null
mkdir /mnt/boot > /dev/null
mount $BOOT_PARTITION /mnt/boot > /dev/null
swapon $SWAP_PARTITION > /dev/null

# Install base system
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware nano iwd dhcpcd netctl > /dev/null

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab > /dev/null

# Chroot into the new system
arch-chroot /mnt > /dev/null <<EOF

# Set time zone
echo "Setting time zone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime > /dev/null
hwclock --systohc > /dev/null

# Set locale
echo "Setting locale..."
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen > /dev/null
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

# Enable iwd for wireless management
echo "Enabling iwd..."
systemctl enable iwd > /dev/null
systemctl start iwd > /dev/null

# Enable DHCP for network management
echo "Enabling DHCP..."
systemctl enable dhcpcd > /dev/null
systemctl start dhcpcd > /dev/null

# Install and configure bootloader (GRUB)
echo "Installing GRUB..."
pacman -S grub efibootmgr os-prober ntfs-3g --noconfirm > /dev/null
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB > /dev/null

# Enable OS Prober in GRUB
sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub > /dev/null

# Manually run os-prober
os-prober > /dev/null 

# Generate GRUB config
echo "Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg > /dev/null

# Set root password
echo "Setting root password..."
echo "root:root" | chpasswd

EOF

# Unmount partitions and reboot
echo "Finishing installation..."
umount -R /mnt > /dev/null
shutdown now > /dev/null
