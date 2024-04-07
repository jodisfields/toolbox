#!/bin/bash

# This script installs the latest firmware awnd NVIDIA drivers on a Fedora machine.

echo "Enabling RPM Fusion repositories for NVIDIA drivers..."
sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

echo "Updating the system..."
sudo dnf update -y

echo "Installing the latest NVIDIA drivers..."
sudo dnf install -y akmod-nvidia
sudo dnf install -y xorg-x11-drv-nvidia-cuda

echo "Installing DKMS to automatically rebuild NVIDIA kernel modules..."
sudo dnf install -y dkms

echo "Updating firmware for all devices..."
sudo dnf install -y fwupd
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
sudo fwupdmgr update

echo "Installation complete. A reboot is recommended."

