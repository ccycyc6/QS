#!/usr/bin/env bash
# 依次跑 sim_pds 下所有非 CNN 主链路的 testbench
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIST="${*:-my_fifo pe_page box_overlay box_ram overlay_chain box_overlay_crop_buffer_manager post_cv3_conv2d adpter_conv2d ddr_video_delay_sync yolo crop_buffer_lprnet}"
FAILED=""
for t in $LIST; do
    echo "################ $t ################"
    if bash "$HERE/run_tb.sh" "$t"; then
        echo "$t: OK"
    else
        echo "$t: FAILED"
        FAILED="$FAILED $t"
    fi
done
echo "==================== summary ===================="
[ -n "$FAILED" ] && { echo "failed:$FAILED"; exit 1; }
echo "all testbenches finished"
