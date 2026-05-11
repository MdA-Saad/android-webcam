#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
SCRCPY_VERSION=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")') # this gives the latest version of the scrcpy
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # this is the path of this script
PROJECT_ROOT="$(dirname "$SCRIPT_PATH")" # This returns the root director of the project

BUILD_WORK_DIR="$PROJECT_ROOT/builds/meson_work"
SOURCE_DIR="$PROJECT_ROOT/builds/scrcpy_source"
INSTALL_DIR="$PROJECT_ROOT/build-packages"

echo "Checking distribution and installing dependencies..."

# --- 1. DETECT DISTRO & INSTALL DEPENDENCIES ---
if command -v apt &> /dev/null; then
    echo "Detected Debian/Ubuntu-based system."
    sudo apt update
    sudo apt install -y ffmpeg libsdl2-2.0-0 adb wget \
                     gcc git pkg-config meson ninja-build libavcodec-dev \
                     libavdevice-dev libavformat-dev libavutil-dev \
                     libswresample-dev libusb-1.0-0-dev libsdl2-dev
else
    echo "Please install dependencies manually."
    exit 1
fi

# --- 2. DOWNLOAD PRE-BUILT SERVER ---
# We use the pre-built server to avoid needing the full Android SDK and dowloading png icon for scrcpy
echo "Downloading pre-built server $SCRCPY_VERSION..."
mkdir -p "$INSTALL_DIR"
echo "Downloading server"
wget "https://github.com/Genymobile/scrcpy/releases/download/$SCRCPY_VERSION/scrcpy-server-$SCRCPY_VERSION" \
     -O "$INSTALL_DIR/scrcpy-server"

# --- 3. CLONE AND BUILD CLIENT ---
mkdir -p "$PROJECT_ROOT/builds"
if [ ! -d "$SOURCE_DIR" ]; then
    git clone https://github.com/Genymobile/scrcpy "$PROJECT_ROOT/builds/scrcpy_source"
fi
cd "$SOURCE_DIR"
git fetch --all
git checkout "$SCRCPY_VERSION"

echo "Configuring build..."
# We tell meson to use the server we just downloaded
meson setup "$BUILD_WORK_DIR" --buildtype=release --strip -Db_lto=true \
    -Dprebuilt_server="$INSTALL_DIR/scrcpy-server" --reconfigure

echo "Compiling..."
ninja -C "$BUILD_WORK_DIR"

# --- 4. DEPLOY TO PROJECT FOLDER ---
echo "Deploying binaries to $INSTALL_DIR..."
cp "$BUILD_WORK_DIR/app/scrcpy" "$INSTALL_DIR/"

# CLEANUP
# Only delete the source and meson build work if the binary exists
if [ -f "$INSTALL_DIR/scrcpy" ]; then
    echo "Build successfully. Cleaning up temporary build files..."
    rm -rf "$BUILD_WORK_DIR" # Be careful with the use of command `rm -rf`
    rm -rf "$SOURCE_DIR" # This is optional to remove
fi

echo "-------------------------------------------------------"
echo "BUILD COMPLETE!"
echo "Binaries are located in: $INSTALL_DIR"
echo "To use them in your script, set:"
echo "Server: $INSTALL_DIR/scrcpy-server"
echo "Client: $INSTALL_DIR/scrcpy"
echo "-------------------------------------------------------"
