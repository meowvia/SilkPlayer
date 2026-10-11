#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Release Packaging Script
# Target: macOS 14.0+, Apple Silicon arm64

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

APP_NAME="SilkPlayer"
VERSION="${1:-1.0.0}"
BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
STAGING_DIR="${BUILD_DIR}/dmg_staging"

echo "=================================================="
echo " Packaging ${APP_NAME} (${VERSION}) -> ${DMG_PATH}"
echo "=================================================="

# 1. Clean previous build staging, old test DMGs, and wipe old installed app version
echo "[1/5] Cleaning previous build artifacts and old installed test versions..."
if [[ -x "${SCRIPT_DIR}/clean_installed_app.sh" ]]; then
    "${SCRIPT_DIR}/clean_installed_app.sh"
fi
rm -rf "${APP_BUNDLE}" "${STAGING_DIR}" "${BUILD_DIR}"/SilkPlayer-*.dmg "${DMG_PATH}" "${HOME}/Desktop/SilkPlayer-test.dmg"
mkdir -p "${BUILD_DIR}"

# 2. Release compilation
echo "[2/5] Compiling release binary..."

swift build -c release

RELEASE_BIN="${PROJECT_DIR}/.build/release/${APP_NAME}"
if [[ ! -f "${RELEASE_BIN}" ]]; then
    echo "Error: Release binary not found at ${RELEASE_BIN}" >&2
    exit 1
fi

# 3. Construct .app bundle layout
echo "[3/6] Assembling ${APP_NAME}.app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

cp "${RELEASE_BIN}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Embed dynamic XCFrameworks into Contents/Frameworks
for xc in "${PROJECT_DIR}/Packages"/*.xcframework; do
    if [[ -d "${xc}" ]]; then
        for fw in "${xc}"/macos*/*.framework; do
            if [[ -d "${fw}" ]]; then
                echo "  Embedding $(basename "${fw}")..."
                cp -R "${fw}" "${APP_BUNDLE}/Contents/Frameworks/"
            fi
        done
    fi
done

# Ensure LC_RPATH points to @executable_path/../Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
install_name_tool -add_rpath "@loader_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [[ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
for lproj in "${PROJECT_DIR}/Resources"/*.lproj; do
    if [[ -d "${lproj}" ]]; then
        cp -R "${lproj}" "${APP_BUNDLE}/Contents/Resources/"
    fi
done

# Copy SwiftPM resource bundles if present
find "${PROJECT_DIR}/.build" -path "*/Release/*.bundle" -type d | while read -r b; do
    cp -R "${b}" "${APP_BUNDLE}/Contents/Resources/"
done

# 4. Ad-hoc inside-out code signing for Apple Silicon
echo "[4/6] Applying ad-hoc inside-out codesign with entitlements..."
for fw in "${APP_BUNDLE}/Contents/Frameworks"/*.framework; do
    if [[ -d "${fw}" ]]; then
        echo "  Signing framework: $(basename "${fw}")..."
        codesign --force --sign - --timestamp=none "${fw}"
    fi
done

codesign --force --sign - \
         --entitlements "${PROJECT_DIR}/Resources/SilkPlayer.entitlements" \
         --timestamp=none \
         "${APP_BUNDLE}"

echo "Codesign verification:"
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

# 5. Build DMG Installer
echo "[5/6] Constructing DMG installer..."
mkdir -p "${STAGING_DIR}"
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

hdiutil create -volname "${APP_NAME}" \
               -srcfolder "${STAGING_DIR}" \
               -ov \
               -format UDZO \
               "${DMG_PATH}"

rm -rf "${STAGING_DIR}"

# 6. Verify DMG & Ensure System Ready for Fresh Testing
echo "[6/6] Verifying DMG image..."
MOUNT_DIR=$(mktemp -d /tmp/silkplayer_mount_XXXXXX)
hdiutil attach "${DMG_PATH}" -mountpoint "${MOUNT_DIR}" -nobrowse -quiet
if [[ -d "${MOUNT_DIR}/${APP_NAME}.app" ]]; then
    echo "  DMG mounted successfully and contains ${APP_NAME}.app"
fi
hdiutil detach "${MOUNT_DIR}" -quiet
rm -rf "${MOUNT_DIR}"

# Guarantee test environment has no residual stale version
if [[ -x "${SCRIPT_DIR}/clean_installed_app.sh" ]]; then
    "${SCRIPT_DIR}/clean_installed_app.sh"
fi

echo "=================================================="
echo " Packaged successfully!"
echo " App: ${APP_BUNDLE}"
echo " DMG: ${DMG_PATH}"
echo " Environment: Completely clean & ready for fresh testing"
echo "=================================================="

