#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Automated Test Suite Runner
# Target: macOS 14.0+, Apple Silicon arm64

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "=================================================="
echo " SilkPlayer Automated Test Suite Runner"
echo "=================================================="

TEST_BIN="/tmp/silk_test_runner"

SDK_PATH="$(xcrun --show-sdk-path)"

swiftc -parse-as-library -sdk "${SDK_PATH}" \
    Tests/SilkPlayerTests/PlaylistTests.swift \
    Sources/SilkPlayer/Shared/L10n.swift \
    Sources/SilkPlayer/Shared/SilkLanguageHelper.swift \
    Sources/SilkPlayer/Shared/SilkMediaFormatHelper.swift \
    Sources/SilkPlayer/Shared/SilkAnimation.swift \
    Sources/SilkPlayer/Shared/VisualEffectView.swift \
    Sources/SilkPlayer/Shared/SilkBrandLogoView.swift \
    Sources/SilkPlayer/Shared/VideoTransform.swift \
    Sources/SilkPlayer/PlayerModels.swift \
    Sources/SilkPlayer/Playlist/MediaItem.swift \
    Sources/SilkPlayer/Playlist/PlaylistModels.swift \
    Sources/SilkPlayer/Playlist/PlaylistManager.swift \
    Sources/SilkPlayer/Settings/AppSettings.swift \
    Sources/SilkPlayer/Settings/SilkSettingsView.swift \
    Sources/SilkPlayer/App/AppNavigationModel.swift \
    Sources/SilkPlayer/App/PlayerWindowManager.swift \
    Sources/SilkPlayer/App/ShortcutsCheatsheetView.swift \
    -framework QuickLookThumbnailing -framework AVFoundation -framework CoreMedia -framework AppKit \
    -framework VideoToolbox -framework CoreVideo -framework AudioToolbox \
    -o "${TEST_BIN}"

"${TEST_BIN}"
rm -f "${TEST_BIN}"
echo "=================================================="
echo " All tests executed successfully!"
echo "=================================================="
