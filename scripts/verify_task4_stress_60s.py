#!/usr/bin/env python3
"""
SilkPlayer Task 4: 60-Second Real-Device 4K 60s MKV Playback VMMAP & Footprint Stress Test
Target Video: 25.8GB 4K HEVC 《哪吒之魔童闹海》 (3840x1608, 25,828,456,428 bytes)
Test Targets:
1. Verify IOAccelerator (graphics) memory <= 150MB (down from ~350MB baseline)
2. Verify phys_footprint stably bounded in 300MB ~ 450MB
3. Verify driver mapping handles / region counts are leak-free (no piling up)
"""

import os
import sys
import time
import subprocess
import re
from datetime import datetime

VIDEO_PATH = "/Volumes/HDD2T/影音娱乐/电影/哪吒之魔童闹海.mkv"
APP_BINARY = "/Volumes/2T/SilkPlayer/build/SilkPlayer.app/Contents/MacOS/SilkPlayer"
TOTAL_DURATION = 60  # seconds

def to_mb(val_str, unit):
    val = float(val_str)
    if unit == 'K': return val / 1024.0
    if unit == 'M': return val
    if unit == 'G': return val * 1024.0
    if unit == 'B' or not unit: return val / (1024.0 * 1024.0)
    return val

def parse_size_str(s):
    if not s or s == '0' or s == '0K':
        return 0.0
    unit = s[-1]
    if unit in ('K', 'M', 'G'):
        return to_mb(s[:-1], unit)
    try:
        return float(s) / (1024.0 * 1024.0)
    except ValueError:
        return 0.0

def kill_existing():
    try:
        out = subprocess.check_output(['pgrep', '-f', 'SilkPlayer.app/Contents/MacOS/SilkPlayer']).decode().strip()
        for p in out.splitlines():
            if p.strip():
                try:
                    os.kill(int(p), 9)
                except Exception:
                    pass
    except Exception:
        pass
    time.sleep(1)

