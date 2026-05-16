#!/bin/bash

pkill -f "zenity.*Android Webcam" 2>/dev/null | true

TIMEOUT=10
ADB_BIN="adb"
TARGET_SCRIPT="$(cd "$(dirname "$0")/../src" && pwd)/main.sh"

set -o pipefail

countdown_loop() {
    for ((i=$TIMEOUT; i>0; i--)); do
        REMAINING=$(( TIMEOUT -i ))
        if $ADB_BIN devices | grep -v "List" | grep -q "device$"; then
            echo "# Device detected! Starting video engine..."
            sleep 1
            echo "100"
            sleep 1
            exit 0
        fi

        PERCENTAGE=$(( ((TIMEOUT-i)*100) / TIMEOUT ))
        echo "$PERCENTAGE"
        echo "# Time remaining: ${i}s remaining\n\n1. Connect your android device via USB.\n2. Enable USB Debugging in developer options."
        sleep 1
    done
    exit 1
}

while true; do
    countdown_loop | zenity --progress \
        --title="Android Webcam: Action Required" \
        --percentage=0 \
        --auto-close \
        --auto-kill 2>/dev/null

    LOOP_STATUS=${PIPESTATUS[0]}

    if [ $LOOP_STATUS -eq 0 ]; then
        konsole -e bash "$TARGET_SCRIPT" >/dev/null 2>&1 & #nohop doenst open a terminal window
        while true; do
            zenity --question \
                --title="Android Webcam" \
                --text="Camera is active!" \
                --ok-label="Stop Camera" \
                --cancel-label="Continue using camera" \
                --no-wrap 2>/dev/null
                BUTTON_CLICK=$?
                if [ $BUTTON_CLICK -eq 0 ]; then
                    echo "Stopping background processes..."
                    pkill -INT -f "scrcpy" 2>/dev/null
                    pkill -INT -f "bash $TARGET_SCRIPT" 2>/dev/null

                    sleep 2
                    pkill -9 -f "scrcpy" 2>/dev/null
                    pkill -9 -f "bash $TARGET_SCRIPT" 2>/dev/null
                    zenity --info --title="Android Webcam" --text="Camera stopped successfully." --timeout=2 2>/dev/null
                    exit 0
                else
                    echo "User chose to keep camera running."
                fi
        done
    else
        zenity --question \
            --title="Retry?" \
            --text="No device was detected. Please ensure phone is connected and USB debugging is enable." \
            --no-wrap 2>/dev/null

        if [ $? -ne 0 ]; then
            exit 0
        fi
    fi
done

