#!/bin/bash

# ======================================================================
# android-webcam - MIT License
#
# This script uses scrcpy (Apache 2.0) and v4l2loopback (GPL 2.0) 
# See CREDITS.md for full license details.
# ======================================================================

set -euo pipefail

# ABSOLUTE PATHS

SCRIPT_PATH="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_PATH")"
BUILD_PATH="$PROJECT_ROOT/build-packages"
ICON_FILE="$PROJECT_ROOT/assets/android-webcam.png"

# --- CONFIGURATION ---

VIDEO_NR=${VIDEO_NR:-"10"}
CARD_LABEL=${CARD_LABEL:-"Android Webcam"}
RES=${RES:-"1280x720"} # scrcpy uses 'x' instead of *
SHOW_PREVIEW=${SHOW_PREVIEW:-"true"}
CAMERA_ID=${CAMERA_ID:-"1"} # 1 for front and 0 for back camera
CONFIG_PATH="$PROJECT_ROOT/config.conf"
LEGACY_MODE=${LEGACY_MODE:-"false"}
NO_AUDIO=${NO_AUDIO:-"true"}
AUDIO_PLAY_BACK=${PLAY_AUDIO:-"false"}
MAX_FPS=${MAX_FPS:-"30"}
MAX_SIZE=${MAX_SIZE:-"1280"}
BIT_RATE=${BIT_RATE:-"4M"}
VIDEO_BUFFER=${VIDEO_BUFFER:-"0"}
CODEC=${CODEC:-"h264"}
ALWAYS_ON_TOP=${ALWAYS_ON_TOP:-"true"}

# CAMERA ICON PNG FILE

export SCRCPY_ICON_PATH="$ICON_FILE"

# --- CREATING CONFIG FILE IF NOT EXISTS ---

