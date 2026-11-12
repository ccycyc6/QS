"""ScreenSense - camera capture with click-to-label.

Cross-platform (Linux V4L2 / Windows DSHOW).  Shows a 1280x720 letterboxed
preview with the 16x16 grid the network uses, records one sample per Space
press: the frame, the clicked centre and the current class.

Keys:  0-9 select class   Space save   c clear centre   q quit
"""

import argparse, csv, os, sys, time
import cv2
import numpy as np

TARGET_W, TARGET_H = 1280, 720


def open_camera(index):
    backend = cv2.CAP_DSHOW if sys.platform.startswith('win') else cv2.CAP_V4L2
    cap = cv2.VideoCapture(index, backend)
    if not cap.isOpened():
        cap = cv2.VideoCapture(index)
    return cap if cap.isOpened() else None


def lock_exposure(cap):
    """Ask the camera for manual exposure/white balance; ignore if unsupported."""
    try:
        cap.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)   # V4L2: 1 = manual
        cap.set(cv2.CAP_PROP_AUTO_WB, 0)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
    except Exception:
        pass


def letterbox(frame):
    h, w = frame.shape[:2]
    scale = min(TARGET_W / w, TARGET_H / h)
    nw, nh = int(w * scale), int(h * scale)
    resized = cv2.resize(frame, (nw, nh), interpolation=cv2.INTER_AREA)
    canvas = np.zeros((TARGET_H, TARGET_W, 3), dtype=np.uint8)
    x0, y0 = (TARGET_W - nw) // 2, (TARGET_H - nh) // 2
    canvas[y0:y0 + nh, x0:x0 + nw] = resized
    return canvas


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--index', type=int, default=0)
    ap.add_argument('--out', default='data/raw')
    ap.add_argument('--classes', type=int, default=4)
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    csv_path = os.path.join(args.out, 'labels.csv')
    fresh = not os.path.exists(csv_path)
    csv_f = open(csv_path, 'a', newline='', encoding='utf-8')
    writer = csv.writer(csv_f)
    if fresh:
        writer.writerow(['file', 'cls', 'x', 'y'])

    cap = open_camera(args.index)
    if cap is None:
        raise SystemExit(f'cannot open camera {args.index} (on WSL there is no /dev/video; run this on the Ubuntu desktop)')
    lock_exposure(cap)

    state = {'cls': 0, 'cx': None, 'cy': None}

    def on_mouse(event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            state['cx'], state['cy'] = x, y

    cv2.namedWindow('capture')
    cv2.setMouseCallback('capture', on_mouse)

    saved = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        view = letterbox(frame)

        for gx in range(0, TARGET_W, 160):
            cv2.line(view, (gx, 0), (gx, TARGET_H), (40, 40, 40), 1)
        for gy in range(0, TARGET_H, 160):
            cv2.line(view, (0, gy), (TARGET_W, gy), (40, 40, 40), 1)

        if state['cx'] is not None:
            cv2.drawMarker(view, (state['cx'], state['cy']), (0, 255, 0),
                           cv2.MARKER_CROSS, 24, 2)

        cv2.putText(view,
                    f'class {state["cls"]}  saved {saved}   [0-9] cls  [space] save  [c] clear  [q] quit',
                    (12, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        cv2.imshow('capture', view)

        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            break
        if ord('0') <= key <= ord('9'):
            state['cls'] = key - ord('0')
        elif key == ord('c'):
            state['cx'], state['cy'] = None, None
        elif key == 32 and state['cx'] is not None:
            name = f'sample_{int(time.time() * 1000)}.png'
            cv2.imwrite(os.path.join(args.out, name), view)
            writer.writerow([name, state['cls'], state['cx'], state['cy']])
            csv_f.flush()
            saved += 1

    cap.release()
    cv2.destroyAllWindows()
    csv_f.close()
    print(f'saved {saved} samples to {args.out}')


if __name__ == '__main__':
    main()
