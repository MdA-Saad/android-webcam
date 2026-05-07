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

# Adding user to video group so that they dont need sudo to use camera
if ! groups | grep -q video; then
    echo "Adding $USER to video group..."
    sudo usermod -aG video "$USER"
    sudo usermod -aG plugdev "$USER"
fi

APP_PATH=$(realpath "start-webcam.sh")
ICON_PATH="camera-web" # Standard system icon

cat <<EOF > android-webcam.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Android Webcam
Comment=Use android device as a webcam
Exec=$APP_PATH
Terminal=true
Categories=AudioVideo;Video;
EOF

mkdir -p ~/.local/share/applications
mv android-webcam.desktop ~/.local/share/applications/
chmod +x ~/.local/share/applications/android-webcam.desktop


echo "Installation complete."
echo "A shortcut has been added to your application Menu."
echo "Please reboot to apply groupd permissions."
echo "Next step: Connect your android device and run ./start-webcam.sh"

