#!/usr/bin/env bash
set -euo pipefail

# SilkPlayer Release Asset Verification Script
# Verifies local DMG SHA-256 hashes against GitHub Releases published digests.

REPO="meowvia/SilkPlayer"
TAG="${1:-1.5.0}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"

echo "=================================================="
echo " Verifying Release Assets for Tag: ${TAG}"
echo " Repository: ${REPO}"
echo "=================================================="

python3 - <<EOF
import json
import subprocess
import sys
import os
import urllib.request

repo = "${REPO}"
tag = "${TAG}"
url = f"https://api.github.com/repos/{repo}/releases/tags/{tag}"

req = urllib.request.Request(url, headers={"User-Agent": "SilkPlayer-Verifier"})
try:
    with urllib.request.urlopen(req) as resp:
        release_data = json.loads(resp.read().decode("utf-8"))
except Exception as e:
    print(f"Error fetching release data: {e}", file=sys.stderr)
    sys.exit(1)

assets = release_data.get("assets", [])
if not assets:
    print("No assets found in GitHub release.")
    sys.exit(1)

build_dir = "${BUILD_DIR}"
desktop_dir = os.path.expanduser("~/Desktop")

print(f"\n{'ASSET NAME':<35} | {'LOCAL SHA-256':<16} | {'REMOTE SHA-256':<16} | {'STATUS'}")
print("-" * 80)

has_error = False

for a in assets:
    name = a["name"]
    remote_digest = a.get("digest", "")
    if remote_digest.startswith("sha256:"):
        remote_sha = remote_digest.replace("sha256:", "")
    else:
        remote_sha = "N/A"

    # Search local matching DMG in build/ or ~/Desktop/
    local_path = None
    for candidate in [
        os.path.join(build_dir, name),
        os.path.join(desktop_dir, name),
        os.path.join(build_dir, name.replace("-fix", "")),
        os.path.join(desktop_dir, name.replace("-fix", ""))
    ]:
        if os.path.exists(candidate):
            local_path = candidate
            break

    if not local_path:
        local_sha = "FILE NOT FOUND"
        status = "MISSING LOCAL"
        has_error = True
    else:
        # Compute local sha256
        res = subprocess.run(["shasum", "-a", "256", local_path], capture_output=True, text=True)
        local_sha = res.stdout.split()[0] if res.returncode == 0 else "ERROR"

        if local_sha == remote_sha:
            status = "MATCH (OK)"
        else:
            status = "MISMATCH (FAIL)"
            has_error = True

    short_local = local_sha[:14] + ".." if len(local_sha) > 16 else local_sha
    short_remote = remote_sha[:14] + ".." if len(remote_sha) > 16 else remote_sha
    print(f"{name:<35} | {short_local:<16} | {short_remote:<16} | {status}")

print("-" * 80)

if has_error:
    print("Result: Verification FAILED! Remote and local assets do not match.")
    sys.exit(1)
else:
    print("Result: Verification PASSED! All GitHub release assets match local binaries.")
    sys.exit(0)
EOF
