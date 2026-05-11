#!/usr/bin/env bash
set -euo pipefail

# Absolute path to the project directory
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_PATH")"
BUILD_PATH="$PROJECT_ROOT/build-packages"
ICON_FILE="$PROJECT_ROOT/assests/android-webcam.png"

# DEFINE VARIABLES
LEGACY_MODE=${LEGACY_MODE:-false}
PLAY_AUDIO=${PLAY_AUDIO:-false}

# Using my camera icon
export SCRCPY_ICON_PATH="$ICON_FILE"

# --- Load Config if exists ---
if [[ -f "$PROJECT_ROOT/config.conf" ]]; then
    source "$PROJECT_ROOT/config.conf"
fi

# --- CONFIGURATION ---
VIDEO_NR=${VIDEO_NR:-10}
VIDEO_DEVICE="/dev/video$VIDEO_NR"
CARD_LABEL=${CARD_LABEL:-"Android Webcam"}
RES=${RES:-"1280x720"} # scrcpy uses 'x' instead of *
SHOW_PREVIEW=${SHOW_PREVIEW:-false}
CAMERA_ID=${CAMERA_ID:-"1"} # 1 for front and 0 for back camera

if [[ -x "$BUILD_PATH/scrcpy" ]]; then
    SCRCPY_BIN="$BUILD_PATH/scrcpy"
    # Point to local server file
    if [[ -f "$BUILD_PATH/scrcpy-server" ]]; then
        export SCRCPY_SERVER_PATH="$BUILD_PATH/scrcpy-server"
    else
        echo "Warning: Custom scrcpy binary found, but scrcpy-server is missing in $BUILD_PATH"
    fi
else
    # Fallback to system scrcpy
    SCRCPY_BIN="scrcpy"

fi
if [[ -x "$BUILD_PATH/adb" ]]; then
    ADB_BIN="$BUILD_PATH/adb"
else
    # fallback to system adb
    ADB_BIN="adb"
fi

# --- Helper function ---
cleanup() {
    echo "Cleaning up..."

    # Give scrcpy and the system a moment to release the device
    sleep 1



    if [[ -n "${LOADED_MODULE:-}" ]]; then
        sudo modprobe -r v4l2loopback
        echo "Unloaded v4l2loopback module."
    fi
    exit 0
}

check_dependency() {
    local cmd_to_check=$1
    local name=$2
    if ! command -v "$1" &>/dev/null; then
        echo "Error: $name is not found."
        echo "Please run the ./install.sh script to resolve dependencies."
        exit 1
    fi
}

check_kernel_module() {
    if ! modinfo v4l2loopback &>/dev/null; then
        echo "Error: v4l2loopback kernel module not found."
        echo "Please install v4l2loopback for your distribution and run this script again."
        exit 1
    fi
}

# --- main script ---
trap cleanup SIGINT SIGTERM

echo "Initializing Webcam..."

check_dependency "$SCRCPY_BIN" "scrcpy"
check_dependency "$ADB_BIN" "adb"
check_kernel_module

# Check video group membership
if ! groups | grep -q video; then
    echo "User $USER is not in the 'video' group."
    echo "Run: re-run the installation script or do sudo usermod -aG video $USER and log out/in."
    exit 1
fi

# Android device detection
device_count=$("$ADB_BIN" devices | grep -c -E '\bdevice\b' || true)
if [[ $device_count -eq 0 ]]; then
    echo "No android device found. Enable USB debugging and grant permission."
    # exit 1
elif [[ $device_count -gt 1 ]]; then
    echo "Multiple devices detected:"
    "$ADB_BIN" devices | grep -E '\bdevice\b' || true
    echo "Please set the desired serial in the ANDROID_SERIAL environment variable."
    exit 1
fi

# Load v4l2loopback if not already active
if ! lsmod | grep -q v4l2loopback; then
    echo "Loading v4l2loopback kernel module..."
    sudo modprobe v4l2loopback exclusive_caps=1 card_label="$CARD_LABEL" video_nr=$VIDEO_NR
    LOADED_MODULE=true
else
    # Check if the device node exists; if not, the module was loaded with different params
    if [[ ! -e "$VIDEO_DEVICE" ]]; then
        echo "Module loaded but $VIDEO_DEVICE missing. Reloading..."
        sudo modprobe -r v4l2loopback
        sudo modprobe v4l2loopback exclusive_caps=1 card_label="$CARD_LABEL" video_nr=$VIDEO_NR
    fi
fi

# List camera IDs on android
echo "Checking Android camera(s)..."

# true prevents set -e from crashing if grep finds nothing
camera_list=$("$ADB_BIN" shell dumpsys camera | grep -E 'Camera ID' | head -1 || true)
if [[ -z $camera_list ]]; then
    echo " Could not enumerate cameras. Ensure the device is unlocked and camera permission granted."
else
    echo " Found: $camera_list"
fi

CAMERA_ID="1" # 0 for back and 1 for front
SCRCPY_CMD=(
    "$SCRCPY_BIN"
    --video-source=camera
    --camera-size="$RES"
    --camera-id="$CAMERA_ID"
    --v4l2-sink="$VIDEO_DEVICE"
    --no-audio-playback
)

if [[ "$SHOW_PREVIEW" == false ]]; then
    SCRCPY_CMD+=(--no-video-playback)
else
    SCRCPY_CMD+=(--always-on-top --window-title="Webcam Feed")
fi

# Start streaming
echo " -----------------------------------------------------------------"
echo "Streaming to $VIDEO_DEVICE. Press Ctrl+C to stop."
echo "Select '$CARD_LABEL' as your camera in your projects or in softwares"
echo " -----------------------------------------------------------------"
"${SCRCPY_CMD[@]}"
