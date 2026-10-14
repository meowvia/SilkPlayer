#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Automated Test Suite Runner (SwiftPM Standard)
# Target: macOS 14.0+, Apple Silicon arm64

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "=================================================="
echo " SilkPlayer Automated Test Suite Runner"
echo "=================================================="

if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    # CI Runner Environment: standard single-pass test
    swift test
else
    # Local Developer Pre-Flight: verify BOTH binary target & CI mock target
    echo "[1/2] Verifying Local Binary Framework Integration..."
    swift test

    echo "[2/2] Verifying Simulated CI Mock Integration (isolated scratch cache)..."
    GITHUB_ACTIONS=true swift test --scratch-path .build-ci
fi

echo "=================================================="
echo " All tests executed successfully!"
echo "=================================================="
