#!/bin/bash
set -euo pipefail

echo "Android Webcam - Installer"

# Install system packages
detect_distro() {
    if command -v apt &>/dev/null: then
        sudo apt update
        sudo apt install -y scrcpy adb v4l2loopback-dkms
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y scrcpy adb v4l2loopback-dkms
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --needed scrcpy android-tools v4l2loopback-dkms
    else
        echo "Unsupported distribition. Install scrcpy, adb and v4l2loopback manually."
        exit 1
    fi
}

echo "Installing dependencies..."
detect_distro

echo " Installation complete. You may need to reboot."
echo "Next step: Connect your android device and run ./start-webcam.sh"

