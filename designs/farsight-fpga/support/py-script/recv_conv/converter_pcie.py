#!/usr/bin/env python3
import os
import argparse
import numpy as np
import cv2
from pathlib import Path

# ----------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------
WIDTH = 4512
HEIGHT = 4581
ROW_PADDING = 16

BYTES_PER_ROW = WIDTH * 3 // 2 + ROW_PADDING  # 6768 packed + 16 pad = 6784
VALID_BYTES = HEIGHT * BYTES_PER_ROW            # 4581 * 6784 = 31,077,504
# Raw files are padded to a 4096-byte boundary: 31,080,448 bytes total.
# The last 2,944 bytes are alignment padding and must be discarded.

# Default directories
RAW_DIR = "raw_frames"
OUT_DIR = "captured_4512x4512"

# ----------------------------------------------------------------------
def strip_padding(raw: bytes) -> bytes:
    """Remove row padding from raw frame data"""
    packed_row_bytes = WIDTH * 3 // 2
    clean = bytearray()
    offset = 0
    for _ in range(HEIGHT):
        clean += raw[offset:offset + packed_row_bytes]
        offset += packed_row_bytes + ROW_PADDING
    return bytes(clean)

def unpack_payload(payload: bytes) -> np.ndarray:
    """Unpack 12-bit packed data into 16-bit numpy array"""
    if not payload:
        return np.zeros((HEIGHT, WIDTH), dtype=np.uint16)
    
    # Sequential 12-bit extraction (no pixel reordering)
    ba = np.frombuffer(payload, dtype=np.uint8)
    n = (len(ba) // 3) * 3
    ba = ba[:n].reshape(-1, 3).astype(np.uint16)
    p0 = ba[:, 0] | ((ba[:, 1] & 0x0F) << 8)
    p1 = (ba[:, 1] >> 4) | (ba[:, 2] << 4)
    pixels = np.empty(len(ba) * 2, dtype=np.uint16)
    pixels[0::2] = p0
    pixels[1::2] = p1
    total = HEIGHT * WIDTH
    if len(pixels) < total:
        pixels = np.pad(pixels, (0, total - len(pixels)), 'constant')
    return pixels[:total].reshape(HEIGHT, WIDTH)

def convert_raw_to_png(raw_path, output_path, delete_raw=False, verbose=True):
    """Convert a single raw frame to PNG"""
    try:
        # Read raw file, discarding the 4096-byte alignment tail
        with open(raw_path, 'rb') as f:
            raw = f.read(VALID_BYTES)

        # Strip padding and unpack
        payload = strip_padding(raw)
        img12 = unpack_payload(payload)
        
        # Convert 12-bit to 16-bit (shift left by 4)
        img16 = (img12.astype(np.uint32) << 4).astype(np.uint16)
        
        # Save as 16-bit PNG
        cv2.imwrite(output_path, img16)
        
        if verbose:
            status = "(raw deleted)" if delete_raw else ""
            print(f"[OK] {os.path.basename(output_path)} {status}")
        
        # Delete raw file if requested
        if delete_raw:
            os.remove(raw_path)
            
        return True
        
    except Exception as e:
        print(f"[ERROR] Failed to convert {raw_path}: {e}")
        return False

def batch_convert(raw_dir, out_dir, delete_raw=False, pattern="*.raw"):
    """Convert all raw files in a directory"""
    raw_path = Path(raw_dir)
    out_path = Path(out_dir)
    
    # Create output directory
    out_path.mkdir(parents=True, exist_ok=True)
    
    # Find all raw files
    raw_files = sorted(raw_path.glob(pattern))
    
    if not raw_files:
        print(f"No raw files found in {raw_dir}")
        return
    
    print(f"Found {len(raw_files)} raw files to convert")
    print(f"Output directory: {out_dir}\n")
    
    success_count = 0
    for raw_file in raw_files:
        output_file = out_path / raw_file.name.replace('.raw', '.png')
        if convert_raw_to_png(str(raw_file), str(output_file), delete_raw):
            success_count += 1
    
    print(f"\n[DONE] Converted {success_count}/{len(raw_files)} files")
    if delete_raw and success_count > 0:
        print(f"[INFO] Deleted {success_count} raw files")

# ----------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Convert 4512×4512 12-bit raw frames to 16-bit PNG images",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert all raw files in default directory
  python converter.py
  
  # Convert specific file
  python converter.py --file frame_000001.raw
  
  # Convert and delete raw files
  python converter.py --delete-raw
  
  # Convert from custom directories
  python converter.py --raw-dir my_raws --out-dir my_pngs
        """
    )
    
    parser.add_argument("--file", type=str, help="Convert single file")
    parser.add_argument("--raw-dir", default=RAW_DIR, help=f"Input directory (default: {RAW_DIR})")
    parser.add_argument("--out-dir", default=OUT_DIR, help=f"Output directory (default: {OUT_DIR})")
    parser.add_argument("--delete-raw", action="store_true", help="Delete raw files after conversion")
    parser.add_argument("--pattern", default="*.raw", help="File pattern to match (default: *.raw)")
    
    args = parser.parse_args()
    
    # Create output directory
    os.makedirs(args.out_dir, exist_ok=True)
    
    if args.file:
        # Convert single file
        if not os.path.exists(args.file):
            print(f"[ERROR] File not found: {args.file}")
            exit(1)
        
        output_file = os.path.join(args.out_dir, 
                                   os.path.basename(args.file).replace('.raw', '.png'))
        convert_raw_to_png(args.file, output_file, args.delete_raw)
    else:
        # Batch convert
        batch_convert(args.raw_dir, args.out_dir, args.delete_raw, args.pattern)
