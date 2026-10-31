#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Dev Test Deployment Script
# 1. Assembles and signs SilkPlayer.app (bypasses DMG creation)
# 2. Cleans system installed app and environment
# 3. Installs new .app to /Applications
# 4. Launches SilkPlayer for interactive testing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARCH="${1:-$(uname -m)}"
VERSION="${2:-1.5.0-dev}"

echo "=================================================="
echo " Deploying SilkPlayer Dev Build (${ARCH}) for User Testing"
echo "=================================================="

# 1. Compile and assemble .app (skip DMG)
"${SCRIPT_DIR}/package_app.sh" "${VERSION}" "${ARCH}" --app-only

# 2. Completely clean test environment & stale installations
"${SCRIPT_DIR}/clean_installed_app.sh"

# 3. Install new application bundle to /Applications
"${SCRIPT_DIR}/install_to_applications.sh"

# 4. Launch newly deployed version
echo "-> Launching /Applications/SilkPlayer.app for user testing..."
open /Applications/SilkPlayer.app

echo "=================================================="
echo " Dev build deployed and launched successfully!"
echo "=================================================="
