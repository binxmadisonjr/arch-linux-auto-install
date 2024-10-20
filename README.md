Arch Linux Installer - by binxmadisonjr
=======================================

Welcome to the custom-built Arch Linux Installer! This installer is designed to streamline the process of setting up Arch Linux with the **KDE Plasma desktop environment** and the **LTS kernel** for stability. This script simulates a GUI-style interface using `dialog` and guides you through setting up your hostname, user credentials, and more.

Installation Steps
------------------

1.  Download or clone the script to your local machine.
2.  Ensure the script is executable by running the following command in your terminal:
    
        chmod +x arch_installer.sh
    
3.  Run the script as `root` or using `sudo`:
    
        sudo ./arch_installer.sh
    
4.  Follow the on-screen prompts to configure your system:
    *   **Hostname:** Enter the desired hostname for your system.
    *   **Root Password:** You'll be asked to enter and confirm the root password.
    *   **User Account:** Specify a username and password for your user account. You will also confirm the user password.
5.  Wait for the installation process to complete. The installer will set up partitions, install the base system, and configure KDE Plasma as the desktop environment.
6.  Once the installation finishes, your system will shut down automatically. Upon restarting, your fresh Arch Linux installation will be ready!

Features
--------

*   **Password Confirmation:** The installer verifies both root and user passwords to prevent any mistakes during password setup.
*   **Interactive Dialog Interface:** A user-friendly interface powered by `dialog` for an Archinstall-like experience.
*   **Automatic Timezone Configuration:** Timezone is hardcoded to `America/Chicago`, but can be customized in the script.
*   **GUI Desktop Environment:** Installs KDE Plasma as the default desktop environment with the **LTS kernel** for enhanced stability.

Customization
-------------

The script has a few configurable options:

*   **Timezone:** Currently set to `America/Chicago`. You can change this by editing the `TIMEZONE` variable in the script:
    
        TIMEZONE="America/Chicago"
    
    Change the value to your desired timezone (e.g., `Europe/London`).
*   **Disk Layout:** The script uses a default NVMe disk setup. If you need to use a different disk, modify the `DISK` variable:
    
        DISK="/dev/nvme0n1"
    
    Replace this with your desired disk (e.g., `/dev/sda`).
*   **Desktop Environment:** The script is designed for KDE Plasma but can be adapted for other desktop environments. Replace `plasma kde-applications sddm` with your preferred DE packages (e.g., `gnome gdm`).

Logging
-------

All installation logs are stored in `/var/log/arch_install.log`. If you encounter any issues during the installation, you can refer to this file for troubleshooting.

Support
-------

If you have any questions, issues, or need support, feel free to reach out to me via email at **thenintiescalled@gmail.com**.

Created by **binxmadisonjr** - Happy Arching!
