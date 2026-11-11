#!/usr/bin/env bash
# 用 Verilator 跑整条 LPRNet 链路（layer20..31 + CTC 后处理）
#
#   bash tools/sim/run_lprnet.sh                 # 默认会写中间层 hex
#   bash tools/sim/run_lprnet.sh +NO_CAPTURE_INTERMEDIATE +DRAIN_CYCLES=5000000
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SIM="$ROOT/sim_pds/sim_modelsim"

command -v verilator >/dev/null || { echo "找不到 verilator，请先安装（Ubuntu: sudo apt install verilator）"; exit 1; }

cd "$SIM"
mkdir -p mem_data sim_out
cp -f "$ROOT"/rtl_pds/data_process/mem_data/*.mem mem_data/

verilator --binary --timing -Wno-fatal -j "$(nproc)" \
    --top-module tb_lprnet \
    -I"$ROOT/rtl_pds" -I"$ROOT/rtl_pds/data_process/header" \
    "$ROOT"/rtl_pds/data_process/*.sv "$ROOT/rtl_pds/top_lprnet.sv" "$ROOT/sim_pds/tb_lprnet.sv" \
    --Mdir obj_lprnet -o sim_lprnet

echo "---- running full LPRNet ----"
# TB 结尾是 $stop，Verilator 会以非 0 退出码结束，这是预期行为
"./obj_lprnet/sim_lprnet" "$@" || true
