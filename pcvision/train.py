"""ScreenSense - train MundusDet on the captured samples (PC side, WSL).

Class 0 is treated as background; every cell of a negative sample is labelled 0.
Both heads are supervised with the same target because the hardware argmax
sees the concatenation of the two.
"""

import argparse, csv, os, sys
import numpy as np
import torch
import torch.nn.functional as F
import cv2

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ml'))
from model_template import MundusDet

GRID_H, GRID_W = 45, 80


def load_samples(root):
    rows = []
    with open(os.path.join(root, 'labels.csv'), encoding='utf-8') as f:
        for r in csv.DictReader(f):
            rows.append((os.path.join(root, r['file']), int(r['cls']),
                         int(r['x']), int(r['y'])))
    return rows


def make_target(cls, x, y, k, device):
    """(1,k,45,80) with a one-hot cell; class 0 means background."""
    t = torch.zeros(1, k, GRID_H, GRID_W, device=device)
    t[:, 0] = 1.0
    if cls > 0:
        gx = min(GRID_W - 1, max(0, x * GRID_W // 1280))
        gy = min(GRID_H - 1, max(0, y * GRID_H // 720))
        t[0, :, gy, gx] = 0.0
        t[0, cls, gy, gx] = 1.0
    return t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data', default='data/raw')
    ap.add_argument('--classes', type=int, default=4)
    ap.add_argument('--epochs', type=int, default=40)
    ap.add_argument('--batch', type=int, default=2)
    ap.add_argument('--lr', type=float, default=1e-3)
    ap.add_argument('--out', default='build/model.pt')
    args = ap.parse_args()

    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    rows = load_samples(args.data)
    print(f'{len(rows)} samples on {device}')

    net = MundusDet(num_classes=args.classes).to(device)
    opt = torch.optim.Adam(net.parameters(), lr=args.lr)

    for ep in range(args.epochs):
        np.random.shuffle(rows)
        total, correct, seen = 0.0, 0, 0
        for i in range(0, len(rows), args.batch):
            opt.zero_grad()
            imgs, tgts = [], []
            for path, cls, x, y in rows[i:i + args.batch]:
                bgr = cv2.imread(path)
                rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
                # (x-128)/128 matches the RTL and ml/export_mat.py offset
                imgs.append(torch.from_numpy(rgb).permute(2, 0, 1).float() / 128.0 - 1.0)
                tgts.append(make_target(cls, x, y, args.classes, device))
            xb = torch.stack(imgs).to(device)
            tb = torch.cat(tgts)
            ha, hb = net(xb)
            loss = 0.5 * (F.binary_cross_entropy_with_logits(ha, tb) +
                          F.binary_cross_entropy_with_logits(hb, tb))
            loss.backward()
            opt.step()
            total += float(loss)
            pred = ha.argmax(1)
            seen += xb.shape[0]
            correct += int((pred == tb.argmax(1)).float().mean() * xb.shape[0])
        print(f'epoch {ep:3d}  loss {total / max(1, len(rows) / args.batch):.4f}  cell-acc {correct / max(1, seen):.3f}')

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    torch.save(net.state_dict(), args.out)
    print('saved', args.out)


if __name__ == '__main__':
    main()
