#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""用 MES2L676-200HP(盘古200Pro+) 官方例程的引脚，重写本工程的 hdmi_loop.fdc。

背景:
  * 本工程原始约束按作者的小眼睛 PG200K-mini 板编写:
      - HDMI RX 有 13 根信号引脚与 200Pro+ 不同
      - I2C(hd_scl/hd_sda) 引脚不同
      - HDMI TX 是 FPGA 直接输出 TMDS 差分对(9 根)
  * 200Pro+ 的 HDMI TX 由板载 MS7210 完成 TMDS 编码, FPGA 输出并行 RGB,
    因此 TX 从 9 根变成 28 根 (pixclk/vs/hs/de + R/G/B[7:0])。

用法:
  python make_proplus_fdc.py \
      --base prj_pds/hdmi_loop_200kmini.fdc \
      --vendor-fdc <官方例程>/2_10_hdmi_loop/hdmi_loop.fdc \
      --out prj_pds/hdmi_loop.fdc
"""
import argparse
import re
import sys

# 从官方 HDMI 回环例程直接照搬的信号(接收侧 + I2C + 发送侧)
RX_SIGNALS = (
    [f"r_in[{i}]" for i in range(8)]
    + [f"g_in[{i}]" for i in range(8)]
    + [f"b_in[{i}]" for i in range(8)]
    + ["de_in", "hs_in", "vs_in", "pixclk_in"]
)
I2C_SIGNALS = ["hd_scl", "hd_sda"]
TX_SIGNALS = (
    ["pixclk_out", "vs_out", "hs_out", "de_out"]
    + [f"r_out[{i}]" for i in range(8)]
    + [f"g_out[{i}]" for i in range(8)]
    + [f"b_out[{i}]" for i in range(8)]
)
TAKE_FROM_VENDOR = RX_SIGNALS + I2C_SIGNALS + TX_SIGNALS

LOC_RE = re.compile(r"^define_attribute\s+\{p:([^}]+)\}\s+\{PAP_IO_LOC\}\s+\{([^}]*)\}\s*$")


def read_map(path):
    pins = {}
    for line in open(path, encoding="utf-8", errors="ignore"):
        m = LOC_RE.match(line.strip())
        if m:
            pins[m.group(1)] = m.group(2)
    return pins


def block(sig, loc, std="LVCMOS33", vccio="3.3", direction="OUTPUT"):
    return [
        f"define_attribute {{p:{sig}}} {{PAP_IO_DIRECTION}} {{{direction}}}",
        f"define_attribute {{p:{sig}}} {{PAP_IO_LOC}} {{{loc}}}",
        f"define_attribute {{p:{sig}}} {{PAP_IO_VCCIO}} {{{vccio}}}",
        f"define_attribute {{p:{sig}}} {{PAP_IO_STANDARD}} {{{std}}}",
        "define_attribute {p:%s} {PAP_IO_NONE} {TRUE}" % sig,
    ]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="原始(200K mini)约束文件")
    ap.add_argument("--vendor-fdc", required=True, help="200Pro+ 官方 hdmi_loop 例程的 .fdc")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    vend = read_map(args.vendor_fdc)
    missing = [s for s in TAKE_FROM_VENDOR if s not in vend]
    if missing:
        sys.exit("官方约束里缺少这些信号: " + ", ".join(missing))

    text = open(args.base, encoding="utf-8").read().replace("\r\n", "\n")
    lines = text.split("\n")

    # 1. 删掉旧的 TMDS 输出约束
    lines = [ln for ln in lines if "{p:tmds_" not in ln]

    # 2. 用官方例程的 LOC 覆盖 HDMI RX / I2C
    out = []
    for ln in lines:
        m = LOC_RE.match(ln.strip())
        if m and m.group(1) in TAKE_FROM_VENDOR:
            ln = ln.replace("{" + m.group(2) + "}", "{" + vend[m.group(1)] + "}")
        out.append(ln)
    lines = out

    # 3. 追加 200Pro+ 的并行 RGB 输出约束
    lines.append("")
    lines.append("# ===== MES2L676-200HP (盘古200Pro+): FPGA -> MS7210 并行 RGB =====")
    for sig in TX_SIGNALS:
        lines.extend(block(sig, vend[sig]))
    lines.append("")

    # 4. 自检: 引脚不能重复
    final = read_map_text("\n".join(lines))
    dup = {}
    for sig, loc in final.items():
        dup.setdefault(loc, []).append(sig)
    bad = {k: v for k, v in dup.items() if len(v) > 1}
    if bad:
        for loc, sigs in sorted(bad.items()):
            print("引脚冲突 %s: %s" % (loc, ", ".join(sigs)), file=sys.stderr)
        sys.exit("存在重复引脚, 已中止")

    open(args.out, "w", encoding="utf-8", newline="\r\n").write("\n".join(lines))
    print("已写出 %s, 共 %d 个引脚约束" % (args.out, len(final)))


def read_map_text(text):
    pins = {}
    for line in text.split("\n"):
        m = LOC_RE.match(line.strip())
        if m:
            pins[m.group(1)] = m.group(2)
    return pins


if __name__ == "__main__":
    main()
