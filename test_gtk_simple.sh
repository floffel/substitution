#!/bin/bash
set -e
export DISPLAY=:99
export GDK_SCALE=1
Xvfb :99 -screen 0 1280x720x24 -ac 2>&1 | head -5 &
XVFB_PID=$!
sleep 3
echo "=== Display Info ==="
xdpyinfo | head -5
echo "=== Testing GTK ==="
gtk-launch --help || true
echo "=== Display ready for Flutter tests ==="
kill $XVFB_PID 2>/dev/null || true
