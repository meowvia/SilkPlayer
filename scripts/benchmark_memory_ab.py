#!/usr/bin/env python3
"""
SilkPlayer Phase 4: 4K HEVC Playback Memory High-Usage A/B Isolation Benchmark
Target Video: 4K HEVC 《哪吒之魔童闹海》 (3840x1608, 24fps, 23.9Mbps, 24GB)
Test Environment: Mac mini M4, macOS 27.2
"""

import os
import sys
import time
import json
import shutil
import subprocess
import re
from pathlib import Path
from datetime import datetime

DEFAULT_VIDEO_PATH = "/Volumes/HDD2T/影音娱乐/电影/哪吒之魔童闹海.mkv"
MOVIES_DIR = "/Volumes/HDD2T/影音娱乐/电影"
APP_BUNDLE_PATH = "/Volumes/2T/SilkPlayer/build/SilkPlayer.app"
APP_SUPPORT_DIR = os.path.expanduser("~/Library/Application Support/SilkPlayer")
CACHES_DIR = os.path.expanduser("~/Library/Caches/SilkPlayer")
BACKUP_DIR = "/tmp/silkplayer_ab_backup"

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

def get_process_metrics(pid):
    metrics = {
        "timestamp": time.time(),
        "pid": pid,
        "rss_mb": 0.0,
        "footprint_mb": 0.0,
        "peak_footprint_mb": 0.0,
        "cpu_pct": 0.0,
        "iosurface_dirty_mb": 0.0,
        "iosurface_resident_mb": 0.0,
        "iosurface_count": 0,
        "ioaccel_dirty_mb": 0.0,
        "ioaccel_resident_mb": 0.0,
        "ioaccel_count": 0,
        "coremedia_mb": 0.0,
        "malloc_small_mb": 0.0,
        "malloc_large_mb": 0.0,
        "total_dirty_mb": 0.0,
        "avd_silk_sessions": 0,
        "avd_total_sessions": 0,
    }

    # 1. PS metrics (RSS & CPU)
    try:
        ps_out = subprocess.check_output(['ps', '-o', 'rss=,%cpu=', '-p', str(pid)]).decode().strip()
        parts = ps_out.split()
        if len(parts) >= 2:
            metrics["rss_mb"] = float(parts[0]) / 1024.0
            metrics["cpu_pct"] = float(parts[1])
    except Exception:
        pass

    # 2. VMMAP metrics
    try:
        vm_out = subprocess.check_output(['vmmap', '-summary', str(pid)], stderr=subprocess.DEVNULL, timeout=8).decode()
        
        fp_match = re.search(r'Physical footprint:\s+([\d\.]+)([KMGT]?)', vm_out)
        if fp_match:
            metrics["footprint_mb"] = to_mb(fp_match.group(1), fp_match.group(2))

        peak_match = re.search(r'Physical footprint \(peak\):\s+([\d\.]+)([KMGT]?)', vm_out)
        if peak_match:
            metrics["peak_footprint_mb"] = to_mb(peak_match.group(1), peak_match.group(2))

        def parse_region(pattern):
            m = re.search(rf'^{pattern}\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)', vm_out, re.MULTILINE)
            if m:
                return parse_size_str(m.group(2)), parse_size_str(m.group(3)), int(m.group(8))
            return 0.0, 0.0, 0

        r_res, r_dirty, r_count = parse_region('IOSurface')
        metrics["iosurface_resident_mb"] = r_res
        metrics["iosurface_dirty_mb"] = r_dirty
        metrics["iosurface_count"] = r_count

        a_res, a_dirty, a_count = parse_region(r'IOAccelerator \(graphics\)')
        metrics["ioaccel_resident_mb"] = a_res
        metrics["ioaccel_dirty_mb"] = a_dirty
        metrics["ioaccel_count"] = a_count

        cm_res, cm_dirty, cm_count = parse_region('CoreMedia Memory Pool')
        metrics["coremedia_mb"] = cm_dirty

        ms_res, ms_dirty, _ = parse_region('Malloc Small')
        metrics["malloc_small_mb"] = ms_dirty

        ml_res, ml_dirty, _ = parse_region('Malloc Large')
        metrics["malloc_large_mb"] = ml_dirty

        tot_match = re.search(r'^TOTAL\s+(\S+)\s+(\S+)\s+(\S+)', vm_out, re.MULTILINE)
        if tot_match:
            metrics["total_dirty_mb"] = parse_size_str(tot_match.group(3))

    except Exception as e:
        print(f"  [Warn] vmmap sampling failed: {e}", file=sys.stderr)

    # 3. VideoToolbox / AppleAVD User Clients
    try:
        ioreg_out = subprocess.check_output(['ioreg', '-r', '-c', 'AppleAVDUserClient'], stderr=subprocess.DEVNULL, timeout=4).decode()
        client_pids = re.findall(r'"ClientPID"\s*=\s*(\d+)', ioreg_out)
        silk_clients = [p for p in client_pids if p == str(pid)]
        metrics["avd_silk_sessions"] = len(silk_clients)
        metrics["avd_total_sessions"] = len(client_pids)
    except Exception:
        pass

    return metrics

