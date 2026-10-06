import argparse
import os
import sys
import subprocess
import time
import glob
import threading
import signal
from pathlib import Path

# ── paths to the two scripts (assumed to be in the same directory) ──────────
SCRIPT_DIR   = Path(__file__).parent.resolve()
RECEIVER_PY  = SCRIPT_DIR / "receiver.py"
CONVERTER_PY = SCRIPT_DIR / "converter.py"

# ── defaults (must match receiver.py / converter.py defaults) ────────────────
DEFAULT_RAW_DIR = "raw_frames"
DEFAULT_OUT_DIR = "captured_4512x4512"

# ────────────────────────────────────────────────────────────────────────────
# Slide-deck viewer (pure Python / OpenCV, no extra deps beyond converter.py)
# ────────────────────────────────────────────────────────────────────────────

def open_slide_deck(image_paths: list[str]):
    """Open a simple full-screen slide deck using OpenCV."""
    try:
        import cv2
        import numpy as np
    except ImportError:
        print("[VIEWER] OpenCV not available – cannot open slide deck.")
        print("[VIEWER] Install with:  pip install opencv-python")
        return

    if not image_paths:
        print("[VIEWER] No images to display.")
        return

    images      = []   # lazy-loaded cache
    loaded      = {}   # index → np.ndarray

    def load(idx):
        if idx not in loaded:
            path = image_paths[idx]
            img = cv2.imread(path, cv2.IMREAD_ANYDEPTH | cv2.IMREAD_GRAYSCALE)
            if img is None:
                img = np.zeros((100, 100), dtype=np.uint8)
            # Normalise to 8-bit for display
            if img.dtype != np.uint8:
                img = cv2.normalize(img, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)
            loaded[idx] = img
        return loaded[idx]

    WINDOW = "Frame Viewer  [P N] navigate  [F] fullscreen  [Q/Esc] quit"
    cv2.namedWindow(WINDOW, cv2.WINDOW_NORMAL)
    cv2.setWindowProperty(WINDOW, cv2.WND_PROP_FULLSCREEN, cv2.WINDOW_FULLSCREEN)

    idx       = 0
    total     = len(image_paths)
    fullscreen = True

    print(f"\n[VIEWER] Opening {total} image(s) as slide deck")
    print("[VIEWER] Controls: P / N to navigate | F toggle fullscreen | Q or Esc to quit\n")

    while True:
        frame = load(idx)

        # Overlay: frame number
        display = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
        label   = f"Frame {idx + 1} / {total}  |  {Path(image_paths[idx]).name}"
        cv2.putText(display, label, (30, 60),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.8, (0, 255, 255), 3, cv2.LINE_AA)

        cv2.imshow(WINDOW, display)
        key = cv2.waitKey(0) & 0xFF

        if key in (ord('q'), ord('Q'), 27):          # Q or Esc → quit
            break
        elif key in (83,  ord('n')):                 # → or D or N → next
            idx = min(idx + 1, total - 1)
        elif key in (81, ord('p')):                  # ← or A or P → prev
            idx = max(idx - 1, 0)
        elif key in (ord('f'), ord('F')):            # F → toggle fullscreen
            fullscreen = not fullscreen
            prop = cv2.WINDOW_FULLSCREEN if fullscreen else cv2.WINDOW_NORMAL
            cv2.setWindowProperty(WINDOW, cv2.WND_PROP_FULLSCREEN, prop)

    cv2.destroyAllWindows()
    print("[VIEWER] Slide deck closed.")


# ────────────────────────────────────────────────────────────────────────────
# Receiver watchdog  – polls raw_dir for new .raw files and stops the process
# when N frames have been written.  Also monitors receiver stdout/stderr for
# [TIMEOUT] messages and aborts immediately if one is detected.
# ────────────────────────────────────────────────────────────────────────────

class ReceiverOutputMonitor:
    """
    Reads receiver stdout/stderr in a background thread, echoes every line to
    the console, and sets a flag if a [TIMEOUT] line is detected.
    """
    def __init__(self, proc: subprocess.Popen):
        self.proc         = proc
        self.timed_out    = False   # set to True when [TIMEOUT] is seen
        self.timeout_msg  = ""      # the full [TIMEOUT] line for display
        self._lock        = threading.Lock()
        self._thread      = threading.Thread(target=self._read_loop, daemon=True)
        self._thread.start()

    def _read_loop(self):
        try:
            for raw_line in self.proc.stdout:
                line = raw_line.rstrip("\n")
                print(line)                          # echo to console
                if "[TIMEOUT]" in line:
                    with self._lock:
                        self.timed_out   = True
                        self.timeout_msg = line
        except Exception:
            pass

    def join(self, timeout=5.0):
        self._thread.join(timeout=timeout)


