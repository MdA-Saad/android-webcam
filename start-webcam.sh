#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
VIDEO_NR=10
VIDEO_DEVICE="/dev/video$VIDEO_NR"
CARD_LABEL="Android Webcam"
RES="1280*720"
SHOW_PREVIEW=false

# --- Load Config if exists ---
if [[ -f "config.conf" ]]; then
    source config.conf
else
    # GUI
    RES=$(zenity --list --title="Select Resolution" --radiolist --column="Pick" --column="Resolution" True "1280*720" FALSE "640*480"
    [[ -z "$RES" ]] && exit 0 # Exit if user cancels
fi

# --- Helper function ---
cleanup() {
    echo "Cleaning up..."
    if [[ -n "${LOADED_MODULE:-}" ]]; then
        sudo modprobe -r v4l2loopback
        echo "Unloaded v4l2loopback module."
    fi
    exit 0
}

check_dependency() {
    if ! command -v "$1" &>/dev/null; then
        echo "Error: $1 is not installed. Install with: sudo apt install $1"
        exit 1
    fi
}

check_kernel_module() {
    if ! modinfo v4l2loopback &>/dev/null; then
        echo "Error: v4l2loopback kernel module not found."
        echo "Install it: Sudo apt install v4l2loopback-dkms"
        exit 1
    fi
}

# --- main script ---
trap cleanup SIGINT SIGTERM

echo "Initializing Webcam..."

check_dependency "scrcpy"
check_dependency "adb"
check_kernel_module

# Check video group membership
if ! groups | grep -q video; then
    echo "User $USER is not in the 'video' group."
    echo "Run:sudo usermod -aG video $USER and log out/in."
    exit 1
fi

# Android device detection
device_count=$(adb devices | grep -E 'device$' | wc -l)
if [[ $device_count -eq 0 ]]; then
    echo "No android device found. Enable USB debugging and grant permission."
    exit 1
elif [[ $device_count -gt 1 ]]; then
    echo "Multiple devices detected:"
    adb devices | grep -E 'device$'
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
        sudo modprobe v4l2loopback exclusive_caps=1 card_label="$CARD_LABEL video_nr=$VIDEO_NR
    fi
fi

# List camera IDs on android
echo "Checking Android camera(s)..."
camera_list=$(adb shell dumpsys camera | grep -E 'Camera ID' | head -1 || true)
if [[ -z $camera_list ]]; then
    echo " Could not enumerate cameras. Ensure the device is unlocked and camera permission granted."
else
    echo " $camera_list"
fi

SCRCPY_CMD=(
    scrcpy
    --video-source=camera
    --camera-size="$RES"
    --v4l2-sink="$VIDEO_DEVICE"
    --no-audio-playback
)

if [[ "$SHOW_PREVIEW" == false ]]; then
    SCRCPY_CMD+=(--no-video-playback)
else
    SCRCPY_CMD+=(--always-on-top --window-title="Webcam Feed")
fi

# Start streaming
echo "Streaming to $VIDEO_DEVICE. Press Ctrl+C to stop."
echo "Select '$CARD_LEVEL' as your camera."

exec "${SCRCPY_CMD[@]}"
