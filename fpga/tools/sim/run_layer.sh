#!/usr/bin/env bash
# 用 Verilator 跑单层 LPRNet 仿真（不需要 ModelSim）
#
#   bash tools/sim/run_layer.sh 20
#
# 输出: sim_pds/sim_modelsim/sim_out/layer<N>_output.hex
# 比对: python python_script/compare_data_pds.py --layer <N>
set -euo pipefail

LAYER="${1:-20}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SIM="$ROOT/sim_pds/sim_modelsim"

command -v verilator >/dev/null || { echo "找不到 verilator，请先安装（Ubuntu: sudo apt install verilator）"; exit 1; }

cd "$SIM"
mkdir -p mem_data sim_out
cp -f "$ROOT"/rtl_pds/data_process/mem_data/*.mem mem_data/

# ModelSim 用 -gTARGET_LAYER 传参；Verilator 不能从命令行传参，这里生成一份改好默认值的副本
sed -e 's/module tb_layer #(/module tb_layer_iv #(/' \
    -e "s/parameter int TARGET_LAYER = 31/parameter int TARGET_LAYER = ${LAYER}/" \
    "$ROOT/sim_pds/tb_layer.sv" > "_iv_tb_layer_${LAYER}.sv"

verilator --binary --timing -Wno-fatal -j "$(nproc)" \
    --top-module tb_layer_iv \
    -I"$ROOT/rtl_pds/data_process/header" \
    "$ROOT"/rtl_pds/data_process/*.sv "_iv_tb_layer_${LAYER}.sv" \
    --Mdir "obj_layer${LAYER}" -o "sim_layer${LAYER}"

echo "---- running layer ${LAYER} ----"
# TB 结尾是 $stop，Verilator 会以非 0 退出码结束，这是预期行为
"./obj_layer${LAYER}/sim_layer${LAYER}" || true

OUT="$SIM/sim_out/layer${LAYER}_output.hex"
[ -s "$OUT" ] || { echo "没有生成 $OUT"; exit 1; }
echo "---- done: $OUT ----"