def wait_for_n_frames(raw_dir: str, n: int, proc: subprocess.Popen,
                      monitor: ReceiverOutputMonitor,
                      poll_interval: float = 0.5):
    """
    Block until `n` .raw files appear in raw_dir **or** a [TIMEOUT] is detected,
    then terminate proc.

    Returns:
        (completed_files, timed_out)
        - completed_files : list of fully-written .raw paths (up to n)
        - timed_out       : True if the receiver reported a frame timeout
    """
    print(f"[WATCHER] Waiting for {n} frame(s) in '{raw_dir}' …")
    last_reported = -1

    while True:
        # ── check for timeout signal from receiver ───────────────────────
        if monitor.timed_out:
            print()
            print("=" * 60)
            print("  ✖  IMAGE CAPTURE TIMED OUT")
            print("=" * 60)
            print(f"  The receiver reported a frame timeout (no complete frame")
            print(f"  was received within the allowed time window).")
            print()
            print(f"  Receiver message: {monitor.timeout_msg.strip()}")
            print()
            print("  Possible causes:")
            print("    • No data arriving on the network interface")
            print("    • Sender stopped transmitting mid-frame")
            print("    • Packet loss rate too high to complete a frame")
            print("    • Wrong IP address or UDP port configured")
            print()
            print("  Aborting – conversion step will NOT run.")
            print("=" * 60)

            try:
                proc.terminate()
                proc.wait(timeout=5)
            except Exception:
                proc.kill()

            return [], True   # ← signal timeout to caller

        # ── count completed .raw files ───────────────────────────────────
        raw_files = sorted(glob.glob(os.path.join(raw_dir, "frame_*.raw")))

        completed = []
        now = time.time()
        for f in raw_files:
            try:
                mtime = os.path.getmtime(f)
                if now - mtime > poll_interval * 2:
                    completed.append(f)
            except OSError:
                pass

        count = len(completed)
        if count != last_reported:
            print(f"[WATCHER] {count}/{n} frame(s) ready …")
            last_reported = count

        if count >= n:
            print(f"[WATCHER] {n} frame(s) captured – stopping receiver …")
            try:
                proc.terminate()
                proc.wait(timeout=5)
            except Exception:
                proc.kill()
            return completed[:n], False   # ← success

        if proc.poll() is not None:
            print(f"[WATCHER] Receiver exited early (rc={proc.returncode}).")
            return completed, False

        time.sleep(poll_interval)


