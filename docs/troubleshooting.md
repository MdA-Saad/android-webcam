# Troubleshooting

## 'v4l2loopback not found'

**solution**
```bash
sudo apt install v4l2loopback-dkms # Debian
sudo dnf install v4l2loopback # Fedora
```

## Permision denied: /dev/videoN

**Solution**: Add user to video group and log out/in
```bash
sudo usermod -aG video $USER
# then reboot or logout
```

## No Android device found

**solution**:
 - Enable USB debugging on phone.
 - Unlock phone and accepet "Allow USB debugging?".
 - Run `adb devices` it should list your device
 - if not try `adb kill-server; adb devices`.

## Multiple devices detected

**Solution**: Set environment variable
```bash
export ANDROID_SERIAL="your_device_serial"
./start-webcam.sh
```
## Camera not working/black image

**Solution**:
 - Unlock the phone and keep it unlocked.
 - Grant camera permission when scrcpy ask.
 - Try a different camera with `--camera-id`.
 - Lower resolution.

## `scrcpy: --no-playback not recognized`

**Solution**:
```bash
sudo apt install scrcpy
```

## `v4l2loopback` already loaded but /dev/videoN missing

**Solution**: Unload and reload with correct parameters:
```bash
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback exclusive_caps=1 video_nr=10
```

## High latency/ choppy video
 - Use a USB 3.0 port and cable
 - Reduce resolution
 - Close background apps on phone
 - Try a different USB port

## Still not working?

Open an issue on Github with:
 - Output of `lsb-release -a`.
 - Output of `scrcpy --version`.
 - Output of `adb devices`.
 - Any error messages from the script.
