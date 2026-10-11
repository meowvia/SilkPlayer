#!/bin/bash
set -e

APP_PATH="/Applications/SilkPlayer.app"
TEST_DIR="${HOME}/Desktop/test"
VIDEO_TOS="${TEST_DIR}/ToS-4k-1920.mov"
VIDEO_JELLY="${TEST_DIR}/jellyfish-120-mbps-4k-uhd-hevc-10bit.mkv"
VIDEO_DOVI="${TEST_DIR}/Mystery Box Dolby Vision Profile 5.mp4"

echo "=================================================="
echo " SilkPlayer Real-World Memory & CPU Stress Benchmark"
echo "=================================================="

# 确保旧进程彻底终止
killall SilkPlayer 2>/dev/null || true
sleep 1

# 启动并打开视频 1 (ToS-4k)
echo ">>> [Phase 1/5] Launching SilkPlayer with ToS-4k-1920.mov..."
open -a "${APP_PATH}" "${VIDEO_TOS}"

sleep 5

PID=$(pgrep -x SilkPlayer || true)
if [ -z "$PID" ]; then
    echo "Error: SilkPlayer failed to launch."
    exit 1
fi
echo "SilkPlayer PID: $PID"

echo "--- Phase 1 Metric (ToS-4k-1920.mov playing 5s) ---"
ps -o pid,%cpu,rss,vsz -p "$PID"
vmmap --summary "$PID" 2>/dev/null | grep -E "Physical footprint|TOTAL|DefaultMallocZone" || true

# 切换到视频 2 (Jellyfish 120M 4K 10bit)
echo ""
echo ">>> [Phase 2/5] Switching to jellyfish-120-mbps-4k-uhd-hevc-10bit.mkv..."
open -a "${APP_PATH}" "${VIDEO_JELLY}"
sleep 5

echo "--- Phase 2 Metric (Jellyfish 120M playing 5s) ---"
ps -o pid,%cpu,rss,vsz -p "$PID"
vmmap --summary "$PID" 2>/dev/null | grep -E "Physical footprint|TOTAL|DefaultMallocZone" || true

# 切换到视频 3 (Mystery Box Dolby Vision Profile 5)
echo ""
echo ">>> [Phase 3/5] Switching to Mystery Box Dolby Vision Profile 5.mp4..."
open -a "${APP_PATH}" "${VIDEO_DOVI}"
sleep 5

echo "--- Phase 3 Metric (Dolby Vision Profile 5 playing 5s) ---"
ps -o pid,%cpu,rss,vsz -p "$PID"
vmmap --summary "$PID" 2>/dev/null | grep -E "Physical footprint|TOTAL|DefaultMallocZone" || true

# 切换回视频 1 (多次切播防反弹防泄漏验证)
echo ""
echo ">>> [Phase 4/5] Switching back to ToS-4k-1920.mov (Re-entry & No-Leak Verification)..."
open -a "${APP_PATH}" "${VIDEO_TOS}"
sleep 5

echo "--- Phase 4 Metric (ToS-4k Re-entry playing 5s) ---"
ps -o pid,%cpu,rss,vsz -p "$PID"
vmmap --summary "$PID" 2>/dev/null | grep -E "Physical footprint|TOTAL|DefaultMallocZone" || true

# 清理退出
echo ""
echo ">>> [Phase 5/5] Terminating SilkPlayer..."
killall SilkPlayer 2>/dev/null || true
sleep 1

echo "=================================================="
echo " Stress Benchmark Run Completed Successfully!"
echo "=================================================="
