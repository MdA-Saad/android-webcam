#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
SCRCPY_VERSION="v2.4" # Update this to the latest release version
PROJECT_ROOT=$(pwd)
BUILD_DIR="$PROJECT_ROOT/build"
INSTALL_DIR="$PROJECT_ROOT/build-packages/scrcpy"

echo "Checking distribution and installing dependencies..."

# --- 1. DETECT DISTRO & INSTALL DEPENDENCIES ---
if command -v apt &> /dev/null; then
    echo "Detected Debian/Ubuntu-based system."
    sudo apt update
    sudo apt install -y ffmpeg libsdl2-2.0-0 adb wget \
                     gcc git pkg-config meson ninja-build libavcodec-dev \
                     libavdevice-dev libavformat-dev libavutil-dev \
                     libswresample-dev libusb-1.0-0-dev libsdl2-dev
elif command -v dnf &> /dev/null; then
    echo "Detected Fedora/RHEL-based system."
    sudo dnf install -y gcc git meson ninja-build libusb1-devel \
                     SDL2-devel android-tools ffmpeg-devel libX11-devel
elif command -v pacman &> /dev/null; then
    echo "Detected Arch-based system."
    sudo pacman -S --needed --noconfirm base-devel meson ninja git \
                                       ffmpeg sdl2 libusb android-tools
else
    echo "Unsupported distribution. Please install dependencies manually."
    exit 1
fi

# --- 2. DOWNLOAD PRE-BUILT SERVER ---
# We use the pre-built server to avoid needing the full Android SDK
echo "Downloading pre-built server $SCRCPY_VERSION..."
mkdir -p "$INSTALL_DIR"
wget "https://github.com/Genymobile/scrcpy/releases/download/$SCRCPY_VERSION/scrcpy-server-$SCRCPY_VERSION" \
     -O "$INSTALL_DIR/scrcpy-server"

# --- 3. CLONE AND BUILD CLIENT ---
if [ ! -d "scrcpy_source" ]; then
    git clone https://github.com/Genymobile/scrcpy scrcpy_source
fi

cd scrcpy_source
git checkout "$SCRCPY_VERSION"

echo "Configuring build..."
# We tell meson to use the server we just downloaded
meson setup "$BUILD_DIR" --buildtype=release --strip -Db_lto=true \
    -Dprebuilt_server="$INSTALL_DIR/scrcpy-server" --reconfigure

echo "Compiling..."
ninja -C "$BUILD_DIR"

# --- 4. DEPLOY TO PROJECT FOLDER ---
echo "Deploying binaries to $INSTALL_DIR..."
cp "$BUILD_DIR/app/scrcpy" "$INSTALL_DIR/"

echo "-------------------------------------------------------"
echo "BUILD COMPLETE!"
echo "Binaries are located in: $INSTALL_DIR"
echo "To use them in your script, set:"
echo "export SCRCPY_SERVER_PATH=$INSTALL_DIR/scrcpy-server"
echo "-------------------------------------------------------"
