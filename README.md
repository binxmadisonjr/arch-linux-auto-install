# Arch Linux Installation Script

This shell script (`arch_install.sh`) is a personalized Arch Linux installation script, tailored specifically for my setup. It formats and mounts partitions, installs the base system, configures GRUB for dual-booting, and sets up basic system settings like timezone, locale, and hostname.

## Personalized Setup:
- **Boot Partition**: `/dev/nvme0n1p5`
- **Root Partition**: `/dev/nvme0n1p6`
- **Swap Partition**: `/dev/nvme0n1p7`
- **Hostname**: `archlinux`
- **Time zone**: `America/Chicago`
- **Locale**: `en_US.UTF-8`

## How to Use:
1. Clone this repository or download the `arch_install.sh` file.
2. Adjust partition variables in the script if necessary to match your setup.
3. Run the script in an Arch Linux installation environment.

**Note**: This script is highly customized for my specific partition setup and might not work as-is for other systems. Be sure to adjust the partition variables and any other personalized settings before using it on your own machine.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
