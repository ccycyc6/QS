#!/usr/bin/env bash
# 用 Verilator 跑 sim_pds 下的其它 testbench（不需要 ModelSim）
#
#   bash tools/sim/run_tb.sh my_fifo
#   bash tools/sim/run_tb.sh yolo
set -uo pipefail

TB="${1:?usage: run_tb.sh <tb-name>}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SIM="$ROOT/sim_pds/sim_modelsim"
RTL="$ROOT/rtl_pds"
DP="$RTL/data_process"
INC=(-I"$DP/header" -I"$RTL")

cd "$SIM"
mkdir -p mem_data sim_out
cp -f "$DP"/mem_data/*.mem mem_data/
cp -f "$DP"/mem_data/*.mem . 2>/dev/null || true

SRC=()
case "$TB" in
  my_fifo)
    SRC=("$RTL/my_fifo.sv" "$ROOT/sim_pds/tb_my_fifo.sv") ;;
  pe_page)
    SRC=("$DP/pe.sv" "$DP/pe_col.sv" "$DP/d_manager.sv" "$DP/w_manager.sv" "$DP/pe_page.sv" "$ROOT/sim_pds/tb_pe_page.sv") ;;
  box_overlay)
    SRC=("$RTL"/overlay/*.sv "$RTL/my_fifo.sv" "$ROOT/sim_pds/tb_box_overlay.sv") ;;
  box_ram)
    SRC=("$RTL"/overlay/*.sv "$RTL"/my_fifo.sv "$ROOT/sim_pds/tb_box_ram.sv") ;;
  overlay_chain)
    SRC=("$RTL"/overlay/*.sv "$RTL/my_fifo.sv" "$ROOT/sim_pds/tb_overlay_chain.sv") ;;
  box_overlay_crop_buffer_manager)
    SRC=("$RTL"/overlay/*.sv "$RTL/my_fifo.sv" "$ROOT/sim_pds/tb_box_overlay_crop_buffer_manager.sv") ;;
  post_cv3_conv2d)
    SRC=("$DP"/*.sv "$ROOT/sim_pds/tb_post_cv3_conv2d.sv") ;;
  adpter_conv2d)
    SRC=("$DP"/*.sv "$RTL/layer_data_adapter.sv" "$RTL/my_fifo.sv" "$ROOT/sim_pds/tb_usb_to_pe_adapter_conv2d.sv") ;;
  ddr_video_delay_sync)
    SRC=("$ROOT/sim_pds/ddr3_test_axi_model.sv" "$RTL/ddr/wr_cmd_trans.v" "$RTL/ddr/wr_ctrl.v" \
         "$RTL/ddr/rd_ctrl.v" "$RTL/ddr/wr_rd_ctrl_top.v" "$RTL/ddr/ddr_wr_line_ram.sv" \
         "$RTL/ddr/ddr_rd_line_ram.sv" "$RTL/ddr/ddr_video_delay_sync.sv" \
         "$ROOT/sim_pds/tb_ddr_video_delay_sync.sv") ;;
  yolo)
    SRC=("$DP"/*.sv "$RTL/top_yolo.sv" "$ROOT/sim_pds/tb_yolo.sv") ;;
  crop_buffer_lprnet)
    SRC=("$DP"/*.sv "$RTL/my_fifo.sv" "$RTL/overlay/crop_buffer_manager.sv" "$RTL/top_lprnet.sv" \
         "$ROOT/sim_pds/tb_crop_buffer_lprnet.sv") ;;
  *)
    echo "unknown tb: $TB"; exit 2 ;;
esac

TOP="tb_${TB}"
# 目录名与 tb 名不完全一致的情况
case "$TB" in
  adpter_conv2d) TOP="tb_usb_to_pe_adapter_conv2d" ;;
  yolo)          TOP="tb_yolo" ;;
esac

OBJ="obj_tb_${TB}"
echo "==== build ${TOP} ===="
verilator --binary --timing -Wno-fatal -j "$(nproc)" --top-module "$TOP" "${INC[@]}" \
    "${SRC[@]}" --Mdir "$OBJ" -o "sim_${TB}" > "/tmp/tb_${TB}_build.log" 2>&1
grep -E '%Error' "/tmp/tb_${TB}_build.log" | head -8 || true
if [ ! -x "./${OBJ}/sim_${TB}" ]; then
    echo "BUILD FAILED: ${TB}"
    exit 1
fi

echo "==== run ${TOP} ===="
timeout "${TB_TIMEOUT:-300}" "./${OBJ}/sim_${TB}" > "/tmp/tb_${TB}_run.log" 2>&1
RC=$?
echo "run exit=$RC (124 = timeout)"
tail -20 "/tmp/tb_${TB}_run.log"
