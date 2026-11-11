#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""检查 .fdc 引脚约束与顶层端口是否一一对应。"""
import argparse
import re
import sys

LOC_RE = re.compile(r"^define_attribute\s+\{p:([^}]+)\}\s+\{PAP_IO_LOC\}\s+\{([^}]*)\}\s*$")
PORT_RE = re.compile(r"^\s*(input|output|inout)\s+(?:wire\s+|reg\s+)?(?:\[([^\]]+)\]\s*)?([A-Za-z_]\w*)")


def fdc_pins(path):
    pins = {}
    for line in open(path, encoding="utf-8", errors="ignore"):
        m = LOC_RE.match(line.strip())
        if m:
            pins[m.group(1)] = m.group(2)
    return pins


def top_ports(path):
    ports = set()
    started = False
    for line in open(path, encoding="utf-8", errors="ignore"):
        if re.match(r"^\s*module\s+hdmi_loop\b", line):
            started = True
            continue
        if not started:
            continue
        if re.match(r"^\s*\)\s*;", line):
            break
        m = PORT_RE.match(line)
        if not m:
            continue
        rng, name = m.group(2), m.group(3)
        if rng and ":" in rng:
            hi, lo = [p.strip() for p in rng.split(":")]
            hi = int(hi, 0)
            lo = int(lo, 0)
            for i in range(lo, hi + 1):
                ports.add("%s[%d]" % (name, i))
        else:
            ports.add(name)
    return ports


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fdc", required=True)
    ap.add_argument("--top", required=True)
    args = ap.parse_args()

    pins = fdc_pins(args.fdc)
    ports = top_ports(args.top)

    no_pin = sorted(ports - set(pins))
    extra = sorted(set(pins) - ports)
    dup = {}
    for sig, loc in pins.items():
        dup.setdefault(loc, []).append(sig)
    conflict = {k: v for k, v in dup.items() if len(v) > 1}

    print("顶层端口 %d 个, .fdc 引脚 %d 个" % (len(ports), len(pins)))
    if no_pin:
        print("[缺少约束] " + ", ".join(no_pin))
    if extra:
        print("[多余约束] " + ", ".join(extra))
    for loc, sigs in sorted(conflict.items()):
        print("[引脚冲突] %s: %s" % (loc, ", ".join(sigs)))
    if not no_pin and not extra and not conflict:
        print("引脚检查通过")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
