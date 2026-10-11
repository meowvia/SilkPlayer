#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Build Cache Cleaner
# Helps manage disk space taken by Swift Package Manager and compiler intermediate artifacts.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

MODE="${1:---soft}"

echo "=================================================="
echo " SilkPlayer Build Cache Cleaner"
echo "=================================================="
echo "Project Directory: ${PROJECT_DIR}"
echo "Current Size:"
du -sh "${PROJECT_DIR}"

case "${MODE}" in
    --soft|--clean)
        echo ""
        echo "[1/2] Running swift package clean (removes compiler intermediates)..."
        swift package clean 2>/dev/null || rm -rf "${PROJECT_DIR}/.build/out"
        echo "[2/2] Done! Cloned packages preserved for fast subsequent compilation."
        ;;

    --all|--purge|--hard)
        echo ""
        echo "[1/2] Purging entire .build directory (frees all 6+ GB)..."
        rm -rf "${PROJECT_DIR}/.build"
        echo "[2/2] Purging build staging directory..."
        rm -rf "${PROJECT_DIR}/build/dmg_staging"
        echo "Done! Full source tree restored to pristine ~5MB footprint."
        echo "Note: Next 'swift build' will re-fetch SPM checkouts."
        ;;

    --help|-h)
        echo ""
        echo "Usage: $0 [--clean | --purge | --help]"
        echo "  --clean (default): Free ~2.5GB by removing compiler intermediates while preserving cloned repos."
        echo "  --purge:           Free ~6.2GB by completely wiping all SPM caches and build outputs."
        exit 0
        ;;

    *)
        echo "Unknown option: ${MODE}"
        echo "Use --clean or --purge"
        exit 1
        ;;
esac

echo ""
echo "New Size:"
du -sh "${PROJECT_DIR}"
echo "=================================================="
