#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Test Environment Clean Script
# Terminates running SilkPlayer instances and deletes all local installations and test caches.

APP_NAME="SilkPlayer"
BUNDLE_ID="com.silkplayer.SilkPlayer"

echo "=================================================="
echo " Cleaning SilkPlayer Test Environment"
echo "=================================================="

# 1. Kill any active instance
if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
    echo "-> Terminating active ${APP_NAME} process..."
    pkill -x "${APP_NAME}" || true
    sleep 0.5
fi

# 2. Unmount any active DMG volumes and detach virtual disk devices
for m in $(mount | awk '/\/Volumes\/SilkPlayer/{print $3}'); do
    echo "-> Ejecting mounted volume: ${m}..."
    hdiutil detach "${m}" -force -quiet 2>/dev/null || diskutil eject "${m}" 2>/dev/null || true
done

python3 -c '
import subprocess, re
try:
    out = subprocess.check_output(["hdiutil", "info"]).decode("utf-8", errors="ignore")
    for chunk in out.split("================================================"):
        if "SilkPlayer" in chunk:
            disks = re.findall(r"/dev/disk\d+", chunk)
            if disks:
                subprocess.run(["hdiutil", "detach", disks[0], "-force"], capture_output=True)
except Exception:
    pass
' 2>/dev/null || true

# 3. Remove installed app bundles
echo "-> Removing installed application bundles..."
rm -rf "/Applications/${APP_NAME}.app"
rm -rf "${HOME}/Applications/${APP_NAME}.app"

# 4. Unregister stale LaunchServices records
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "/Applications/${APP_NAME}.app" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "${HOME}/Applications/${APP_NAME}.app" 2>/dev/null || true

# 3. Clean application support and caches
echo "-> Cleaning application support, caches, and preferences..."
rm -rf "${HOME}/Library/Application Support/${APP_NAME}"
rm -rf "${HOME}/Library/Caches/${APP_NAME}"
rm -rf "${HOME}/Library/Saved Application State/${BUNDLE_ID}.savedState"
rm -rf "${HOME}/Library/Saved Application State/${APP_NAME}.savedState"
rm -f "${HOME}/Library/Preferences/${BUNDLE_ID}.plist"
rm -f "${HOME}/Library/Preferences/silk_test_runner.plist"

# 4. Flush cfprefsd defaults
defaults delete "${BUNDLE_ID}" 2>/dev/null || true

echo "=================================================="
echo " SilkPlayer test environment completely clean!"
echo "=================================================="
