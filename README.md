# Arch Linux Automated Installation Script

## Description
This is a shell script designed to automate the installation of Arch Linux, complete with network setup, bootloader configuration (GRUB), and EFI partition mounting. The script ensures that the system is ready for development by including essential packages like `git`, `base-devel`, and networking tools such as `iwd` and `dhcpcd`.

## Features
- Automatic partition formatting and mounting (EFI, root, and swap).
- Installs essential base packages (`base`, `linux`, `linux-firmware`).
- Includes networking tools like `iwd` for wireless management and `dhcpcd` for DHCP.
- Configures DNS for internet access immediately after installation.
- Detects and configures Windows dual-boot with GRUB using `os-prober`.
- Installs development tools (`git` and `base-devel`).
- Automatic timezone, locale, and hostname configuration.
- Automated GRUB installation and configuration.

## Prerequisites
- UEFI-enabled system (for EFI partition usage).
- An existing Arch Linux live environment (booted from USB or other media).
- Partition structure ready (EFI, root, and swap partitions).

## How to Use

1. **Boot into the Arch Linux live environment** from your USB or other bootable media.

2. **Set up your partitions**: Ensure you have an EFI partition (usually around 100 MB), a root partition, and a swap partition.

3. **Clone this repository**:
   ```bash
   git clone https://github.com/binxmadisonjr/arch-linux-auto-install.git
   cd arch-linux-auto-install
4. **Edit the script if necessary**: Update the partition variables in `arch_install.sh` if they differ from the defaults in the script.

5. **Make the script executable**:
   ```bash
   chmod +x arch_install.sh
6. **Run the script**:
   ```bash
   ./arch_install.sh
7. **Follow the prompts**: The script will handle partition formatting, system installation, and GRUB configuration.

8. **Reboot** after the script completes.

## Included Packages
- `base`: The Arch base system.
- `linux`: The latest Arch Linux kernel.
- `linux-firmware`: Firmware needed by the kernel.
- `nano`: A lightweight terminal text editor.
- `iwd`: Wireless management tool for Wi-Fi setup.
- `dhcpcd`: DHCP client for automatic IP assignment.
- `netctl`: Networking profiles for systemd.
- `git`: Version control for managing repositories.
- `base-devel`: Essential development tools for compiling software.

## Troubleshooting

- **GRUB doesn't detect Windows**: Ensure your EFI partition is mounted correctly, and `os-prober` is enabled. If GRUB still doesn't detect Windows, check your partition setup and rerun `grub-mkconfig`.

- **No internet connection**: Verify that `iwd` and `dhcpcd` are enabled and running. Make sure DNS is configured correctly in `/etc/resolv.conf`.

## Contribution

Feel free to contribute to this project by opening issues or submitting pull requests!
