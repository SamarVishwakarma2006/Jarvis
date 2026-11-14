import sys
import time

import cv2
import mediapipe as mp


def classify(hand):
    """Return a simple palm/fist pose; other poses are ignored."""
    fingers = (8, 12, 16, 20)
    joints = (6, 10, 14, 18)
    extended = [hand.landmark[tip].y < hand.landmark[joint].y for tip, joint in zip(fingers, joints)]
    if all(extended):
        return "RESUME_VOICE"
    if not any(extended):
        return "PAUSE_VOICE"
    return None


def main():
    camera = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    if not camera.isOpened():
        print("ERROR: Could not open the default camera.", flush=True)
        return 1

    hands_api = mp.solutions.hands
    stable_pose = None
    pose_since = time.monotonic()
    last_emitted = None

    try:
        with hands_api.Hands(max_num_hands=1, min_detection_confidence=0.65, min_tracking_confidence=0.6) as hands:
            print("CAMERA_ACTIVE", flush=True)
            while True:
                ok, frame = camera.read()
                if not ok:
                    print("ERROR: Camera frame could not be read.", flush=True)
                    return 1

                frame = cv2.flip(frame, 1)
                result = hands.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
                pose = classify(result.multi_hand_landmarks[0]) if result.multi_hand_landmarks else None
                now = time.monotonic()
                if pose != stable_pose:
                    stable_pose = pose
                    pose_since = now
                elif pose and pose != last_emitted and now - pose_since >= 0.9:
                    print(pose, flush=True)
                    last_emitted = pose
                elif pose is None:
                    last_emitted = None

                label = "Show an open palm to resume voice" if last_emitted == "PAUSE_VOICE" else "Show a fist to pause voice"
                cv2.putText(frame, label, (14, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (40, 220, 90), 2)
                cv2.putText(frame, "Camera is active locally | Q closes preview", (14, 56), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (40, 220, 90), 2)
                cv2.imshow("VoiceDesk gestures - camera active", frame)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
    finally:
        camera.release()
        cv2.destroyAllWindows()
        print("CAMERA_STOPPED", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
