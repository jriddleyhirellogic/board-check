# UDP Frame Receiver & Converter Suite

A Python toolkit for receiving high-resolution image frames transmitted over UDP or PCIe and converting them between various RAW12 formats and PNG.

## Overview

This suite captures 4512×4581 12-bit image frames sent as UDP packets, handles packet reordering and loss recovery, and provides multiple conversion pathways depending on your data format needs. It also includes an all-in-one capture-and-view script and a dedicated PCIe format converter.

## Requirements

- Python 3.x
- NumPy
- OpenCV (`cv2`)
- dpkt (for pcap file reading)

```bash
pip install -r requirements.txt
```

## Components

### 1. UDP Frame Receiver (`receiver.py`)

Captures UDP packets and assembles them into raw frame files.

**Key Features:**
- Real-time packet reception with reordering support
- Out-of-order packet handling with configurable wait times
- Missing packet detection and zero-filling
- Background threaded file I/O to prevent packet loss
- PCAP file replay for testing
- Comprehensive packet loss statistics

**Usage:**

```bash
# Standard UDP reception
python receiver.py

# With custom port
python receiver.py --port 35121

# Using raw sockets (requires root, bypasses checksum)
sudo python receiver.py --no-checksum

# Read from pcap file instead of live capture
python receiver.py --pcap capture.pcap

# Enable debug output
python receiver.py --debug
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--port` | 35121 | UDP port to listen on |
| `--raw-dir` | `raw_frames` | Directory for raw frame files |
| `--no-checksum` | - | Use raw sockets (requires root) |
| `--wait-time` | 0.01 | Seconds to wait for late packets |
| `--frame-timeout` | 2.0 | Maximum seconds to wait for a complete frame |
| `--batch-size` | 10 | Number of image lines buffered before writing |
| `--debug` | - | Enable debug output (line/packet numbers) |
| `--skip-buffer-check` | - | Skip UDP buffer size validation |
| `--pcap` | - | Read packets from pcap file |

---

### 2. All-in-One Capture & View (`capture_and_view.py`)

Orchestrates the full pipeline: start the receiver, wait for N frames, convert to PNG, then open an interactive slide deck viewer — all in one command.

**Key Features:**
- Launches and manages `receiver.py` as a subprocess
- Watches for N completed `.raw` files and stops the receiver automatically
- Detects `[TIMEOUT]` events from the receiver and aborts with a clear error
- Converts each captured frame to PNG using `converter.py`
- Opens a full-screen OpenCV slide deck for immediate review
- `--viewer-only` mode to open existing PNGs without capturing

**Usage:**

```bash
# Capture 1 frame, convert, and view (default)
python capture_and_view.py

# Capture 3 frames then view
python capture_and_view.py --n 3

# Read from pcap instead of live capture
python capture_and_view.py --n 5 --pcap recording.pcap

# Custom directories
python capture_and_view.py --n 2 --raw-dir /tmp/raws --out-dir /tmp/pngs

# Keep raw files after conversion
python capture_and_view.py --n 4 --keep-raw

# Capture and convert without opening the viewer
python capture_and_view.py --n 3 --no-viewer

# Open existing PNGs as a slide deck (skip capture)
python capture_and_view.py --viewer-only captured_4512x4512/
```

**Viewer controls:** `N` / `→` next frame · `P` / `←` previous · `F` toggle fullscreen · `Q` / `Esc` quit

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--n` | 1 | Number of frames to capture |
| `--raw-dir` | `raw_frames` | Directory for raw frames |
| `--out-dir` | `captured_4512x4512` | Directory for PNG output |
| `--pcap` | - | Read from pcap instead of live capture |
| `--keep-raw` | - | Do not delete raw files after conversion |
| `--port` | - | Override receiver UDP port |
| `--no-checksum` | - | Pass `--no-checksum` to receiver (raw sockets) |
| `--skip-buffer-check` | - | Skip UDP buffer size check in receiver |
| `--debug` | - | Enable debug output in receiver |
| `--viewer-only` | - | Skip capture/convert; open PNGs from given directory |
| `--no-viewer` | - | Capture and convert but skip the slide deck viewer |

---

### 3. Format Converters

#### a. Unaligned RAW12 → PNG (`converter.py`)

**PRIMARY CONVERTER** — Directly converts the custom hardware RAW12 format (with row padding, non-standard 96-bit pixel packing) to 16-bit PNG in a single step. This is what `capture_and_view.py` uses internally.

**When to use:** Recommended for most use cases with UDP-captured frames.

**Usage:**

```bash
# Convert all raw files in default directory
python converter.py

