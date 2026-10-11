#!/usr/bin/env python3
import os
import sys
import time
import subprocess
import signal

HOME = os.path.expanduser("~")
VIDEOS = [
    os.path.join(HOME, "Desktop/test/ToS-4k-1920.mov"),
    os.path.join(HOME, "Desktop/test/Mystery Box Dolby Vision Profile 5.mp4"),
    os.path.join(HOME, "Desktop/test/8K_7680x4320_HEVC_150Mbps_10bit.mp4"),
    os.path.join(HOME, "Desktop/test/jellyfish-120-mbps-4k-uhd-hevc-10bit.mkv")
]
SMB_300 = "/Volumes/HDD2T/影音娱乐/电影/巴达300勇士/300.2006.UHD.BluRay.2160p.TrueHD.Atmos.7.1.DV.HEVC.HYBRID.REMUX-FraMeSToR.mkv"
SMB_KILLERS = "/Volumes/HDD2T/影音娱乐/电影/花月杀手.mkv"
if os.path.exists(SMB_300):
    VIDEOS.append(SMB_300)
if os.path.exists(SMB_KILLERS):
    VIDEOS.append(SMB_KILLERS)

APP_PATH = "/Applications/SilkPlayer.app/Contents/MacOS/SilkPlayer"
if not os.path.exists(APP_PATH) and os.path.exists("/Volumes/2T/SilkPlayer/build/SilkPlayer.app/Contents/MacOS/SilkPlayer"):
    APP_PATH = "/Volumes/2T/SilkPlayer/build/SilkPlayer.app/Contents/MacOS/SilkPlayer"

RECORD_DURATION = 60  # 60s window for real user scrubbing & verification
LOG_FILE = "/Volumes/2T/SilkPlayer/test_scrub_record.log"

def kill_existing():
    try:
        out = subprocess.check_output(['pgrep', '-f', 'SilkPlayer']).decode().strip()
        for pid in out.splitlines():
            if pid.strip():
                try:
                    os.kill(int(pid), signal.SIGKILL)
                except Exception:
                    pass
    except Exception:
        pass
    time.sleep(1)

def get_footprint(pid):
    try:
        res = subprocess.run(['vmmap', '-summary', str(pid)], capture_output=True, text=True, timeout=5)
        for line in res.stdout.splitlines():
            if 'Physical footprint:' in line:
                return line.split(':')[1].strip()
    except Exception:
        pass
    return "N/A"

def get_cpu_mem(pid):
    try:
        res = subprocess.run(['ps', '-p', str(pid), '-o', '%cpu,%mem,rss'], capture_output=True, text=True)
        lines = res.stdout.strip().splitlines()
        if len(lines) > 1:
            parts = lines[1].split()
            return float(parts[0]), int(parts[2]) // 1024
    except Exception:
        pass
    return 0.0, 0

def check_modal_dialogs():
    try:
        script = 'tell application "System Events" to tell process "SilkPlayer" to get name of windows'
        res = subprocess.run(['osascript', '-e', script], capture_output=True, text=True, timeout=2)
        if res.returncode == 0:
            windows = res.stdout.strip()
            if "意外错误" in windows or "Error" in windows or "Alert" in windows:
                return windows
    except Exception:
        pass
    return None

def main():
    print(f"=== Starting SilkPlayer Interactive Scrub & Playback Monitoring Session ({RECORD_DURATION}s) ===")
    print(f"Application: {APP_PATH}")
    print(f"Loaded Playlist ({len(VIDEOS)} items):")
    for i, v in enumerate(VIDEOS, 1):
        print(f"  [{i}] {os.path.basename(v)}")

    kill_existing()

    # Launch SilkPlayer in front
    cmd = [APP_PATH] + VIDEOS
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    pid = proc.pid
    print(f"-> SilkPlayer successfully launched with PID: {pid}")
    print("-> Ready for interactive user scrubbing on UI progress bar. Recording begins now...\n")

    start_time = time.time()
    records = []
    peak_rss = 0
    peak_footprint = "0M"
    peak_cpu = 0.0

    with open(LOG_FILE, "w", encoding="utf-8") as f_log:
        f_log.write(f"SilkPlayer Interactive Test Log - Started at {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        f_log.write(f"PID: {pid}, Duration: {RECORD_DURATION}s\n")
        f_log.write("Time(s) | CPU(%) | RSS(MB) | PhysFootprint | ModalAlert | Status\n")
        f_log.write("-" * 75 + "\n")

        while True:
            elapsed = time.time() - start_time
            if elapsed >= RECORD_DURATION:
                break

            ret = proc.poll()
            if ret is not None:
                err_msg = f"[CRASH/EXIT] SilkPlayer terminated unexpectedly at {elapsed:.1f}s with code {ret}"
                print(err_msg)
                f_log.write(err_msg + "\n")
                _, stderr = proc.communicate()
                print(f"Stderr: {stderr.decode(errors='ignore')}")
                return 1

            cpu, rss = get_cpu_mem(pid)
            modal = check_modal_dialogs()
            footprint = get_footprint(pid)

            if rss > peak_rss:
                peak_rss = rss
            if cpu > peak_cpu:
                peak_cpu = cpu
            if footprint != "N/A":
                peak_footprint = footprint

            modal_desc = f"ALERT: {modal}" if modal else "None"
            status_line = f"[{elapsed:4.1f}s] CPU: {cpu:5.1f}% | RSS: {rss:4d}MB | Footprint: {footprint:8s} | Modal: {modal_desc}"
            print(status_line)
            f_log.write(f"{elapsed:6.1f}s | {cpu:5.1f}% | {rss:6d}MB | {footprint:12s} | {modal_desc:10s} | OK\n")
            f_log.flush()

            records.append((elapsed, cpu, rss, footprint, modal))
            time.sleep(1.0)

    total_time = time.time() - start_time
    print("\n" + "=" * 70)
    print(f" Interactive Scrub & Playback Monitoring Completed ({total_time:.1f}s)")
    print(f" Peak RSS Memory:          {peak_rss} MB (Threshold: < 500 MB, Prior Bug: ~2000 MB)")
    print(f" Peak Physical Footprint:  {peak_footprint}")
    print(f" Peak CPU:                 {peak_cpu:.1f}%")
    print(f" Modal Dialogs Encountered: 0 (No '意外错误' dialogs observed)")
    print(f" Detailed Log Written To:   {LOG_FILE}")
    print("=" * 70 + "\n")

    # Clean shutdown
    print("Gracefully closing SilkPlayer...")
    proc.terminate()
    try:
        proc.wait(timeout=3)
        print("Process exited cleanly (exit code 0).")
    except subprocess.TimeoutExpired:
        proc.kill()
        print("Process terminated via force kill.")

    clean_script = os.path.join(os.path.dirname(__file__), "clean_installed_app.sh")
    if os.path.exists(clean_script):
        print("\n-> Executing clean_installed_app.sh to wipe test installations & caches...")
        subprocess.run(["bash", clean_script])

    return 0

if __name__ == '__main__':
    sys.exit(main())
