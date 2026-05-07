#!/usr/bin/env python3
"""
Realtime object detection using yolo8n via android webcam.
Requires: pip install ultralytics opencv-python
"""
import sys
import argparse

try:
    import cv2
    from ultralytics import YOLO
except ImportError:
    print(" Error: Missing dependencies!")
    print(" Please run: pip install -r requirements-optional.txt")
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
    video_device = f"/dev/video{args.dev}"
    # Load yolo nano (for speed)
    try:
        model=YOLO("yolo8n.pt")
    except Exception as e:
        print(f"Error loading model: {e}")
        sys.exit()

    # Virtual Camera
    cap = cv2.VideoCapture("/dev/videoN")
    if not cap.isOpened():
        print("Error: Cannot open /dev/video$N")
        sys.exit()

    # Set internal buffer to small to reduce lag
    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)


    # Reduce resolution for faster inference
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    print("Press 'q' to quit.")

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Run yolo inference
        results = model(frame, verbose=false)

        # Draw bouding box and labels
        annotated_frame = results[0].plot()

        cv2.imshow("Android Webcam", annotated_frame)
        
        # Break loop on 'q'
        if cv2.waitKey(1)&0xFF == ord('q'):
            break
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