if [[ -f "$CONFIG_PATH" ]]; then
    echo "Loading configurations..."
    while IFS='=' read -r key val; do
        [[  "$key" =~ ^#.*$ ]] || [[ -z "$key" ]] && continue
        val=$(echo "$val" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
        export "$key=$val"
    done < "$CONFIG_PATH"
    source "$CONFIG_PATH"
fi

# Setting video device after setting the config file because this is a dependent variable.
VIDEO_DEVICE="/dev/video$VIDEO_NR"

# Checking scrcpy and adb installation

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
    echo ""
    echo "-----------------------------------------------------------------------"
    echo "Shutting down webcam..."

    # Give scrcpy and the system a moment to release the device
    sleep 1
    
    # Kill any stray scrcpy processes tied to this script, trap usually handles this but its safe backup
    pkill -P $$ scrcpy 2>/dev/null || true


    # Only unload the module if this script were the ones who loaded it
    # This prevents accidentally killing other virtual cameras
    if [[ "${LOADED_MODULE:-false}" == "true" ]]; then
        #echo "Unloading v4l2loopback module..."
        #pkexec modprobe -r v4l2loopback 2>/dev/null || echo "[INFO] Module busy; skipping unload."
        exit 0
    else
        echo "v4l2loopback remains loaded (was active before script start)."
    fi

    echo "Done. See you next time!"
    echo "-----------------------------------------------------------------------"
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
"$ADB_BIN" start-server &>/dev/null
device_count=$("$ADB_BIN" devices | awk 'NR>1 && $2=="device" {count++} END {print count+0}')
if [[ $device_count -eq 0 ]]; then
    echo "No android device found. Enable USB debugging and grant permission."
    exit 1
elif [[ $device_count -gt 1 ]]; then
    echo "Multiple devices detected:"
    "$ADB_BIN" devices | grep -E '\bdevice\b' || true
    echo "Please set the desired serial in the ANDROID_SERIAL environment variable."
    exit 1
fi

# Load v4l2loopback if already active
if ! lsmod | grep -q v4l2loopback && [[ -e "$VIDEO_DEVICE" ]]; then
    echo "[OK] Virtual camera $VIDEO_DEVICE is already running."
    LOADED_MODULE=true
else
    # Check if the device node exists; if not, the module was loaded with different params
    echo "Loading modprobe module for this session..."
    SUDO_PASS=$(zenity --password --title="Android Webcam Setup" 2>/dev/null)
    ZENITY_STATUS=$?
    
    if [ $ZENITY_STATUS -ne 0 ] || [ -z "$SUDO_PASS" ]; then
        echo "Authentication cancelled by user."
        exit 1
    fi
    if lsmod | grep -q v4l2loopback; then
        echo "$SUDO_PASS" | sudo -S modprobe -r v4l2loopback 2>/dev/null || true
    fi
    echo "$SUDO_PASS" | sudo -S modprobe v4l2loopback exclusive_caps=1 card_label="$CARD_LABEL" video_nr="$VIDEO_NR"

    unset SUDO_PASS
    LOADED_MODULE=true
fi

# Checking android version
echo "Checking android version"
check_android_sdk() {
    local sdk_version
    sdk_version=$("$ADB_BIN" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')

    if [ -z "$sdk_version" ] || ! [[ "$sdk_version" =~ ^[0-9]+$ ]]; then
        return 2
    fi

    if [ "$sdk_version" -lt 31 ]; then
        LEGACY_MODE="true"
        return 0
    else
        LEGACY_MODE="false"
        return 1
    fi
}

CHECK_ANDROID_SDK_STATUS=0
check_android_sdk || CHECK_ANDROID_SDK_STATUS=$?

if [ "$CHECK_ANDROID_SDK_STATUS" -eq 2 ]; then
    echo "Error: Device not found or unauthorized."
elif [ "$LEGACY_MODE" = "true" ]; then
    echo "Legacy mode enabled (< Android 12)"
else
    echo "Modern pipeline enabled (>= Android 12)"
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

# Common performance flags
SCRCPY_CMD=(
    "$SCRCPY_BIN"
    --v4l2-sink="$VIDEO_DEVICE"
    --video-buffer="$VIDEO_BUFFER"
    --video-bit-rate="$BIT_RATE"
    --window-title="$CARD_LABEL"
)

# Add audio flag true--NO_AUDIO
if [[ "$NO_AUDIO" == "true" ]]; then
    SCRCPY_CMD+=("--no-audio")
    echo "AUDIO is disabled"
fi

# Add flag for audio playback
if [[ "$AUDIO_PLAY_BACK" == "false" ]]; then
    SCRCPY_CMD+=("--no-audio-playback")
    echo " [OFF] AUDIO is mute"
fi

# Add window flag
if [[ "$SHOW_PREVIEW" == "false" ]]; then
    SCRCPY_CMD+=("--no-window")
    echo "NO PREVIEW mode"
fi

if [[ "$ALWAYS_ON_TOP" == "true" ]] && [[ "$SHOW_PREVIEW" == "true" ]]; then
    SCRCPY_CMD+=("--always-on-top")
    echo "ALWAYS ON TOP mode activated"
fi

if [[ "$LEGACY_MODE" == "true" ]]; then
    SCRCPY_CMD+=(
        "--stay-awake"
        "--max-fps" "$MAX_FPS"
        "--max-size" "$MAX_SIZE"
    )
    echo "[INFO] Running in LEGACY MODE. Please open the Camera APP on your phone."
else
    SCRCPY_CMD+=(
        "--video-source=camera"
        "--camera-size=$RES"
        "--camera-id=$CAMERA_ID"
        "--video-codec=$CODEC"
    )
    echo "[INFO] Running latest MODE camera capture"
fi


# Start streaming
echo " -----------------------------------------------------------------"
echo "Streaming to $VIDEO_DEVICE. Press Ctrl+C to stop."
echo "Select '$CARD_LABEL' as your camera in your projects or in softwares"
echo " -----------------------------------------------------------------"
"${SCRCPY_CMD[@]}"
