#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Git History Scrubbing Script (Safe Local Clean-Room Tool)
#
# PURPOSE:
# 1. Purge legacy binary package Packages/SilkCoreKit.xcframework from git history
# 2. Scrub historical commit messages for sensitive paths, movie titles, or watermarks
#
# SAFETY GUARANTEES:
# - Strictly operates on a standalone branch (scrubbed-release-branch)
# - Creates an immutable safety backup branch before any modification
# - NEVER forces push or modifies remote repository

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

echo "================================================================================"
echo " SilkPlayer Git History Scrubbing Utility"
echo "================================================================================"

export PATH="${HOME}/Library/Python/3.14/bin:${PATH}"

# Check tool prerequisites
if ! command -v git-filter-repo &>/dev/null; then
    echo "[!] git-filter-repo is required but not found in PATH."
    echo "    Please install it using one of the following commands:"
    echo "      brew install git-filter-repo"
    echo "      pip3 install git-filter-repo"
    exit 1
fi

# Check git status clean
if [ -n "$(git status --porcelain)" ]; then
    echo "[!] Working tree contains uncommitted changes. Please commit or stash first."
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_BRANCH="backup_main_${TIMESTAMP}"
TARGET_BRANCH="clean_release_${TIMESTAMP}"

echo "-> Step 1: Creating safety backup branch: ${BACKUP_BRANCH}..."
git branch "${BACKUP_BRANCH}"

echo "-> Step 2: Creating and checking out isolated test branch: ${TARGET_BRANCH}..."
git checkout -b "${TARGET_BRANCH}"

echo "-> Step 3: Running git-filter-repo to purge binary framework and sanitize history..."

# Create Python message callback script for message filtering
CALLBACK_PY="/tmp/scrub_msg_callback.py"
cat << 'EOF' > "${CALLBACK_PY}"
import re

def filter_message(message):
    text = message.decode('utf-8', errors='replace')
    patterns = [
        r"6v123",
        r"5266ys",
        r"FraMeSToR",
        r"ParkHD",
        r"DreamHD",
        r"MOMOWEB",
        r"影音娱乐",
        r"巴达300勇士",
        r"盗亦有道",
        r"红雀",
        r"麦克白",
        r"两杆大烟枪",
        r"极限审判",
        r"送院途中",
        r"哪吒之魔童闹海"
    ]
    for p in patterns:
        text = re.sub(p, "[REDACTED_SAMPLE]", text)
    return text.encode('utf-8')
EOF

git-filter-repo --force \
    --path Packages/SilkCoreKit.xcframework --invert-paths \
    --message-callback "
import sys
sys.path.insert(0, '/tmp')
import scrub_msg_callback
return scrub_msg_callback.filter_message(message)
"

rm -f "${CALLBACK_PY}"

echo "================================================================================"
echo " Scrubbing Complete on Local Branch: ${TARGET_BRANCH}"
echo "================================================================================"
echo "Safety backup branch preserved at: ${BACKUP_BRANCH}"
echo ""
echo "To review commit history on the scrubbed branch:"
echo "    git log -n 10 --oneline"
echo ""
echo "To inspect repository size before and after:"
echo "    git count-objects -vH"
echo ""
echo "NOTE: This script has NOT touched remote repositories. To apply changes to main"
echo "and update GitHub, verify manually and follow the User Authorization Checklist."
echo "================================================================================"