# Convert specific file
python converter.py --file frame_000001.raw

# Convert and delete raw files after conversion
python converter.py --delete-raw

# Convert from custom directories
python converter.py --raw-dir raw_frames --out-dir png_output
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--file` | - | Convert single file |
| `--raw-dir` | `raw_frames` | Input directory |
| `--out-dir` | `captured_4512x4512` | Output directory |
| `--delete-raw` | - | Delete raw files after conversion |
| `--pattern` | `*.raw` | File pattern to match |

---

#### b. PCIe RAW12 → PNG (`converter_pcie.py`)

Converts raw frames captured via PCIe to 16-bit PNG. PCIe frames have the same row-padding format as UDP frames but are written with a 4096-byte alignment tail at the end of the file (31,080,448 bytes total). This converter trims that tail before processing.

**When to use:** When raw files were captured through the PCIe DMA interface rather than UDP.

**Usage:**

```bash
# Convert all raw files in default directory
python converter_pcie.py

# Convert specific file
python converter_pcie.py --file frame_000001.raw

# Convert and delete raw files after conversion
python converter_pcie.py --delete-raw

# Convert from custom directories
python converter_pcie.py --raw-dir raw_frames --out-dir png_output
```

Options are identical to `converter.py`.

---

#### c. Unaligned → Aligned RAW12 (`converter_unaligned_to_aligned_raw.py`)

Converts custom hardware RAW12 format (with row padding and non-standard pixel packing) to standard RAW12 format (2 pixels per 3 bytes, no padding).

**When to use:** Only needed if you want standard RAW12 files for compatibility with other imaging tools or pipelines.

**Usage:**

```bash
# Convert single file
python converter_unaligned_to_aligned_raw.py input.raw output.raw

# Batch convert directory
python converter_unaligned_to_aligned_raw.py --input-dir raw_frames --output-dir aligned_frames

# Custom file pattern
python converter_unaligned_to_aligned_raw.py --input-dir raw_frames --output-dir aligned_frames --pattern "frame_*.raw"
```

---

#### d. Aligned RAW12 → PNG (`converter_aligned_raw_to_png.py`)

Converts standard RAW12 format (no padding, standard byte packing) to 16-bit PNG images.

**When to use:** Only if you have already produced aligned RAW12 files via `converter_unaligned_to_aligned_raw.py`, or if your source files are standard RAW12 from another tool.

**Usage:**

```bash
# Convert all raw files in default directory
python converter_aligned_raw_to_png.py

# Convert specific file
python converter_aligned_raw_to_png.py --file frame_000001.raw

# Convert and delete raw files after conversion
python converter_aligned_raw_to_png.py --delete-raw

# Convert from custom directories
python converter_aligned_raw_to_png.py --raw-dir aligned_frames --out-dir png_output
```

Options are identical to `converter.py`.

---

## Typical Workflows

### Workflow 1: One-Command Capture + View (RECOMMENDED)

```bash
python capture_and_view.py --n 3
```

Captures 3 frames, converts to PNG, and opens the slide deck viewer automatically.

---

### Workflow 2: Manual Capture + Direct Conversion

```bash
# Step 1: Capture frames
python receiver.py

# Step 2: Convert directly to PNG
python converter.py
```

---

### Workflow 3: PCIe Capture

```bash
# Frames are written by the DMA driver to raw_frames/
python converter_pcie.py --raw-dir raw_frames --out-dir png_output
```

---

### Workflow 4: Two-Step Conversion (for aligned RAW12 output)

```bash
# Step 1: Capture frames
python receiver.py

# Step 2: Convert to aligned RAW12 (for compatibility with other tools)
python converter_unaligned_to_aligned_raw.py --input-dir raw_frames --output-dir aligned_frames

# Step 3: Convert aligned RAW12 to PNG
python converter_aligned_raw_to_png.py --raw-dir aligned_frames --out-dir final_images
```

---

### Workflow 5: PCAP File Analysis

```bash
# Extract and view frames from a pcap recording
python capture_and_view.py --n 5 --pcap capture.pcap

