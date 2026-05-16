# Troubleshooting Guide

## 1. Kernel & Module Issues (`v4l2loopback`)

**Symptom:** The script says the module is missing, or `modprobe` fails.

* **Missing Kernel Headers:** The module cannot build or load without system headers matching your kernel version.

* **Fix (Ubuntu/Debian):** `sudo apt install linux-headers-$(uname -r)`
* **Fix (Fedora):** `sudo dnf install kernel-devel`

* **Secure Boot Interference:** If Secure Boot is enabled, the Linux kernel may block the `v4l2loopback` module because it isn't digitally signed.

* **Fix:** Disable **Secure Boot** in your BIOS/UEFI settings, or sign the module manually.

* **Module Not Loading:** The device `/dev/video10` does not appear in `/dev/`.

* **Fix:** Run `lsmod | grep v4l2loopback`. If the output is empty, force load it:

```bash
sudo modprobe v4l2loopback exclusive_caps=1 video_nr=10
```
* **Device Node Missing despite Load:** The module is loaded, but the specific `/dev/videoN` node is missing.

* **Fix:** Unload and reload with correct parameters:

```bash
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback exclusive_caps=1 video_nr=10
```
---

## 2. Permissions & Groups

**Symptom:** Script fails with "Permission Denied" when accessing `/dev/video10`.

* **Video Group Membership:** Your user must be a member of the `video` group to write to loopback devices.

* **Fix:** `sudo usermod -aG video $USER`
* **Note:** A **reboot** or log-out/log-in is strictly required for this to take effect.

---

## 3. `scrcpy` Versions & Package Conflicts

**Symptom:** "Camera source not supported," version is < 2.0, or "Command not found."

* **Outdated Repositories:** Standard `apt` repositories (especially on Ubuntu 22.04 LTS) often carry version 1.x.

* **Fix:** **Build from source.** Follow the custom build guide to get the latest features.

* **Path Conflict:** You installed a new version, but the script still finds an old `apt` version.

* **Fix:** Remove the old version: `sudo apt remove scrcpy`

### Why Universal Packages (Snap/Flatpak) are Discouraged:
* **Confinement:** Sandboxed apps cannot "see" `/dev/video10` without complex manual overrides.
* **Interface Mismatches:** You may encounter errors like `Content snap command-chain not found` or `snapd has no content interface slots` due to GPU driver mismatches.
* **Latency:** The sandbox layers can introduce lag, which is critical for a webcam feed.

---

## 4. Device Detection (`adb`)

**Symptom:** `adb devices` shows the device but says `unauthorized` or `no devices found`.

* **USB Debugging:** Ensure **USB Debugging** is enabled in Android Developer Options.
* **Udev Rules:** Your user might lack permission to access raw USB ports.

* **Fix:** Install `android-sdk-platform-tools-common` (Ubuntu) or `android-udev` (Arch).
* **Fix:** Add yourself to the group: `sudo usermod -aG plugdev $USER`.

* **Connection Reset:** If the device is stuck.
* **Fix:** `adb kill-server; adb devices`

---

## 5. Video Quality & Performance

**Symptom:** High latency, choppy video, or black screen.

* **Black Image:**
* Unlock the phone screen (Android often blocks camera access while locked).
* Grant camera permissions on the phone when prompted by `scrcpy`.

* **Latency/Lag:**
* Use a **USB 3.0** port and a high-quality cable.
* Lower the resolution in `config.conf` (e.g., use `800x600` for testing).
* Add `--v4l2-buffer=0` to the `scrcpy` command to reduce buffering delay.

---

## 6. Display & Wayland Issues

**Symptom:** Preview window flickers, "Always on Top" fails, or window doesn't appear.

* **Wayland Conflict:** Features like "Always on Top" behave inconsistently on Wayland.

* **Fix:** Set `SHOW_PREVIEW=false` in `config.conf` and use an external viewer like **OBS Studio** or **ffplay** to monitor the feed:

```bash
ffplay /dev/video10
```

---
## 7. Application Runs Successfully But There Is No Video Feed
**Issue:** The startup script completes without errors, and the active window/browser is open, but the video screen remains black, frozen, or says "no feed".

**Cause:** An old, stale instance of the video engine or your web browser might be hung up in the background, holding onto the video stream or port resource. Even if the script launches a new instance, the old ghost process will block the fresh feed.

**Solution:**
* **Restart the Interface:** Close your web browser (or video application) completely. Ensure all tabs and windows are shut down, then relaunch it.
* **Force Kill Stale Streams:** If restarting the browser doesn't work, open a terminal and manually kill any residual background streaming processes by running:
  ```bash
  pkill -f scrcpy
  pkill -f main.sh
  ```

### 8. Removing the Kernel Module (`v4l2loopback` / `modprobe`)

**Context:** Some users try removing the virtual camera kernel module (`modprobe`) using `sudo` when troubleshooting a missing video feed.

**Important Note:** If your application is already running successfully but you just aren't getting a video feed, **removing or resetting the modprobe module will not fix the issue.** A missing feed is a data streaming issue (usually fixed by Step 1 above), not a module driver issue.

However, if you explicitly want to unload the virtual camera loopback module from your system kernel, you can do so by running the following command:

```bash
sudo modprobe -r v4l2loopback
```

## Still not working?

If the above steps do not resolve the issue, please open a GitHub issue with the following information:
1.  **OS Version:** Output of `lsb_release -a`
2.  **scrcpy Version:** Output of `scrcpy --version`
3.  **ADB Status:** Output of `adb devices`
4.  **Error Logs:** Copy/paste the full terminal output from the script.

```
