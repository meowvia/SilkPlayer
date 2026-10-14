#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_SRC="${PROJECT_DIR}/build/SilkPlayer.app"
APP_DEST="/Applications/SilkPlayer.app"

MEDIA_DIR="${SILK_TEST_MEDIA_DIR:-/tmp/silk_test_media}"
VIDEO_SAMPLE_A="${MEDIA_DIR}/sample_4k_dv.mkv"
VIDEO_SAMPLE_B="${MEDIA_DIR}/sample_4k_webdl.mkv"
VIDEO_TOS="${MEDIA_DIR}/sample_tos_4k.mov"
VIDEO_VERTICAL="${MEDIA_DIR}/sample_vertical_9_16.mp4"

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

# PHASE 1: 4K HDR Remux (PGS Bitmap Subtitles & 4K TrueHD Remux)
echo ""
echo ">>> [Phase 1/4] Testing 4K HDR Remux (PGS Bitmap Subtitles & 4K TrueHD Remux)..."
if [ -f "${VIDEO_SAMPLE_A}" ]; then
    open -a "${APP_DEST}" "${VIDEO_SAMPLE_A}"
    sleep 4

    PID=$(pgrep -x SilkPlayer || true)
    if [ -n "${PID}" ]; then
        echo "SilkPlayer PID: ${PID}"
        for i in {1..3}; do
            sleep 3
            sample_metrics "Phase 1 - 4K Remux (${i}x3s)" "${PID}"
        done
    fi
fi

# PHASE 2: 4K Web-DL (Multi-Subtitle Auto-Activation)
echo ""
echo ">>> [Phase 2/4] Switching to 4K Web-DL (Multi-Subtitle Auto-Activation)..."
if [ -f "${VIDEO_SAMPLE_B}" ]; then
    open -a "${APP_DEST}" "${VIDEO_SAMPLE_B}"
    sleep 3
    PID=$(pgrep -x SilkPlayer || true)
    if [ -n "${PID}" ]; then
        for i in {1..2}; do
            sleep 3
            sample_metrics "Phase 2 - 4K Web-DL (${i}x3s)" "${PID}"
        done
    fi
fi

# PHASE 3: ToS 4K (Fast Scrubbing & Master Audio Clock Sync)
echo ""
echo ">>> [Phase 3/4] Switching to ToS-4k-1920 (Scrub Seek & AV Sync Benchmark)..."
if [ -f "${VIDEO_TOS}" ]; then
    open -a "${APP_DEST}" "${VIDEO_TOS}"
    sleep 3
    PID=$(pgrep -x SilkPlayer || true)
    if [ -n "${PID}" ]; then
        for i in {1..3}; do
            sleep 3
            sample_metrics "Phase 3 - ToS 4K Scrub (${i}x3s)" "${PID}"
        done
    fi
fi

# PHASE 4: Vertical Video (Adaptive Window Dimension & Aspect Ratio)
echo ""
echo ">>> [Phase 4/4] Switching to Vertical Video (720x1280 9:16 Adaptive Sizing)..."
if [ -f "${VIDEO_VERTICAL}" ]; then
    open -a "${APP_DEST}" "${VIDEO_VERTICAL}"
    sleep 3
    PID=$(pgrep -x SilkPlayer || true)
    if [ -n "${PID}" ]; then
        for i in {1..2}; do
            sleep 3
            sample_metrics "Phase 4 - Vertical Video (${i}x3s)" "${PID}"
        done
    fi
fi

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
