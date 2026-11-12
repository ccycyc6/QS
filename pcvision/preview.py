"""ScreenSense - show what the board would detect (bit-exact preview).

Runs hw_emulate over a folder of frames and writes annotated PNGs, so the PC
preview uses exactly the arithmetic the FPGA will run.
"""

import argparse, glob, os
import numpy as np
import cv2

from hw_emulate import HWModel, detect, FRAME_W, FRAME_H


def draw(frame, cls, gx, gy, conf, classes):
    out = frame.copy()
    cx, cy = gx * 16 + 8, gy * 16 + 8
    x0, y0 = max(0, cx - 32), max(0, cy - 20)
    x1, y1 = min(FRAME_W - 1, x0 + 64), min(FRAME_H - 1, y0 + 40)
    cv2.rectangle(out, (x0, y0), (x1, y1), (0, 255, 0), 2)
    label = f'{classes[cls] if cls < len(classes) else cls}  {conf}'
    cv2.putText(out, label, (x0, max(14, y0 - 6)),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mat', required=True)
    ap.add_argument('--frames', required=True)
    ap.add_argument('--out', default='build/preview')
    ap.add_argument('--classes', default='background,obj0,obj1,obj2')
    args = ap.parse_args()

    classes = args.classes.split(',')
    os.makedirs(args.out, exist_ok=True)
    model = HWModel(args.mat)

    files = sorted(glob.glob(os.path.join(args.frames, '*.png')) +
                   glob.glob(os.path.join(args.frames, '*.jpg')))
    print(f'{len(files)} frames')
    for i, f in enumerate(files):
        bgr = cv2.imread(f)
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        if rgb.shape[:2] != (FRAME_H, FRAME_W):
            rgb = cv2.resize(rgb, (FRAME_W, FRAME_H))
        cls, gx, gy, conf = detect(model, rgb)
        out = draw(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), cls, gx, gy, conf, classes)
        dst = os.path.join(args.out, os.path.basename(f))
        cv2.imwrite(dst, out)
        if i % 10 == 0:
            print(f'  {os.path.basename(f)} -> class {cls} ({gx},{gy}) conf {conf}')


if __name__ == '__main__':
    main()
