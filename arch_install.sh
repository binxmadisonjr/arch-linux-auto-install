# Clear the screen to start with a clean slate
clear

# Variables (you can update these based on your setup)
BOOT_PARTITION="/dev/nvme0n1p5"
ROOT_PARTITION="/dev/nvme0n1p6"
SWAP_PARTITION="/dev/nvme0n1p7"
LOGFILE="/var/log/arch_install.log"
LOCALE="en_US.UTF-8"

# Prompt for necessary information
echo "Please enter the hostname:"
read HOSTNAME
clear

echo "Please enter the time zone (e.g., America/Chicago):"
read TIMEZONE
clear

echo "Please enter the root password:"
read -s ROOT_PASSWORD
clear

echo "Please enter the user name:"
read USER_NAME
clear

echo "Please enter the password for user [$USER_NAME]:"
read -s USER_PASSWORD
clear

# Helper function for error handling
handle_error() {
    echo "Error occurred at line $1. Check the log file for details: $LOGFILE"
    exit 1
}

# Set trap to catch errors and log them
trap 'handle_error $LINENO' ERR

# Clear or create the log file
echo "Starting Arch Linux installation..." > $LOGFILE

# Update system clock
echo "Updating system clock..." | tee -a $LOGFILE
timedatectl set-ntp true > /dev/null 2>> $LOGFILE || echo "Failed to update system clock" | tee -a $LOGFILE

# Partition formatting
echo "Formatting partitions..." | tee -a $LOGFILE
mkfs.fat -F32 $BOOT_PARTITION > /dev/null 2>> $LOGFILE || echo "Failed to format boot partition $BOOT_PARTITION" | tee -a $LOGFILE
mkfs.ext4 -F $ROOT_PARTITION > /dev/null 2>> $LOGFILE || echo "Failed to format root partition $ROOT_PARTITION" | tee -a $LOGFILE
mkswap $SWAP_PARTITION > /dev/null 2>> $LOGFILE || echo "Failed to create swap on $SWAP_PARTITION" | tee -a $LOGFILE

# Mount partitions
echo "Mounting partitions..." | tee -a $LOGFILE
mount $ROOT_PARTITION /mnt > /dev/null 2>> $LOGFILE || echo "Failed to mount root partition $ROOT_PARTITION" | tee -a $LOGFILE
mkdir -p /mnt/boot/efi > /dev/null 2>> $LOGFILE || echo "Failed to create /mnt/boot/efi" | tee -a $LOGFILE
mount $BOOT_PARTITION /mnt/boot/efi > /dev/null 2>> $LOGFILE || echo "Failed to mount boot partition $BOOT_PARTITION" | tee -a $LOGFILE
swapon $SWAP_PARTITION > /dev/null 2>> $LOGFILE || echo "Failed to enable swap on $SWAP_PARTITION" | tee -a $LOGFILE

# Install base system with status updates
echo "Installing base system..." | tee -a $LOGFILE
pacstrap /mnt base linux linux-firmware nano networkmanager dhcpcd base-devel gcc make bison flex perl grub efibootmgr > /dev/null 2>> $LOGFILE || echo "Base system installation failed" | tee -a $LOGFILE
echo "Step 1/4 complete."

# Install KDE Plasma and SDDM (display manager) with all default applications
echo "Installing KDE Plasma and SDDM..." | tee -a $LOGFILE
arch-chroot /mnt pacman -S plasma kde-applications sddm --noconfirm > /dev/null 2>> $LOGFILE
echo "Enabling SDDM..." | tee -a $LOGFILE
arch-chroot /mnt systemctl enable sddm > /dev/null 2>> $LOGFILE || echo "Failed to enable SDDM" | tee -a $LOGFILE

# Generate fstab
echo "Step 2/4: Generating fstab..." | tee -a $LOGFILE
genfstab -U /mnt >> /mnt/etc/fstab 2>> $LOGFILE || echo "Failed to generate fstab" | tee -a $LOGFILE
echo "Step 2/4 complete."

# Chroot into the new system
echo "Step 3/4: Chrooting and configuring the system..." | tee -a $LOGFILE
arch-chroot /mnt <<EOF

# Set time zone
echo "Setting time zone..." | tee -a $LOGFILE
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime > /dev/null 2>> $LOGFILE || echo "Failed to set time zone" | tee -a $LOGFILE
hwclock --systohc > /dev/null 2>> $LOGFILE || echo "Failed to set hardware clock" | tee -a $LOGFILE

# Set locale
echo "Setting locale..." | tee -a $LOGFILE
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen > /dev/null 2>> $LOGFILE || echo "Failed to generate locale" | tee -a $LOGFILE
echo "LANG=$LOCALE" > /etc/locale.conf

# Set hostname
echo "Setting hostname..." | tee -a $LOGFILE
echo "$HOSTNAME" > /etc/hostname

# Set keymap (optional)
echo "Setting keymap..." | tee -a $LOGFILE
echo "KEYMAP=us" > /etc/vconsole.conf

# Enable NetworkManager for wireless and network management
echo "Enabling NetworkManager..." | tee -a $LOGFILE
systemctl enable NetworkManager > /dev/null 2>> $LOGFILE || echo "Failed to enable NetworkManager" | tee -a $LOGFILE
systemctl start NetworkManager > /dev/null 2>> $LOGFILE || echo "Failed to start NetworkManager" | tee -a $LOGFILE

# Set root password
echo "Setting root password..." | tee -a $LOGFILE
echo "root:$ROOT_PASSWORD" | chpasswd > /dev/null 2>> $LOGFILE || echo "Failed to set root password" | tee -a $LOGFILE

# Create initial user with sudo access
echo "Creating initial user with sudo access..." | tee -a $LOGFILE
useradd -m -G wheel -s /bin/bash "$USER_NAME" > /dev/null 2>> $LOGFILE || echo "Failed to create user $USER_NAME" | tee -a $LOGFILE
echo "$USER_NAME:$USER_PASSWORD" | chpasswd > /dev/null 2>> $LOGFILE || echo "Failed to set password for user $USER_NAME" | tee -a $LOGFILE

# Give the user full sudo access by modifying the sudoers file
echo "Granting sudo access to $USER_NAME..." | tee -a $LOGFILE
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers > /dev/null 2>> $LOGFILE || echo "Failed to update sudoers file" | tee -a $LOGFILE

# Install and configure bootloader (GRUB)
echo "Installing GRUB..." | tee -a $LOGFILE
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB > /dev/null 2>> $LOGFILE || echo "Failed to install GRUB" | tee -a $LOGFILE

# Generate GRUB config
echo "Generating GRUB configuration..." | tee -a $LOGFILE
grub-mkconfig -o /boot/grub/grub.cfg > /dev/null 2>> $LOGFILE || echo "Failed to generate GRUB config" | tee -a $LOGFILE

EOF
echo "Step 3/4 complete."

# Unmount partitions and shutdown with a 10-second delay
echo "Step 4/4: Unmounting partitions and shutting down..." | tee -a $LOGFILE
umount -R /mnt > /dev/null 2>> $LOGFILE || echo "Failed to unmount partitions" | tee -a $LOGFILE
echo "System will shutdown in 10 seconds..." | tee -a $LOGFILE
sleep 10
shutdown now