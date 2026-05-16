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
            
            # We NO LONGER launch the script here. 
            # We just exit with 0 to tell the main loop we found the device.
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
        # 1. SUCCESS! Launch the camera script in the background.
        nohup bash "$TARGET_SCRIPT" >/dev/null 2>&1 &
        
        # 2. IMMEDIATELY open the control window. 
        # The script will pause right here and wait for you to click a button.
        zenity --question \
            --title="Android Webcam" \
            --text="Camera is active!\n\nLeave this window open. Click below when you are ready to turn it off." \
            --ok-label="Stop Camera" \
            --cancel-label="Keep Running in Background" \
            --no-wrap 2>/dev/null

        # 3. If you clicked "Stop Camera" (exit code 0), kill everything.
        if [ $? -eq 0 ]; then
            echo "Stopping background processes..."
            pkill -TERM -f "bash $TARGET_SCRIPT" 2>/dev/null
            pkill -f "scrcpy" 2>/dev/null
            zenity --info --title="Android Webcam" --text="Camera stopped successfully." --timeout=2 2>/dev/null
        fi
        
        # 4. Exit this startup script cleanly.
        exit 0
    else
        # TIMEOUT! Ask if the user wants to retry.
        zenity --question \
            --title="Retry?" \
            --text="No device was detected. Please ensure phone is connected and USB debugging is enabled." \
            --no-wrap 2>/dev/null

        # If they click Cancel/X, exit. If they click OK, the while loop restarts.
        if [ $? -ne 0 ]; then
            exit 0
        fi
    fi
done
