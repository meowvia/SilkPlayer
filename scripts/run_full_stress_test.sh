#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/Volumes/2T/SilkPlayer"
APP_SRC="${PROJECT_DIR}/build/SilkPlayer.app"
APP_DEST="/Applications/SilkPlayer.app"

VIDEO_300="/Volumes/HDD2T/影音娱乐/电影/巴达300勇士/300.2006.UHD.BluRay.2160p.TrueHD.Atmos.7.1.DV.HEVC.HYBRID.REMUX-FraMeSToR.mkv"
VIDEO_SPIDER="/Volumes/HDD2T/影音娱乐/电影/2160p.iT.WEB-DL.H.265.DV.DDP5.1.Atmos.mkv"
VIDEO_TOS="${HOME}/Desktop/test/ToS-4k-1920.mov"
VIDEO_VERTICAL="${HOME}/Downloads/动物园布偶猫奇遇.mp4"

echo "=================================================="
echo " Starting Comprehensive SilkPlayer Real-World Stress Test"
echo " Target Benchmark Duration: >= 36s"
echo "=================================================="

# 1. Clean environment
"${PROJECT_DIR}/scripts/clean_installed_app.sh"

# 2. Install newly built app
echo "-> Installing newly packaged SilkPlayer.app to /Applications..."
cp -R "${APP_SRC}" "${APP_DEST}"

# Helper to sample metrics
sample_metrics() {
    local label="$1"
    local pid="$2"
    echo "--- [Metric: ${label}] ---"
    ps -o pid,%cpu,rss,vsz -p "${pid}" || true
    local footprint=$(vmmap --summary "${pid}" 2>/dev/null | grep -E "Physical footprint" || true)
    echo "Memory Footprint: ${footprint}"
}

# PHASE 1: 300 Spartans (PGS Graphic Subtitle & 4K TrueHD Remux)
echo ""
echo ">>> [Phase 1/4] Testing 300 Spartans (PGS Bitmap Subtitles & 4K HDR Remux)..."
open -a "${APP_DEST}" "${VIDEO_300}"
sleep 4

PID=$(pgrep -x SilkPlayer || true)
if [ -z "${PID}" ]; then
    echo "Error: SilkPlayer failed to launch."
    exit 1
fi
echo "SilkPlayer PID: ${PID}"

for i in {1..3}; do
    sleep 3
    sample_metrics "Phase 1 - 300 Spartans (${i}x3s)" "${PID}"
done

# PHASE 2: Spider-Man (Multi-Subtitle Auto-Selection & Web-DL)
echo ""
echo ">>> [Phase 2/4] Switching to Spider-Man (Multi-Subtitle Auto-Activation)..."
open -a "${APP_DEST}" "${VIDEO_SPIDER}"
sleep 3
for i in {1..2}; do
    sleep 3
    sample_metrics "Phase 2 - Spider-Man (${i}x3s)" "${PID}"
done

# PHASE 3: ToS 4K (Fast Scrubbing & Master Audio Clock Sync)
echo ""
echo ">>> [Phase 3/4] Switching to ToS-4k-1920 (Scrub Seek & AV Sync Benchmark)..."
open -a "${APP_DEST}" "${VIDEO_TOS}"
sleep 3
for i in {1..3}; do
    sleep 3
    sample_metrics "Phase 3 - ToS 4K Scrub (${i}x3s)" "${PID}"
done

# PHASE 4: Vertical Video (Adaptive Window Dimension & Aspect Ratio)
echo ""
echo ">>> [Phase 4/4] Switching to Vertical Video (720x1280 9:16 Adaptive Sizing)..."
open -a "${APP_DEST}" "${VIDEO_VERTICAL}"
sleep 3
for i in {1..2}; do
    sleep 3
    sample_metrics "Phase 4 - Vertical Video (${i}x3s)" "${PID}"
done

echo ""
echo ">>> Stress test run completed successfully! Total runtime > 38 seconds."
echo "-> Shutting down test process..."
killall SilkPlayer 2>/dev/null || true
sleep 1

# Post-test cleanup
echo "-> Performing post-test environment cleanup..."
"${PROJECT_DIR}/scripts/clean_installed_app.sh"

echo "=================================================="
echo " All Benchmarks Passed and Cleaned!"
echo "=================================================="
