#!/usr/bin/env python3
"""
Test the android webcam with opencv.
Run this after starting the webcam script.
"""
import argparse
import time

try:
    import cv2
except ImportError:
    print(" Error: Missing dependencies!")
    print(" Please run: pip install opencv-python")
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="YOLOv8 detection on Android webcam")
    parser.add_argument(
            "--dev",
            type=int,
            default=10,
            help="The N in /dev/videoN (default: 10)"
    )
    args = parser.parse_args()

    # The virtual camera device
    CAM_DEVICE = f"/dev/video{args.dev}"


    print(f"Opening {CAM_DEVICE}...")
    cap = cv2.VideoCapture(CAM_DEVICE)
    if not cap.isOpened():
        print("Error: Cannot open camera. Is the webcam script running?.")
        return

    # Set resolution (should match what scrcpy streams)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    fps=0
    frame_count=0
    start_time = time.time()

    while True:
        ret, frame = cap.read()
        if not ret:
            print("Failed to grab frame")
            break

        # Calcualte approximate FPS
        frame_count+=1
        if frame_count % 30 ==0:
            elapsed = time.time() - start_time
            fps = frame_count / elapsed

        # Display information on frame
        cv2.putText(frame, f"FPS: {fps:.1f}", (10,30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0,255,0), 2)
        cv2.imshow("Android Webcam", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()


