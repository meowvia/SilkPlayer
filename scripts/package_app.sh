#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Release Packaging Script
# Target: macOS 14.0+, Apple Silicon (arm64) / Intel (x86_64) / Universal (universal)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

APP_NAME="SilkPlayer"
VERSION="${1:-1.0.0}"
ARCH="${2:-arm64}"
BUILD_APP_ONLY=false

if [[ "${3:-}" == "--app-only" || "${3:-}" == "--no-dmg" ]]; then
    BUILD_APP_ONLY=true
fi

if [[ "${ARCH}" != "arm64" && "${ARCH}" != "x86_64" && "${ARCH}" != "universal" ]]; then
    echo "Error: Unsupported architecture '${ARCH}'. Supported: arm64, x86_64, universal." >&2
    exit 1
fi

BUILD_DIR="${PROJECT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-${ARCH}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
STAGING_DIR="${BUILD_DIR}/dmg_staging"

# Strict dynamic dependency allowlist auditor (Iron Rule 5)
# Every dynamic dependency must be @rpath-isolated or a standard Apple system framework
audit_bundle_dependencies() {
    local target_app="$1"
    local stage_name="$2"
    echo "  [Audit] Inspecting dynamic library linkages in ${stage_name}..."
    local violation_count=0

    while IFS= read -r bin; do
        if [[ -f "${bin}" && ! -L "${bin}" ]]; then
            local deps
            deps=$(otool -L "${bin}" 2>/dev/null | grep $'^\t' | awk '{print $1}')
            for dep in ${deps}; do
                # Allowed prefixes: @rpath/, /System/Library/, /usr/lib/
                if [[ "${dep}" == "@rpath/"* || "${dep}" == "/System/Library/"* || "${dep}" == "/usr/lib/"* ]]; then
                    continue
                fi
                echo "  [VIOLATION] Disallowed dynamic library path: '${dep}' in $(basename "${bin}")" >&2
                ((violation_count++))
            done
        fi
    done < <(find "${target_app}" -type f \( -perm +111 -o -name "*.dylib" \))

    if [[ ${violation_count} -gt 0 ]]; then
        echo "Fatal: Detected ${violation_count} non-rpath/host-leaked dynamic library dependencies in ${stage_name}!" >&2
        echo "Every non-system dynamic library MUST use @rpath/ and be embedded within the bundle." >&2
        return 1
    fi
    echo "  [Audit Passed] All dependencies strictly adhere to @rpath or system frameworks."
    return 0
}

if [[ "${BUILD_APP_ONLY}" == "true" ]]; then
    echo "=================================================="
    echo " Assembling ${APP_NAME}.app (${VERSION} - ${ARCH}) [DMG Skipped]"
    echo "=================================================="
else
    echo "=================================================="
    echo " Packaging ${APP_NAME} (${VERSION} - ${ARCH}) -> ${DMG_PATH}"
    echo "=================================================="
fi

# 1. Clean previous build staging and destination DMG
echo "[1/6] Cleaning previous build artifacts..."

if [[ "${BUILD_APP_ONLY}" != "true" && "${VERSION}" != *"-test"* && -f "${DMG_PATH}" ]]; then
    echo "Error: Release ${DMG_PATH} already exists! To prevent accidental overwrite of finalized versions, delete it manually or bump version." >&2
    exit 1
fi

rm -rf "${APP_BUNDLE}" "${STAGING_DIR}" "${DMG_PATH}" "${HOME}/Desktop/SilkPlayer-test.dmg"
mkdir -p "${BUILD_DIR}"

# 2. Release compilation
if [[ "${ARCH}" == "universal" ]]; then
    echo "[2/6] Compiling release binaries for universal (arm64 + x86_64)..."
    echo "  Compiling arm64 slice..."
    swift build -c release --triple "arm64-apple-macosx14.0"
    TEMP_DIR=$(mktemp -d /tmp/silkplayer_build_XXXXXX)
    cp "${PROJECT_DIR}/.build/release/${APP_NAME}" "${TEMP_DIR}/${APP_NAME}_arm64"

    echo "  Compiling x86_64 slice..."
    swift build -c release --triple "x86_64-apple-macosx14.0"
    cp "${PROJECT_DIR}/.build/release/${APP_NAME}" "${TEMP_DIR}/${APP_NAME}_x86_64"

    RELEASE_BIN="${BUILD_DIR}/${APP_NAME}_universal_bin"
    echo "  Merging slices into universal binary..."
    lipo -create "${TEMP_DIR}/${APP_NAME}_arm64" "${TEMP_DIR}/${APP_NAME}_x86_64" -output "${RELEASE_BIN}"
    rm -rf "${TEMP_DIR}"
else
    echo "[2/6] Compiling release binary for ${ARCH}..."
    swift build -c release --triple "${ARCH}-apple-macosx14.0"
    RELEASE_BIN="${PROJECT_DIR}/.build/release/${APP_NAME}"
fi

if [[ ! -f "${RELEASE_BIN}" ]]; then
    echo "Error: Release binary not found at ${RELEASE_BIN}" >&2
    exit 1