def run_stress_test():
    if not os.path.exists(VIDEO_PATH):
        print(f"Error: Video file not found at {VIDEO_PATH}")
        sys.exit(1)
    if not os.path.exists(APP_BINARY):
        print(f"Error: App binary not found at {APP_BINARY}")
        sys.exit(1)

    video_size_gb = os.path.getsize(VIDEO_PATH) / (1000 * 1000 * 1000)
    print("=" * 80)
    print(" SILKPLAYER PHASE II · TASK 4: 60-SECOND STRESS & VMMAP VERIFICATION")
    print(f" Test Video:      {os.path.basename(VIDEO_PATH)} ({video_size_gb:.2f} GB / {os.path.getsize(VIDEO_PATH)} bytes)")
    print(f" Target Duration: {TOTAL_DURATION} seconds")
    print(f" App Binary:      {APP_BINARY}")
    print("=" * 80)

    kill_existing()

    # Prepend environment for CommandLineTools
    env = os.environ.copy()
    env["DEVELOPER_DIR"] = "/Library/Developer/CommandLineTools"

    proc = subprocess.Popen([APP_BINARY, VIDEO_PATH], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pid = proc.pid
    print(f"[*] SilkPlayer launched with PID: {pid}")
    print("[*] Warming up pipeline for 4.0s...")
    time.sleep(4.0)

    samples = []
    start_time = time.time()
    last_sample_time = 0
    raw_vmmap_30s = ""
    raw_vmmap_60s = ""
    raw_footprint_30s = ""
    raw_footprint_60s = ""

    header_fmt = "  {:<7} | {:<14} | {:<12} | {:<14} | {:<13} | {:<8} | {:<8}"
    print("\n" + header_fmt.format("Time", "Footprint (Peak)", "RSS", "IOAccel (Dirty)", "IOSurface", "Handles", "CPU"))
    print("  " + "-" * 78)

    while True:
        now = time.time()
        elapsed = now - start_time
        if elapsed > TOTAL_DURATION:
            break

        if now - last_sample_time >= 3.0:
            last_sample_time = now
            sample = {
                "elapsed": round(elapsed, 1),
                "rss_mb": 0.0,
                "cpu_pct": 0.0,
                "footprint_mb": 0.0,
                "peak_footprint_mb": 0.0,
                "ioaccel_res_mb": 0.0,
                "ioaccel_dirty_mb": 0.0,
                "ioaccel_count": 0,
                "iosurface_res_mb": 0.0,
                "iosurface_dirty_mb": 0.0,
                "iosurface_count": 0,
                "total_dirty_mb": 0.0,
            }

            # PS
            try:
                ps_out = subprocess.check_output(['ps', '-o', 'rss=,%cpu=', '-p', str(pid)]).decode().strip()
                parts = ps_out.split()
                if len(parts) >= 2:
                    sample["rss_mb"] = float(parts[0]) / 1024.0
                    sample["cpu_pct"] = float(parts[1])
            except Exception:
                pass

            # VMMAP
            try:
                vm_out = subprocess.check_output(['vmmap', '-summary', str(pid)], env=env, stderr=subprocess.DEVNULL, timeout=10).decode()
                
                fp_m = re.search(r'Physical footprint:\s+([\d\.]+)([KMGT]?)', vm_out)
                if fp_m:
                    sample["footprint_mb"] = to_mb(fp_m.group(1), fp_m.group(2))

                pfp_m = re.search(r'Physical footprint \(peak\):\s+([\d\.]+)([KMGT]?)', vm_out)
                if pfp_m:
                    sample["peak_footprint_mb"] = to_mb(pfp_m.group(1), pfp_m.group(2))

                def parse_region(pat):
                    m = re.search(rf'^{pat}\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)', vm_out, re.MULTILINE)
                    if m:
                        return parse_size_str(m.group(2)), parse_size_str(m.group(3)), int(m.group(8))
                    return 0.0, 0.0, 0

                sample["iosurface_res_mb"], sample["iosurface_dirty_mb"], sample["iosurface_count"] = parse_region('IOSurface')
                sample["ioaccel_res_mb"], sample["ioaccel_dirty_mb"], sample["ioaccel_count"] = parse_region(r'IOAccelerator \(graphics\)')

                tot_m = re.search(r'^TOTAL\s+(\S+)\s+(\S+)\s+(\S+)', vm_out, re.MULTILINE)
                if tot_m:
                    sample["total_dirty_mb"] = parse_size_str(tot_m.group(3))

                if 28 <= elapsed <= 34 and not raw_vmmap_30s:
                    raw_vmmap_30s = vm_out
                if elapsed >= 56 and not raw_vmmap_60s:
                    raw_vmmap_60s = vm_out
            except Exception as e:
                sample["error"] = str(e)

            # Footprint snapshot at ~30s and ~58s
            if 28 <= elapsed <= 34 and not raw_footprint_30s:
                try:
                    raw_footprint_30s = subprocess.check_output(['footprint', '-p', str(pid)], env=env, stderr=subprocess.DEVNULL, timeout=10).decode()
                except Exception:
                    pass
            if elapsed >= 56 and not raw_footprint_60s:
                try:
                    raw_footprint_60s = subprocess.check_output(['footprint', '-p', str(pid)], env=env, stderr=subprocess.DEVNULL, timeout=10).decode()
                except Exception:
                    pass

            samples.append(sample)
            print(f"  T+{sample['elapsed']:4.1f}s | {sample['footprint_mb']:5.1f}M ({sample['peak_footprint_mb']:5.1f}M) | {sample['rss_mb']:5.1f} MB   | {sample['ioaccel_res_mb']:5.1f}M ({sample['ioaccel_dirty_mb']:4.1f}M) | {sample['iosurface_res_mb']:5.1f}M ({sample['iosurface_dirty_mb']:4.1f}M) | {sample['ioaccel_count']:>3} accel | {sample['cpu_pct']:4.1f}%")

        time.sleep(0.5)

    print("\n[*] Terminating player process...")
    proc.terminate()
    try:
        proc.wait(timeout=3)
    except Exception:
        proc.kill()
    time.sleep(1)

    return samples, raw_vmmap_30s, raw_vmmap_60s, raw_footprint_30s, raw_footprint_60s

if __name__ == '__main__':
    samples, vm30, vm60, fp30, fp60 = run_stress_test()
    with open('/tmp/silkplayer_stress_samples.json', 'w') as f:
        import json
        json.dump(samples, f, indent=2)
    with open('/tmp/silkplayer_vmmap_30s.txt', 'w') as f:
        f.write(vm30)
    with open('/tmp/silkplayer_vmmap_60s.txt', 'w') as f:
        f.write(vm60)
    with open('/tmp/silkplayer_footprint_30s.txt', 'w') as f:
        f.write(fp30)
    with open('/tmp/silkplayer_footprint_60s.txt', 'w') as f:
        f.write(fp60)
    print("[*] All stress test logs dumped to /tmp/silkplayer_*")
