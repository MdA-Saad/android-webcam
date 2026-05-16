#!/bin/bash

# ======================================================================
# android-webcam - MIT License
#
# This script automates the build of scrcpy (Apache 2.0) 
# See CREDITS.md for full license details.
# ======================================================================


set -euo pipefail

# --- CONFIGURATION ---
SCRCPY_VERSION=$(curl -s https://api.github.com/repos/Genymobile/scrcpy/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")') # this gives the latest version of the scrcpy
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # this is the path of this script
PROJECT_ROOT="$(dirname "$SCRIPT_PATH")" # This returns the root director of the project

BUILD_WORK_DIR="$PROJECT_ROOT/builds/meson_work"
SOURCE_DIR="$PROJECT_ROOT/builds/scrcpy_source"
INSTALL_DIR="$PROJECT_ROOT/build-packages"

echo "Checking distribution and installing dependencies..."

# Ensures scrcpy_version is not empty
if [[ -z "$SCRCPY_VERSION" ]]; then
    echo "[ERROR]: Could not fetch latest scrcpy version from GitHub. Check your internet connection."
    exit 1
fi

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
    sudo dnf install -y gcc git meson ninja-build libusb1-devel SDL2-devel \
        ffmpeg-devel libX11-devel wget adb
elif command -v pacman &> /dev/null; then
    echo "Detected Arch-based system."
    sudo pacman -S --needed --noconfirm base-devel meson ninja git \
        ffmpeg libusb sdl2 wget android-tools
else
    echo "Unsupported distro, Please manually install dependencies (ffmpeg, libusb, sdl2, meson, ninja)."
    exit 1
fi

# --- 2. DOWNLOAD PRE-BUILT SERVER ---
# We use the pre-built server to avoid needing the full Android SDK and dowloading png icon for scrcpy
echo "Downloading pre-built server $SCRCPY_VERSION..."
mkdir -p "$INSTALL_DIR"
echo "Downloading server"
wget -q --show-progress "https://github.com/Genymobile/scrcpy/releases/download/$SCRCPY_VERSION/scrcpy-server-$SCRCPY_VERSION" -O "$INSTALL_DIR/scrcpy-server"

# --- 3. CLONE AND BUILD CLIENT ---
mkdir -p "$PROJECT_ROOT/builds"
if [ ! -d "$SOURCE_DIR" ]; then
    git clone https://github.com/Genymobile/scrcpy "$SOURCE_DIR"
fi
cd "$SOURCE_DIR"
git fetch --all
git reset --hard "origin/$SCRCPY_VERSION" || git reset --hard "$SCRCPY_VERSION"
git checkout "$SCRCPY_VERSION"

echo "Configuring build..."
# We tell meson to use the server we just downloaded
# Using "Setup or Reconfigure patter"
# Common flags used in both scenarios
MESON_FLAGS=("--buildtype=release" "--strip" "-Db_lto=true" "-Dprebuilt_server=$INSTALL_DIR/scrcpy-server")

if [ -d "$BUILD_WORK_DIR" ]; then
    meson setup "$BUILD_WORK_DIR" --reconfigure "${MESON_FLAGS[@]}"
else
    meson setup "$BUILD_WORK_DIR" "${MESON_FLAGS[@]}"
fi

echo "Compiling..."
ninja -C "$BUILD_WORK_DIR"

# --- 4. DEPLOY TO PROJECT FOLDER ---
echo "Deploying binaries to $INSTALL_DIR..."
cp "$BUILD_WORK_DIR/app/scrcpy" "$INSTALL_DIR/"

# CLEANUP
# Only delete the source and meson build work if the binary exists
if [ -f "$INSTALL_DIR/scrcpy" ]; then
    echo "[OK] Build successfully. Initiating cleanup.."
    echo "Temporary files left in: $BUILD_WORK_DIR and $SOURCE_DIR"
    echo "[DELETE] temporary files manually to save storage."
fi

echo "-------------------------------------------------------"
echo "BUILD COMPLETE!"
echo "Binaries are located in: $INSTALL_DIR"
echo "To use them in your script, set:"
echo "Server: $INSTALL_DIR/scrcpy-server"
echo "Client: $INSTALL_DIR/scrcpy"
echo "-------------------------------------------------------"
