#!/bin/bash

# This script removes all NVIDIA drivers from a Fedora machine.

echo "Identifying all installed NVIDIA packages..."
nvidia_packages=$(dnf list installed | grep -i nvidia | awk '{print $1}')

if [ -z "$nvidia_packages" ]; then
    echo "No NVIDIA packages found. Exiting..."
    exit 0
else
    echo "NVIDIA packages found. Preparing to remove..."
fi

# Remove the identified NVIDIA packages.
echo "Removing NVIDIA packages..."
sudo dnf remove -y $nvidia_packages

# Rebuild the initramfs to ensure it doesn't include NVIDIA drivers.
echo "Rebuilding the initial ramdisk..."
sudo dracut --force

echo "NVIDIA drivers have been removed. A reboot is recommended."

