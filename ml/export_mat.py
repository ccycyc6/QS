"""ScreenSense - export a trained MundusDet to hardware .mat files.

Writes one .mat per layer with the fields the Pango generator reads:
    weight (Cout,Cin,Kh,Kw) int32, bias (Cout,) int32, shift_k float,
    input  (1,Cin,H,W) int32, output (1,Cout,H,W) int32   <- bit-exact pair.

Quantisation is symmetric per layer (weights scaled into 9-bit signed), the
requantisation shift is a power of two chosen from the calibrated peak.
"""

import argparse
import os

import numpy as np
import torch
import torch.nn.functional as F
import scipy.io as sio

from model_template import MundusDet


# (mat index, attribute, kernel, stride, has_relu)
LAYERS = [
    (0,  'l0',  3, 2, True),  (1,  'l1',  3, 2, True),
    (2,  'l2',  3, 2, True),  (3,  'l3',  3, 2, True),
    (4,  'l4',  3, 1, True),  (5,  'l5',  3, 1, True),
    (6,  'l6',  3, 1, True),  (7,  'l7',  1, 1, False),
    (8,  'l8',  3, 1, True),  (9,  'l9',  3, 1, True),
    (10, 'l10', 1, 1, False),
]

# which layer output feeds each layer (the 80x45 branch leaves l4)
SRC = {0: 'in', 1: 0, 2: 1, 3: 2, 4: 3, 5: 4, 6: 5, 7: 6,
       8: 4, 9: 8, 10: 9}


def mat_names(i):
    conv = 'node_conv2d' if i == 0 else f'node_conv2d_{i}'
    if i in (7, 10):
        relu = None
    elif i == 0:
        relu = 'node_relu'
    elif i <= 6:
        relu = f'node_relu_{i}'
    else:
        relu = f'node_relu_{i - 1}'      # the generator's L8/L9 naming
    return conv, relu


def int_conv(x, w, b, stride, pad):
    """Exact integer convolution via float64 (all values are small integers)."""
    xt = torch.from_numpy(x.astype(np.float64))[None]
    wt = torch.from_numpy(w.astype(np.float64))
    bt = torch.from_numpy(b.astype(np.float64))
    y = F.conv2d(xt, wt, bt, stride=stride, padding=pad)
    return y[0].round().to(torch.int64).numpy()


def quantise(w, b, x, stride, kernel, relu):
    amax = float(np.abs(w).max())
    scale = (amax / 255.0) if amax > 0 else 1.0
    wq = np.clip(np.round(w / scale), -256, 255).astype(np.int32)
    bq = np.clip(np.round(b / scale), -(2**22), 2**22 - 1).astype(np.int64)

    acc = int_conv(x, wq, bq, stride, kernel // 2)

    peak = int(np.abs(acc).max())
    shift = 0
    while peak >> (shift + 1) > 110:
        shift += 1

    out = np.clip(acc >> shift, -128, 127)
    if relu:
        out = np.maximum(out, 0)
    return wq, bq.astype(np.int32), shift, out.astype(np.int32)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ckpt', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--classes', type=int, default=4)
    ap.add_argument('--calib', default=None, help='optional .npy (3,720,1280) uint8')
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    net = MundusDet(num_classes=args.classes)
    net.load_state_dict(torch.load(args.ckpt, map_location='cpu'))
    net.eval()

    if args.calib:
        img = np.load(args.calib).astype(np.int32) - 128
    else:
        rng = np.random.default_rng(0)
        img = rng.integers(0, 256, size=(3, 720, 1280)).astype(np.int32) - 128

    outs = {'in': img}
    for idx, attr, k, stride, relu in LAYERS:
        conv_name, relu_name = mat_names(idx)
        x = outs[SRC[idx]]
        layer = getattr(net, attr)
        w = layer.weight.detach().numpy()
        b = layer.bias.detach().numpy()

        wq, bq, shift, out = quantise(w, b, x, stride, k, relu)
        outs[idx] = out

        sio.savemat(os.path.join(args.out, conv_name + '.mat'), {
            'weight': wq,
            'bias': bq,
            'shift_k': float(shift),
            'input': x[None].astype(np.int32),
            'output': out[None].astype(np.int32),
        })
        if relu_name:
            sio.savemat(os.path.join(args.out, relu_name + '.mat'), {'shift_k': float(shift)})

        print(f'{conv_name:16s} {tuple(wq.shape)} stride={stride} shift={shift} out={out.shape}')

    print('done ->', args.out)


if __name__ == '__main__':
    main()