def find_silkplayer_pid():
    try:
        out = subprocess.check_output(['pgrep', '-f', 'SilkPlayer.app/Contents/MacOS/SilkPlayer']).decode().strip()
        pids = [int(p) for p in out.splitlines() if p.strip()]
        return pids[0] if pids else None
    except Exception:
        return None

def kill_silkplayer():
    pid = find_silkplayer_pid()
    if pid:
        try:
            os.kill(pid, 15) # SIGTERM
            time.sleep(1)
            if find_silkplayer_pid():
                os.kill(pid, 9) # SIGKILL
        except Exception:
            pass
    time.sleep(1)

def backup_env():
    if os.path.exists(BACKUP_DIR):
        shutil.rmtree(BACKUP_DIR)
    os.makedirs(BACKUP_DIR, exist_ok=True)
    if os.path.exists(APP_SUPPORT_DIR):
        shutil.copytree(APP_SUPPORT_DIR, os.path.join(BACKUP_DIR, "SilkPlayer_AppSupport"))
    if os.path.exists(CACHES_DIR):
        shutil.copytree(CACHES_DIR, os.path.join(BACKUP_DIR, "SilkPlayer_Caches"))

def restore_env():
    kill_silkplayer()
    if os.path.exists(os.path.join(BACKUP_DIR, "SilkPlayer_AppSupport")):
        if os.path.exists(APP_SUPPORT_DIR):
            shutil.rmtree(APP_SUPPORT_DIR)
        shutil.copytree(os.path.join(BACKUP_DIR, "SilkPlayer_AppSupport"), APP_SUPPORT_DIR)
    if os.path.exists(os.path.join(BACKUP_DIR, "SilkPlayer_Caches")):
        if os.path.exists(CACHES_DIR):
            shutil.rmtree(CACHES_DIR)
        shutil.copytree(os.path.join(BACKUP_DIR, "SilkPlayer_Caches"), CACHES_DIR)

def setup_group_b_env():
    """B 组：完全隔离媒体库的极简单片环境"""
    kill_silkplayer()
    # 清空 AppSupport 与 Caches
    if os.path.exists(APP_SUPPORT_DIR):
        for f in os.listdir(APP_SUPPORT_DIR):
            p = os.path.join(APP_SUPPORT_DIR, f)
            if os.path.isfile(p): os.remove(p)
            elif os.path.isdir(p): shutil.rmtree(p)
    else:
        os.makedirs(APP_SUPPORT_DIR, exist_ok=True)

    if os.path.exists(CACHES_DIR):
        shutil.rmtree(CACHES_DIR)

