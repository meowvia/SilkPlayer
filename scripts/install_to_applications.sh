#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_NAME="SilkPlayer"
SRC_APP="${PROJECT_DIR}/build/${APP_NAME}.app"
DEST_APP="/Applications/${APP_NAME}.app"

if [[ ! -d "${SRC_APP}" ]]; then
    echo "Error: ${SRC_APP} not found. Build or package first." >&2
    exit 1
fi

echo "Installing ${APP_NAME} to /Applications..."
pkill -x "${APP_NAME}" 2>/dev/null || true
rm -rf "${DEST_APP}"
cp -R "${SRC_APP}" "/Applications/"
rm -rf "${SRC_APP}"
xattr -cr "${DEST_APP}"

# Unregister staging build path and register only /Applications/SilkPlayer.app
LSREG="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"${LSREG}" -u "${SRC_APP}" 2>/dev/null || true
"${LSREG}" -gc >/dev/null 2>&1 || true
"${LSREG}" -f -r "${DEST_APP}"
touch "${DEST_APP}"
killall Dock 2>/dev/null || true

echo "Installed successfully! Dock and LaunchServices refreshed."