fi

BIN_ARCH=$(lipo -archs "${RELEASE_BIN}")
if [[ "${ARCH}" == "universal" ]]; then
    if [[ "${BIN_ARCH}" != *"arm64"* || "${BIN_ARCH}" != *"x86_64"* ]]; then
        echo "Error: Universal binary missing required architectures! Got: ${BIN_ARCH}" >&2
        exit 1
    fi
    echo "  Universal binary verified: ${BIN_ARCH}"
else
    if [[ "${BIN_ARCH}" != *"${ARCH}"* ]]; then
        echo "Error: Binary architecture mismatch! Expected ${ARCH}, got ${BIN_ARCH}" >&2
        exit 1
    fi
fi

# 3. Construct .app bundle layout
echo "[3/6] Assembling ${APP_NAME}.app bundle..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"

cp "${RELEASE_BIN}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if [[ "${ARCH}" == "universal" && -f "${RELEASE_BIN}" ]]; then
    rm -f "${RELEASE_BIN}"
fi

# Embed dynamic XCFrameworks into Contents/Frameworks
# Note: SilkCoreKit is statically linked into the main binary, so skip embedding it to avoid bloat
for xc in "${PROJECT_DIR}/Packages"/*.xcframework; do
    if [[ -d "${xc}" ]]; then
        for fw in "${xc}"/macos*/*.framework; do
            if [[ -d "${fw}" ]]; then
                fw_name="$(basename "${fw}")"
                if [[ "${fw_name}" == "SilkCoreKit.framework" ]]; then
                    echo "  Skipping static archive ${fw_name} (already statically linked into executable)..."
                    continue
                fi
                if [[ "${ARCH}" == "universal" ]]; then
                    echo "  Embedding ${fw_name} (universal fat binary)..."
                    cp -R "${fw}" "${APP_BUNDLE}/Contents/Frameworks/"
                else
                    echo "  Embedding ${fw_name} (thinning to ${ARCH})..."
                    cp -R "${fw}" "${APP_BUNDLE}/Contents/Frameworks/"
                    
                    fw_bin="${APP_BUNDLE}/Contents/Frameworks/${fw_name}/Versions/A/${fw_name%.framework}"
                    if [[ -f "${fw_bin}" ]]; then
                        if lipo -info "${fw_bin}" | grep -q "Architectures in the fat file"; then
                            lipo -thin "${ARCH}" "${fw_bin}" -output "${fw_bin}.thin"
                            mv "${fw_bin}.thin" "${fw_bin}"
                            chmod +x "${fw_bin}"
                        fi
                    fi
                fi
            fi
        done
    fi
done

# Ensure LC_RPATH points to @executable_path/../Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
install_name_tool -add_rpath "@loader_path/../Frameworks" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# Enforce zero absolute host paths assertion & strict @rpath isolation (Iron Rule 5)
audit_bundle_dependencies "${APP_BUNDLE}" "Staging .app Bundle"

cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
if [[ -f "${PROJECT_DIR}/Resources/AppIcon.icns" ]]; then
    cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
fi
for lproj in "${PROJECT_DIR}/Resources"/*.lproj; do
    if [[ -d "${lproj}" ]]; then
        cp -R "${lproj}" "${APP_BUNDLE}/Contents/Resources/"
    fi
done
if [[ -d "${PROJECT_DIR}/Resources/Turntable" ]]; then
    cp -R "${PROJECT_DIR}/Resources/Turntable" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy SwiftPM resource bundles if present
find "${PROJECT_DIR}/.build" -path "*/Release/*.bundle" -type d | while read -r b; do
    cp -R "${b}" "${APP_BUNDLE}/Contents/Resources/"
done

# Strip all extended attributes before codesigning to ensure clean LaunchServices & Gatekeeper indexing
xattr -cr "${APP_BUNDLE}"

# 4. Ad-hoc inside-out code signing
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

if [[ "${BUILD_APP_ONLY}" == "true" ]]; then
    echo "=================================================="
    echo " App bundle assembled and signed successfully (DMG creation bypassed)!"
    echo " App: ${APP_BUNDLE}"
    echo "=================================================="
    exit 0
fi

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
    echo "  DMG mounted successfully."
    echo "  Re-auditing dynamic dependencies inside mounted DMG..."
    audit_bundle_dependencies "${MOUNT_DIR}/${APP_NAME}.app" "Mounted DMG .app Bundle"
    echo "  Verifying inside-out codesign of mounted DMG .app..."
    codesign --verify --deep --strict "${MOUNT_DIR}/${APP_NAME}.app"
fi
hdiutil detach "${MOUNT_DIR}" -quiet
rm -rf "${MOUNT_DIR}"

DMG_SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

echo "=================================================="
echo " Packaged successfully!"
echo " App: ${APP_BUNDLE}"
echo " DMG: ${DMG_PATH}"
echo " DMG SHA-256: ${DMG_SHA256}"
echo " To verify against GitHub Releases:"
echo "   ./scripts/verify_release_asset.sh ${VERSION}"
echo "=================================================="

