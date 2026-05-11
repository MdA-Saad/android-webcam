<p align="center">
    <img src="assets/android-webcam.png" width="350" title="android-webcam">
</p>
# Android-Webcam: Use android device as a low latency webcam
![Latency](https://img.shields.io/badge/latency-~35ms-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

Turn your Android phone into a high-performance, low-latency virtual webcam for Linux. No proprietary apps, no subscriptions, and zero privacy compromises.

---

## Why this exists?
Most "Phone-as-Webcam" solutions rely on closed-source drivers and applications this approach introduces extra latency which is undesirable for many machine learning and computer vision applications. This project uses a **direct hardware-to-kernel pipe** to achieve near-zero latency by leveraging `scrcpy` and the Linux `v4l2loopback` module.

> **The Result:** Your Linux system treats your phone exactly like a physical USB webcam.

---

## Comparison
| Method | Latency | Privacy | Quality |
| :--- | :--- | :--- | :--- |
| **Commercial Apps (DroidCam, etc.)** | Moderate | Closed Source | Capped (Free) |
| **Browser-Based (IP Cam)** | High | Moderate | Compressed |
| **Linux Pipe (`scrcpy` + `v4l2`)** | **Minimal (~35ms)** | **Open Source** | **Raw Sensor Output** |

---

## Tech Stack
*   **scrcpy:** Captures the camera sensor via ADB using hardware-accelerated H.264/H.265 encoding.
*   **v4l2loopback:** A kernel module that creates the "virtual pipe" (`/dev/videoN`) for your OS to read.

---

## How it Works

1.  **Capture:** Your phone hardware compresses the feed.
2.  **Transport:** Frames travel over USB/ADB as a raw byte stream.
3.  **Bridge:** `scrcpy` pipes bytes into `/dev/video10`.
4.  **Consumption:** Linux presents it as a standard **UVC Webcam**.

---

## Requirements
*   **OS:** Linux (Ubuntu/Kubuntu, Fedora, Arch, etc.)
*   **Mobile:** Android with **USB Debugging** enabled.
*   **Cable:** USB 3.0 recommended for 1080p+ resolutions.

---

## Quick Start

### 1. Clone & Setup
```bash
git clone https://github.com/MdA-Saad/android-webcam.git
cd android-webcam
chmod +x *.sh
```

### 2. Install Dependencies
```bash
./install.sh
```

### 3. Launch
```bash
./start-webcam.sh
```
---

## Usage Instructions

Once you have completed the installation via `./install.sh`, follow these steps to start using your phone as a high-fidelity webcam.

### Method 1: Wired (Lowest Latency)
*Best for professional meetings, streaming, and AI detection.*

1.  **Connect:** Plug your Android phone into your PC via a USB cable.
2.  **Authorize:** If prompted on your phone, allow **USB Debugging**.
3.  **Launch:** 
    *   **GUI:** Double click on **"Android Webcam"**.
    *   **CLI:** Run `./start-webcam.sh` from the terminal.

---

### Method 2: Wireless (ADB over WiFi)
*Best for freedom of movement. Note: Latency may increase slightly based on your router.*

1.  **Initial Pair:** Connect your phone via USB cable **one last time**.
2.  **Enable WiFi Mode:** Run the following command in your terminal:
    ```bash
    adb tcpip 5555
    ```
3.  **Identify IP:** Find your phone's IP address (Settings > About Phone > Status or WiFi settings). It usually looks like `192.168.1.XX`.
4.  **Connect Wirelessly:** Disconnect the cable and run:
    
    ```bash
    adb connect [YOUR_PHONE_IP]:5555
    ```
5.  **Launch:** Click the **Android Webcam** icon or run `./start-webcam.sh`.

---

## Optional: AI Object Detection
If you want to use your phone as an AI-powered smart camera, we provide a YOLOv8 integration.

**Install AI Extras:**
```bash
pip install -r requirements-optional.txt
```

**Run Detection:**
```bash
# Uses the camera stream on /dev/video10 (set in config)
python3 detect.py --dev 10
```

---

## Privacy & Performance
*   **Total Privacy:** Data never leaves your USB cable. No cloud servers involved.
*   **Battery Efficient:** Uses the phone's dedicated H.264 encoder chip.
*   **Linux Native:** Works perfectly with in computer vision and machine learning scripts (opencv, pytorch, etc.,) along with OBS, Zoom, google meet, etc.,

---

### Contributing
Found a bug or want to add a GUI? 
1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'Add AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

**Made with ❤️ for the Linux Community.**
