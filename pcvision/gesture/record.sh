#!/usr/bin/env bash
# Record a gesture dataset from the webcam.
#
#   bash pcvision/gesture/record.sh              # guided: one key per class
#   bash pcvision/gesture/record.sh --manual     # freeform Space-to-save
#
# Any further flags go to capture_gestures.py (--camera, --names, --seconds...).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/env.sh"

if [ "${1:-}" = "--manual" ]; then
  shift
  exec "$QS_GESTURE_HOME/env/bin/python" "$HERE/capture_gestures.py" "$@"
fi
exec "$QS_GESTURE_HOME/env/bin/python" "$HERE/capture_gestures.py" --guided "$@"
