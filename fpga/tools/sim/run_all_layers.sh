#!/usr/bin/env bash
# 依次跑多个 LPRNet 层（默认 20..31），每层单独 build+run
#
#   bash tools/sim/run_all_layers.sh            # 20..31
#   bash tools/sim/run_all_layers.sh 25 28 31   # 指定层
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -gt 0 ]; then
    LAYERS="$*"
else
    LAYERS="20 21 22 23 24 25 26 27 28 29 30 31"
fi

FAILED=""
for L in $LAYERS; do
    echo "################ layer ${L} ################"
    if bash "$HERE/run_layer.sh" "$L" > "/tmp/layer_${L}.log" 2>&1; then
        echo "layer ${L}: simulation done"
    else
        echo "layer ${L}: FAILED (see /tmp/layer_${L}.log)"
        tail -5 "/tmp/layer_${L}.log"
        FAILED="$FAILED $L"
    fi
done

echo "==================== summary ===================="
if [ -n "$FAILED" ]; then
    echo "failed layers:$FAILED"
    exit 1
fi
echo "all layers finished"
