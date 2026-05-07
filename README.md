# Android-Webcam: The "Pro" Linux Pipe
![Latency](https://img.shields.io/badge/latency-~35ms-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

Turn your Android phone into a high-performance, low-latency virtual webcam for Linux. No proprietary apps, no subscriptions, and zero privacy compromises.

---

## Why this exists?
Most "Phone-as-Webcam" solutions rely on closed-source drivers or laggy network streams. This project uses a **direct hardware-to-kernel pipe** to achieve near-zero latency by leveraging `scrcpy` and the Linux `v4l2loopback` module.

> **The Result:** Your Linux system treats your phone exactly like a physical USB webcam.

---

## 📊 Comparison
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

### 3. Configure & Launch
```bash
cp config.example.conf config.conf
# Edit config.conf with text editor to set your resolution/device ID
./start-webcam.sh
```

---

## Optional: AI Object Detection
If you want to use your phone as an AI-powered smart camera, we provide a YOLOv8 integration.

**Install AI Extras:**
```bash
pip install -r requirements-cv.txt
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
*   **Linux Native:** Works perfectly with Zoom, Discord, OBS, and Teams.

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