def setup_group_a_env():
    """A 组：带完整媒体库（已索引电影目录与生成缩略图缓存）状态"""
    kill_silkplayer()
    os.makedirs(APP_SUPPORT_DIR, exist_ok=True)
    thumb_dir = os.path.join(CACHES_DIR, "Thumbnails")
    os.makedirs(thumb_dir, exist_ok=True)

    # 扫描电影目录下的真实视频
    import hashlib
    import uuid

    folder_id = str(uuid.uuid4()).upper()
    folder_entry = {
        "id": folder_id,
        "path": MOVIES_DIR,
        "name": "电影",
        "itemCount": 0,
        "addedDate": 812493122.0,
        "lastScannedDate": 812493122.0
    }

    items = []
    video_exts = {".mkv", ".mp4", ".avi", ".mov", ".m4v"}
    for root, _, files in os.walk(MOVIES_DIR):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in video_exts:
                p = os.path.join(root, f)
                try:
                    stat = os.stat(p)
                    size = stat.st_size
                    title = os.path.splitext(f)[0]
                    item_id = str(uuid.uuid4()).upper()
                    item = {
                        "id": item_id,
                        "path": p,
                        "title": title,
                        "fileSize": size,
                        "duration": 7200.0,
                        "lastModified": stat.st_mtime,
                        "folderId": folder_id,
                        "playbackProgress": 0.0,
                        "lastPlayedPosition": 0.0,
                        "isFinished": False,
                        "videoWidth": 3840 if "2160p" in f or "4K" in f else 1920,
                        "videoHeight": 1608 if "2160p" in f or "4K" in f else 1080,
                        "videoCodec": "HEVC" if "2160p" in f or "x265" in f or "H.265" in f else "H.264"
                    }
                    items.append(item)

                    # 生成缩略图缓存占位文件 (保证真实命中 Disk Cache)
                    cache_raw = f"{p}_{size}".encode('utf-8')
                    cache_key = hashlib.sha256(cache_raw).hexdigest()
                    cache_file = os.path.join(thumb_dir, f"{cache_key}.jpg")
                    if not os.path.exists(cache_file):
                        # 快速写入一个微型 320x180 基础测试 JPEG
                        # 使用 macOS sips 或直接写入一段标准 JPEG 字节
                        with open(cache_file, "wb") as cf:
                            cf.write(b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00`\x00`\x00\x00\xff\xdb\x00C\x00' + b'\x00'*64 + b'\xff\xc0\x00\x0b\x08\x00\xb4\x01@\x01\x01\x11\x00\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xbf\x00\xff\xd9')
                except Exception:
                    pass

    folder_entry["itemCount"] = len(items)
    payload = {
        "folders": [folder_entry],
        "items": items
    }

    index_path = os.path.join(APP_SUPPORT_DIR, "library_index.json")
    with open(index_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"  [Group A Preload] Created library index with {len(items)} items and preheated {len(items)} thumbnail caches.")

def run_benchmark(group_name, duration=30, interval=2, video_path=DEFAULT_VIDEO_PATH):
    print(f"\n========================================================")
    print(f" Starting Benchmark: Group {group_name}")
    print(f" Video: {os.path.basename(video_path)}")
    print(f" Duration: {duration}s | Interval: {interval}s")
    print(f"========================================================")

    # 启动 SilkPlayer 打开目标视频（直接启动二进制，精准传递视频文件参数）
    binary_path = os.path.join(APP_BUNDLE_PATH, "Contents/MacOS/SilkPlayer")
    proc = subprocess.Popen([binary_path, video_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pid = proc.pid

    print(f" SilkPlayer started directly (PID: {pid}). Waiting 3.5s for playback initialization...")
    time.sleep(3.5)

    samples = []
    start_time = time.time()
    step = 0

    while True:
        elapsed = time.time() - start_time
        if elapsed > duration:
            break

        metrics = get_process_metrics(pid)
        metrics["elapsed_seconds"] = round(elapsed, 1)
        samples.append(metrics)

        print(f"  [T+{elapsed:4.1f}s] Footprint: {metrics['footprint_mb']:5.1f} MB (Peak: {metrics['peak_footprint_mb']:5.1f} MB) | "
              f"RSS: {metrics['rss_mb']:5.1f} MB | "
              f"IOSurface: {metrics['iosurface_dirty_mb']:4.1f} MB ({metrics['iosurface_count']:2d} reg) | "
              f"IOAccel: {metrics['ioaccel_dirty_mb']:5.1f} MB | "
              f"AVD: {metrics['avd_silk_sessions']:d} | "
              f"CPU: {metrics['cpu_pct']:4.1f}%")

        time.sleep(interval)

    try:
        proc.terminate()
        proc.wait(timeout=2)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
    kill_silkplayer()
    return samples

def compute_statistics(samples):
    if not samples:
        return {}
    # 跳过前两采样点作为预热阶段，取稳态采样
    steady = samples[2:] if len(samples) > 2 else samples
    fps = [s["footprint_mb"] for s in steady]
    peaks = [s["peak_footprint_mb"] for s in steady]
    rsss = [s["rss_mb"] for s in steady]
    ios_dirtys = [s["iosurface_dirty_mb"] for s in steady]
    ios_counts = [s["iosurface_count"] for s in steady]
    ioaccs = [s["ioaccel_dirty_mb"] for s in steady]
    avd_counts = [s["avd_silk_sessions"] for s in steady]
    cpus = [s["cpu_pct"] for s in steady]
    malloc_smalls = [s["malloc_small_mb"] for s in steady]
    malloc_larges = [s["malloc_large_mb"] for s in steady]

    return {
        "footprint_min": round(min(fps), 1),
        "footprint_mean": round(sum(fps) / len(fps), 1),
        "footprint_max": round(max(fps), 1),
        "peak_footprint": round(max(peaks), 1),
        "rss_mean": round(sum(rsss) / len(rsss), 1),
        "iosurface_dirty_mean": round(sum(ios_dirtys) / len(ios_dirtys), 1),
        "iosurface_count_mean": round(sum(ios_counts) / len(ios_counts), 1),
        "ioaccel_dirty_mean": round(sum(ioaccs) / len(ioaccs), 1),
        "avd_sessions_mean": round(sum(avd_counts) / len(avd_counts), 1),
        "cpu_mean": round(sum(cpus) / len(cpus), 1),
        "malloc_small_mean": round(sum(malloc_smalls) / len(malloc_smalls), 1),
        "malloc_large_mean": round(sum(malloc_larges) / len(malloc_larges), 1),
    }

def main():
    import argparse
    parser = argparse.ArgumentParser(description="SilkPlayer A/B Memory Benchmark")
    parser.add_argument("--mode", choices=["a", "b", "both"], default="both")
    parser.add_argument("--duration", type=int, default=26)
    parser.add_argument("--interval", type=int, default=2)
    parser.add_argument("--video", default=DEFAULT_VIDEO_PATH)
    args = parser.parse_args()

    if not os.path.exists(args.video):
        print(f"Error: Target video not found at {args.video}", file=sys.stderr)
        sys.exit(1)

    backup_env()

    results = {}

    try:
        if args.mode in ("b", "both"):
            setup_group_b_env()
            samples_b = run_benchmark("B (Isolated Minimal Playback)", duration=args.duration, interval=args.interval, video_path=args.video)
            stats_b = compute_statistics(samples_b)
            results["group_b"] = {
                "description": "B 组：完全隔离媒体库的极简单片环境（0 索引文件夹、0 缩略图缓存、直接载入单片）",
                "stats": stats_b,
                "samples": samples_b
            }

        if args.mode in ("a", "both"):
            setup_group_a_env()
            samples_a = run_benchmark("A (With Preloaded Media Library)", duration=args.duration, interval=args.interval, video_path=args.video)
            stats_a = compute_statistics(samples_a)
            results["group_a"] = {
                "description": "A 组：带媒体库状态（26部电影完整索引载入、缩略图就绪、媒体库驻留）",
                "stats": stats_a,
                "samples": samples_a
            }

    finally:
        restore_env()

    # 输出 JSON 报告
    output_path = "/Volumes/2T/SilkPlayer/build/memory_ab_report.json"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)

    print(f"\n========================================================")
    print(f" Benchmark Complete! Detailed JSON saved to: {output_path}")
    print(f"========================================================")

if __name__ == "__main__":
    main()
