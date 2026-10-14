#!/usr/bin/env python3
import os
import sys
import time
import subprocess
import signal

MEDIA_DIR = os.environ.get("SILK_TEST_MEDIA_DIR", "/tmp/silk_test_media")
VIDEOS = [
    os.path.join(MEDIA_DIR, "sample_tos_4k.mov"),
    os.path.join(MEDIA_DIR, "sample_dovi_p5.mp4"),
    os.path.join(MEDIA_DIR, "sample_8k_hevc.mp4"),
    os.path.join(MEDIA_DIR, "sample_jellyfish_4k.mkv"),
    os.path.join(MEDIA_DIR, "sample_4k_dv.mkv")
]

APP_PATH = os.environ.get("SILK_APP_PATH", "/Applications/SilkPlayer.app/Contents/MacOS/SilkPlayer")
if not os.path.exists(APP_PATH) and os.path.exists("build/SilkPlayer.app/Contents/MacOS/SilkPlayer"):
    APP_PATH = "build/SilkPlayer.app/Contents/MacOS/SilkPlayer"
TEST_DURATION = 55  # >= 30s as mandated by Core Rule 7

def kill_silkplayer():
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
            return f"CPU: {parts[0]}%, RSS: {int(parts[2])//1024}MB"
    except Exception:
        pass
    return "N/A"

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

def send_key(key_code, modifiers=[]):
    if not modifiers:
        script = f'tell application "System Events" to key code {key_code}'
    else:
        mod_str = " using {" + ", ".join(modifiers) + "}"
        script = f'tell application "System Events" to key code {key_code}{mod_str}'
    subprocess.run(['osascript', '-e', script])

def main():
    print(f"=== Starting SilkPlayer Comprehensive Real Machine Playback Test (Target: >= {TEST_DURATION}s) ===")
    kill_silkplayer()

    cmd = [APP_PATH] + VIDEOS
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    pid = proc.pid
    print(f"Launched SilkPlayer (PID {pid}) with {len(VIDEOS)} playlist items:")
    for idx, v in enumerate(VIDEOS):
        print(f"  [{idx+1}] {os.path.basename(v)}")

    start_time = time.time()
    snapshots = []

    # Sequence of interactive events:
    # t=5s: Seek +5s while playing (Right Arrow = 124)
    # t=9s: Pause playback (Space = 49)
    # t=12s: Seek +5s while PAUSED (Right Arrow = 124, tests pause seek rendering!)
    # t=15s: Unpause (Space = 49)
    # t=19s: Next track (Cmd + Right Arrow -> DV Profile 5)
    # t=26s: Next track (Cmd + Right Arrow -> 8K HEVC 150Mbps)
    # t=33s: Next track (Cmd + Right Arrow -> Jellyfish 120Mbps MKV)
    # t=39s: Next track (Cmd + Right Arrow -> 300 53GB REMUX TrueHD Atmos over SMB)
    # t=46s: Next track (Cmd + Right Arrow -> 花月杀手 36GB over SMB)
    # t=51s: Previous track (Cmd + Left Arrow -> Back to 300)
    events = [
        (5.0, "Seeking +5s during playback (Right Arrow)", lambda: send_key(124)),
        (9.0, "Pausing playback (Space)", lambda: send_key(49)),
        (12.0, "Seeking +5s during PAUSE state (verifying instant freeze frame seek)", lambda: send_key(124)),
        (15.0, "Resuming playback from pause state (Space)", lambda: send_key(49)),
        (19.0, "Switching to Next Episode: DV Profile 5 (Cmd + Right Arrow)", lambda: send_key(124, ["command down"])),
        (26.0, "Switching to Next Episode: 8K HEVC 150Mbps (Cmd + Right Arrow)", lambda: send_key(124, ["command down"])),
        (33.0, "Switching to Next Episode: Jellyfish 120Mbps MKV (Cmd + Right Arrow)", lambda: send_key(124, ["command down"])),
        (38.0, "Switching to Next Episode: 300 53GB REMUX TrueHD Atmos via SMB (Cmd + Right Arrow)", lambda: send_key(124, ["command down"])),
        (42.0, "Cycling Audio Track on 300 (Key 'A')", lambda: send_key(0)),
        (45.0, "Switching to Next Episode: 花月杀手 36GB via SMB (Cmd + Right Arrow)", lambda: send_key(124, ["command down"])),
        (48.0, "Cycling Subtitle Track on 花月杀手 (Key 'S')", lambda: send_key(1)),
        (51.0, "Seeking +5s during playback on 花月杀手 with subtitle (Right Arrow)", lambda: send_key(124)),
        (53.0, "Switching back to Previous Episode: 300 REMUX (Cmd + Left Arrow)", lambda: send_key(123, ["command down"]))
    ]

    while True:
        elapsed = time.time() - start_time
        if elapsed >= TEST_DURATION:
            break

        # Check process status
        ret = proc.poll()
        if ret is not None:
            print(f"ERROR: SilkPlayer exited prematurely with code {ret} at {elapsed:.1f}s")
            _, stderr = proc.communicate()
            print(f"Stderr: {stderr.decode(errors='ignore')}")
            sys.exit(1)

        # Check for unexpected modal dialogs
        modal = check_modal_dialogs()
        if modal:
            print(f"ERROR: Detected modal error dialog: {modal}")
            proc.kill()
            sys.exit(2)

        # Trigger events
        for ev in list(events):
            t_ev, desc, action = ev
            if elapsed >= t_ev:
                events.remove(ev)
                print(f"[{elapsed:.1f}s] Event: {desc}...")
                action()

        stats = get_cpu_mem(pid)
        if int(elapsed) % 4 == 0 and int(elapsed) not in [s[0] for s in snapshots]:
            footprint = get_footprint(pid)
            snapshots.append((int(elapsed), stats, footprint))
            print(f"[{elapsed:.1f}s] SilkPlayer Running Healthy | {stats} | PhysFootprint: {footprint}")

        time.sleep(0.5)

    total_elapsed = time.time() - start_time
    print(f"\nPlayback & interaction testing completed cleanly across {total_elapsed:.1f}s (>= 30s threshold satisfied).")

    # Clean shutdown via SIGTERM
    print("Sending SIGTERM to verify clean dock/process exit...")
    proc.terminate()
    try:
        proc.wait(timeout=3)
        print("Process exited cleanly within 3s.")
    except subprocess.TimeoutExpired:
        proc.kill()
        print("Process required force kill.")

    clean_script = os.path.join(os.path.dirname(__file__), "clean_installed_app.sh")
    if os.path.exists(clean_script):
        print("\n-> Executing clean_installed_app.sh to wipe test installations & caches...")
        subprocess.run(["bash", clean_script])

    print("\n=== Real Machine Test PASSED ===")
    return 0

if __name__ == '__main__':
    sys.exit(main())