# ────────────────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Capture N frames → convert to PNG → open slide deck",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Capture 3 live frames then view
  python capture_and_view.py --n 3

  # Read from a pcap file instead of live capture
  python capture_and_view.py --n 5 --pcap recording.pcap

  # Custom directories
  python capture_and_view.py --n 2 --raw-dir /tmp/raws --out-dir /tmp/pngs

  # Keep raw files after conversion
  python capture_and_view.py --n 4 --keep-raw
        """)

    parser.add_argument("--n",             type=int,   default=1,
                        help="Number of frames to capture (default: 1)")
    parser.add_argument("--raw-dir",       default=DEFAULT_RAW_DIR,
                        help=f"Directory for raw frames (default: {DEFAULT_RAW_DIR})")
    parser.add_argument("--out-dir",       default=DEFAULT_OUT_DIR,
                        help=f"Directory for PNG output (default: {DEFAULT_OUT_DIR})")
    parser.add_argument("--pcap",          type=str,   default=None,
                        help="Read from pcap file instead of live capture")
    parser.add_argument("--keep-raw",      action="store_true",
                        help="Do NOT delete raw files after conversion")
    parser.add_argument("--port",          type=int,   default=None,
                        help="Override receiver UDP port")
    parser.add_argument("--no-checksum",   action="store_true",
                        help="Pass --no-checksum to receiver (raw sockets, needs root)")
    parser.add_argument("--skip-buffer-check", action="store_true",
                        help="Skip UDP buffer size check in receiver")
    parser.add_argument("--debug",         action="store_true",
                        help="Enable debug output in receiver")
    parser.add_argument("--viewer-only",   type=str,   default=None,
                        metavar="PNG_DIR",
                        help="Skip capture/convert – just open PNGs in PNG_DIR as slide deck")

    args = parser.parse_args()

    # ── viewer-only shortcut ─────────────────────────────────────────────────
    if args.viewer_only:
        pngs = sorted(glob.glob(os.path.join(args.viewer_only, "*.png")))
        if not pngs:
            print(f"[ERROR] No PNG files found in '{args.viewer_only}'")
            sys.exit(1)
        open_slide_deck(pngs)
        return

    if args.n < 1:
        print("[ERROR] --n must be at least 1")
        sys.exit(1)

    # ── validate script paths ────────────────────────────────────────────────
    for path, name in [(RECEIVER_PY, "receiver.py"), (CONVERTER_PY, "converter.py")]:
        if not path.exists():
            print(f"[ERROR] Cannot find {name} at {path}")
            print(f"        Place capture_and_view.py in the same directory as the two scripts.")
            sys.exit(1)

    os.makedirs(args.raw_dir, exist_ok=True)
    os.makedirs(args.out_dir, exist_ok=True)

    # ────────────────────────────────────────────────────────────────────────
    # STEP 1 – Start receiver
    # ────────────────────────────────────────────────────────────────────────
    receiver_cmd = [sys.executable, str(RECEIVER_PY),
                    "--raw-dir", args.raw_dir]

    if args.pcap:
        receiver_cmd += ["--pcap", args.pcap]
    if args.port:
        receiver_cmd += ["--port", str(args.port)]
    if args.no_checksum:
        receiver_cmd.append("--no-checksum")
    if args.skip_buffer_check:
        receiver_cmd.append("--skip-buffer-check")
    if args.debug:
        receiver_cmd.append("--debug")

    print("=" * 60)
    print(f"  STEP 1/3 – Starting receiver (target: {args.n} frame(s))")
    print("=" * 60)
    print(f"  Command: {' '.join(receiver_cmd)}\n")

    receiver_proc = subprocess.Popen(
        receiver_cmd,
        stdout=subprocess.PIPE,   # capture so monitor can scan for [TIMEOUT]
        stderr=subprocess.STDOUT, # merge stderr into stdout
        text=True,
        bufsize=1,                # line-buffered
    )

    # ── start output monitor (echoes lines + watches for [TIMEOUT]) ──────────
    monitor = ReceiverOutputMonitor(receiver_proc)

    # ── wait / watch for N frames ────────────────────────────────────────────
    completed_raws, timed_out = wait_for_n_frames(
        raw_dir=args.raw_dir,
        n=args.n,
        proc=receiver_proc,
        monitor=monitor,
    )

    # Drain any remaining output from the receiver before continuing
    monitor.join(timeout=3.0)

    # ── abort if a timeout was detected ─────────────────────────────────────
    if timed_out:
        sys.exit(1)

    if len(completed_raws) < args.n:
        print(f"[WARNING] Only {len(completed_raws)} frame(s) available "
              f"(requested {args.n}).")
        if not completed_raws:
            print("[ERROR] No frames captured – aborting.")
            sys.exit(1)

    # ────────────────────────────────────────────────────────────────────────
    # STEP 2 – Convert raw → PNG
    # ────────────────────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print(f"  STEP 2/3 – Converting {len(completed_raws)} raw file(s) to PNG")
    print("=" * 60)

    converter_cmd = [sys.executable, str(CONVERTER_PY),
                     "--raw-dir", args.raw_dir,
                     "--out-dir", args.out_dir]

    if not args.keep_raw:
        converter_cmd.append("--delete-raw")

    png_paths = []
    for raw_file in completed_raws:
        out_png = os.path.join(
            args.out_dir,
            Path(raw_file).stem + ".png"
        )
        cmd = [sys.executable, str(CONVERTER_PY),
               "--file", raw_file,
               "--out-dir", args.out_dir]
        if not args.keep_raw:
            cmd.append("--delete-raw")

        result = subprocess.run(cmd)
        if result.returncode == 0 and os.path.exists(out_png):
            png_paths.append(out_png)
        else:
            print(f"[WARNING] Converter failed for {raw_file} (rc={result.returncode})")

    if not png_paths:
        print("[ERROR] Conversion produced no PNG files – aborting viewer.")
        sys.exit(1)

    png_paths = sorted(png_paths)

    # ────────────────────────────────────────────────────────────────────────
    # STEP 3 – Open slide deck
    # ────────────────────────────────────────────────────────────────────────
    print()
    print("=" * 60)
    print(f"  STEP 3/3 – Opening slide deck ({len(png_paths)} image(s))")
    print("=" * 60)

    open_slide_deck(png_paths)

    print("\n[DONE] All steps complete.")


if __name__ == "__main__":
    main()