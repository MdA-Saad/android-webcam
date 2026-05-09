# Troubleshooting

## `v4l2loopback` Issues

**Symptom:** The script says the module is missing or `modprobe` fails.

* **Missing Kernel Headers:** Even if the package is installed, it cannot "build" itself without headers.
* *Fix (Ubuntu/Debian):* `sudo apt install linux-headers-$(uname -r)`
* *Fix (Fedora):* `sudo dnf install kernel-devel`
* **Secure Boot:** If Secure Boot is enabled, the kernel may block the module because it isn't signed.
* *Fix:* You may need to sign the module manually or disable Secure Boot in your BIOS settings.
* **Module Not Loading:** If the device `/dev/video10` doesn't appear.
* *Fix:* Run `lsmod | grep v4l2loopback`. If empty, try `sudo modprobe v4l2loopback`.

## `scrcpy` Version Mismatch

**Symptom:** The script runs but says "Camera source not supported" or version is < 2.0.

* **Outdated Repositories:** Many LTS distros (like Ubuntu 22.04 or Debian) only carry version 1.x.
* *Fix (Snap):* `sudo snap install scrcpy`
* *Fix (Manual):* Build from source using the official [scrcpy server](https://github.com/Genymobile/scrcpy) instructions.
* **Path Conflict:** You installed the Snap version, but the script still finds the old `apt` version.
* *Fix:* Uninstall the apt version (`sudo apt remove scrcpy`) or ensure `/snap/bin` is early in your `$PATH`.

## Device Detection (`adb`)

**Symptom:** `adb devices` shows the device but says `unauthorized` or `no permissions`.

* **USB Debugging:** Ensure "USB Debugging" is toggled ON in Android Developer Options.
* **Udev Rules:** Your Linux user might not have permission to access the raw USB port.
* *Fix:* Install `android-sdk-platform-tools-common` (Ubuntu) or `android-udev` (Arch).
* *Fix:* Add yourself to the group: `sudo usermod -aG plugdev $USER` (then log out and back in).

## Permissions & Groups

**Symptom:** Script fails with "Permission Denied" when accessing `/dev/video10`.

* **Video Group:** You must be a member of the `video` group to use loopback devices.
* *Fix:* `sudo usermod -aG video $USER` (A reboot is usually required for this to take effect).

## Display & Wayland Issues

**Symptom:** The preview window doesn't appear, flickers, or "Always on Top" fails.

* **Wayland:** Some window management features in `scrcpy` behave differently on Wayland (default in Fedora/Ubuntu).
* *Fix:* Try running with the preview disabled (`SHOW_PREVIEW=false` in `config.conf`) and view the feed directly in your target app (like OBS or Zoom).


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