# Or manually:
python receiver.py --pcap capture.pcap --raw-dir extracted_frames
python converter.py --raw-dir extracted_frames --out-dir final_images
```

---

## Configuration

### UDP Receiver Settings

```python
UDP_IP = "10.101.15.195"    # Listening IP address
UDP_PORT = 35121            # UDP port
WIDTH = 4512                # Image width in pixels
HEIGHT = 4581               # Image height in pixels
LANES = 8                   # Data lanes
ROW_PADDING = 16            # Padding bytes per row
PACKETS_PER_LINE = 5        # UDP packets per image row
```

### Converter Settings

```python
WIDTH = 4512                # Image width in pixels
HEIGHT = 4581               # Image height in pixels
ROW_PADDING = 16            # Padding bytes per row
```

## System Requirements

### UDP Buffer Configuration

For high-throughput capture, increase system UDP receive buffer limits:

```bash
# Check current limits
sysctl net.core.rmem_max
sysctl net.core.rmem_default

# Increase to 256MB (recommended)
sudo sysctl -w net.core.rmem_max=268435456
sudo sysctl -w net.core.rmem_default=268435456

# Make persistent across reboots
echo "net.core.rmem_max = 268435456" | sudo tee -a /etc/sysctl.conf
echo "net.core.rmem_default = 268435456" | sudo tee -a /etc/sysctl.conf
```

The receiver checks these limits automatically on startup and exits with instructions if they are too low (unless `--skip-buffer-check` is used).

Run `check_env.sh` before first use to verify the entire environment in one step — it checks the Python interpreter, all required pip packages (offering to install any that are missing), and the sysctl buffer settings (offering to fix them via `sudo` if needed):

```bash
bash check_env.sh
```

## Output Formats

### Raw Frame Files
- **Unaligned RAW12** (UDP): Custom hardware format with 16-byte row padding
- **PCIe RAW12**: Same row format, padded to 4096-byte file boundary
- **Aligned RAW12**: Standard RAW12 format (2 pixels per 3 bytes, no padding)
- **File naming**: `frame_XXXXXX_TIMESTAMP.raw`

### PNG Images
- **Format**: 16-bit grayscale PNG
- **Resolution**: 4512×4581 pixels
- **Bit depth**: 12-bit data scaled to 16-bit (left-shifted by 4)

## Packet Format

Each UDP packet contains:
- **Header** (6 bytes total):
  - Start marker (2 bytes)
  - Line sequence number (2 bytes, big-endian)
  - Packet sequence number (2 bytes, big-endian)
- **Payload**: 12-bit packed pixel data (5 packets per image row)

## Statistics & Monitoring

The UDP receiver displays comprehensive statistics on exit:

```
[STATS] Total UDP payload bytes processed: 123,456,789 bytes
[STATS] Total packets received: 45,678
[STATS] Packets filled with zeros: 23
[STATS] Out of order packets: 45
[STATS] Estimated lost packets: 23
```

## File Size Reference

Expected file sizes for 4512×4581 frames:

| Format | Size |
|--------|------|
| Unaligned RAW12 (UDP, with row padding) | 31,077,504 bytes (~29.6 MB) |
| PCIe RAW12 (padded to 4096-byte boundary) | 31,080,448 bytes (~29.7 MB) |
| Aligned RAW12 (standard, no padding) | 31,004,208 bytes (~29.6 MB) |
| 16-bit PNG | Variable (compressed), typically 20–40% of raw size |

## Troubleshooting

### High Packet Loss
1. Increase UDP buffer size (see System Requirements)
2. Reduce `--wait-time` if packets arrive quickly
3. Use `--no-checksum` with root privileges
4. Check network configuration and bandwidth

### Frame Timeout (`capture_and_view.py`)
`capture_and_view.py` will print a clear timeout error and abort if the receiver reports a `[TIMEOUT]` event. Common causes:
- No data arriving on the network interface
- Sender stopped transmitting mid-frame
- Packet loss rate too high to complete a frame
- Wrong IP address or UDP port configured

### Corrupted Images
1. Verify image dimensions match hardware output (4512×4581)
2. Check row padding configuration
3. Ensure complete frame reception (check timeout settings)
4. Use `--debug` to monitor packet reception
5. For PCIe files, ensure you are using `converter_pcie.py` not `converter.py`

### Conversion Errors
1. Verify raw file size matches expected dimensions (see File Size Reference)
2. Check if files need unaligned→aligned conversion first
3. Ensure sufficient disk space
4. Verify file permissions
