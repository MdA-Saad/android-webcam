![Latency](https://img.shields.io/badge/latency-35ms-brightgreen)
# Use android phone as virtual webcam on linux with low latency
### A Low-Latency, Open-Source Approach using `scrcpy` and `v4l2loopback`
### The "Pro" Linux Pipe (`scrcpy` + `v4l2`)
This method treats your phone like a raw hardware sensor. It uses **ADB (Android Debug Bridge)** to tunnel a raw video stream directly into the Linux kernel. There is no middleman, no heavy UI, and no "Pro" subscription required.

## Comparison with existing methods
When choosing how to bridge your phone to your PC, there are three common architectural paths. Here is how they compare qualitatively:
--- 
| Method | Latency | Privacy | Quality |
| :--- | :--- | :--- | :--- | :--- |
| **Commercial Apps (DroidCam, etc.)** | Moderate | Closed Source| Capped (Free) / Good (Paid) |
| **Browser-Based (IP Cam)** | High | Moderate | moderate |
| **The `scrcpy` + `v4l2` Pipe** | **Minimal** | High (Open Source) | **Uncapped (Raw Sensor)** |
---

## Tech Stack
To understand why this solution is superior, we need to look at the two pillars it stands on:

### **1. scrcpy (Screen Copy)**
`scrcpy` is a legend in the Android-Linux world. It works by pushing a tiny Java server to your phone that captures the screen (or camera) and streams it as raw H.264/H.265 video frames.
*   **Why it's fast:** It uses hardware-accelerated encoding on the phone.
*   **The "Camera" Flag:** Modern versions of `scrcpy` allow you to bypass the screen entirely and pull data directly from the camera sensor (`--video-source=camera`).

### **2. v4l2loopback**
Linux handles video devices through a framework called **Video4Linux2**. Usually, these are physical USB devices. `v4l2loopback` is a kernel module that creates **virtual** video devices.
*   **The "Pipe" Analogy:** Imagine a physical pipe. You "pour" the video stream from `scrcpy` into one end, and to the rest of your OS (Zoom, OBS, Discord), the other end of the pipe looks exactly like a plugged-in USB webcam.

---

## 🚀 How the Pipeline Works

The data flows through your system in a lean, direct path:

1.  **Capture:** Your phone's hardware encoder compresses the camera feed.
2.  **Transport:** The frames travel over a USB cable (via ADB) as a raw byte stream.
3.  **Bridge:** `scrcpy` receives these bytes on your PC and pipes them into `/dev/videoX`.
4.  **Consumption:** Your Linux kernel presents `/dev/videoX` as a standard UVC Webcam.

---

## Usage

### **Step 1: Clone repo**
```bash
git clone .....
```
### **Step 2: change directory to this project directory**
```bash
cd ..
```
### **Step 3: Install the dependencies**
```bash
./install.sh
```
### **Step 4: Run script**
```bash
./start-webcam.sh
```
---

## Why Use This?
*   **Privacy:** No 3rd party servers. Your video never leaves the USB cable.
*   **Performance:** Low CPU overhead on your PC or laptop.
*   **Flexibility:** Use your phone’s high-end lenses (Wide-angle, Macro, or Telephoto) as a webcam for your Linux desktop.

---

**Contribute to the Project:**
*If you find this useful, feel free to fork this repo, add a GUI, or improve the automation scripts!*
