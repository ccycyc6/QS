#!/usr/bin/env bash
# ScreenSense - one-shot setup on the physical Ubuntu machine.
#   bash setup.sh            CPU build
#   bash setup.sh --cuda     CUDA build (needs an NVIDIA driver + toolkit)
set -e
cd "$(dirname "$0")"

USE_CUDA=0
[ "$1" = "--cuda" ] && USE_CUDA=1

if [ ! -d .venv ]; then
    python3 -m venv .venv
fi
. .venv/bin/activate
python3 -m pip install --upgrade pip >/dev/null

# torch first: the CPU/CUDA split decides the wheel index
if [ "$USE_CUDA" -eq 1 ]; then
    python3 -m pip install torch --index-url https://download.pytorch.org/whl/cu124
else
    python3 -m pip install torch --index-url https://download.pytorch.org/whl/cpu
fi
python3 -m pip install -r requirements.txt

echo
echo "activate with:  source $(pwd)/.venv/bin/activate"
echo "then check:     bash doctor.sh"
