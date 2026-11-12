#!/usr/bin/env bash
# ScreenSense - environment check for the physical Ubuntu machine.
# Run this first: it tells you exactly what is missing before you train.
set +e

ok()   { printf '  [ok]   %s\n' "$1"; }
bad()  { printf '  [MISS] %s\n' "$1"; FAIL=1; }
warn() { printf '  [warn] %s\n' "$1"; }

FAIL=0

echo "== system =="
. /etc/os-release 2>/dev/null
ok "$PRETTY_NAME ($(uname -m))"

echo "== repo =="
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ok "repo at $REPO"
case "$REPO" in
  /mnt/*) warn "repo is on an NTFS mount: git may report bogus filemode changes (fix: git config core.filemode false)" ;;
esac
touch "$REPO/.write_test" 2>/dev/null && ok "repo writable" && rm -f "$REPO/.write_test" || bad "repo not writable"

echo "== python =="
python3 -V >/dev/null 2>&1 && ok "python3 $(python3 -V 2>&1 | cut -d' ' -f2)" || bad "python3 missing"
for m in numpy scipy cv2 torch; do
  python3 -c "import $m" 2>/dev/null && ok "$m" || bad "$m (run pcvision/setup.sh)"
done
python3 - <<'PY' 2>/dev/null
import torch
print('  [info] torch', torch.__version__, '| cuda available:', torch.cuda.is_available())
if torch.cuda.is_available():
    print('  [info] gpu:', torch.cuda.get_device_name(0))
PY

echo "== camera =="
CAMS=$(ls /dev/video* 2>/dev/null | wc -l)
if [ "$CAMS" -gt 0 ]; then
  ok "$CAMS video device(s): $(ls /dev/video* | tr '\n' ' ')"
  if id -nG "$USER" | grep -qw video; then ok "user in 'video' group"; else warn "user not in 'video' group (sudo usermod -aG video $USER, then re-login)"; fi
else
  bad "no /dev/video* - camera not visible"
fi

echo "== display =="
[ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ] && ok "graphical session ($DISPLAY $WAYLAND_DISPLAY)" || bad "no DISPLAY (capture needs a desktop session)"

echo
if [ "$FAIL" -eq 0 ]; then echo "READY"; else echo "NOT READY - fix the [MISS] items above"; fi
exit $FAIL
