set -e
cd /mnt/e/qs/ScreenSense/pcvision
rm -rf /tmp/raw /tmp/mats3 && mkdir -p /tmp/raw
python3 - <<'PY'
import numpy as np, cv2, csv, os
os.makedirs('/tmp/raw', exist_ok=True)
rows = []
for i in range(4):
    img = np.zeros((720, 1280, 3), np.uint8)
    cx, cy = 200 + i * 180, 300 + i * 60
    cv2.rectangle(img, (cx - 60, cy - 40), (cx + 60, cy + 40), (40, 200, 240), -1)
    p = f'/tmp/raw/s{i}.png'
    cv2.imwrite(p, img)
    rows.append((f's{i}.png', 1 + (i % 3), cx, cy))
with open('/tmp/raw/labels.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['file','cls','x','y']); w.writerows(rows)
print('synthetic dataset ready')
PY
time python3 train.py --data /tmp/raw --classes 4 --epochs 1 --batch 2 --out /tmp/m3.pt 2>&1 | tail -4
cd /mnt/e/qs/ScreenSense/ml
python3 export_mat.py --ckpt /tmp/m3.pt --out /tmp/mats3 --classes 4 > /tmp/e3.log 2>&1 && tail -1 /tmp/e3.log
cd /mnt/e/qs/ScreenSense/pcvision
python3 preview.py --mat /tmp/mats3 --frames /tmp/raw --out /tmp/prev 2>&1 | tail -3
ls /tmp/prev | head -3
