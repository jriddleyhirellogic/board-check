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
HEIGHT = 4577
ROW_PADDING = 16

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
    
    # Ensure payload length is multiple of 12
    payload = payload[: (len(payload) // 12) * 12]
    if not payload:
        return np.zeros((HEIGHT, WIDTH), dtype=np.uint16)

    # Convert to 32-bit words (big-endian)
    words = np.frombuffer(payload, dtype='>u4')
    
    # Calculate expected dimensions
    groups_per_line = WIDTH // 8
    expected_words = HEIGHT * groups_per_line * 3
    
    # Pad if necessary
    if len(words) < expected_words:
        words = np.pad(words, (0, expected_words - len(words)), 'constant')
    
    # Reshape to (HEIGHT, groups_per_line, 3)
    words = words[:expected_words].reshape(HEIGHT, groups_per_line, 3)

    # Extract three 32-bit words per group
    w0, w1, w2 = [words[:,:,i].astype(np.uint64) for i in range(3)]
    
    # Unpack 8 pixels from 3 words (12 bytes = 96 bits / 12 bits per pixel = 8 pixels)
    pixels = np.empty((HEIGHT, groups_per_line, 8), dtype=np.uint16)
    pixels[:,:,0] = (w0 & 0xFFF)
    pixels[:,:,1] = ((w0 >> 12) & 0xFFF)
    pixels[:,:,2] = (((w0 >> 24) | (w1 << 8)) & 0xFFF)
    pixels[:,:,3] = ((w1 >> 4) & 0xFFF)
    pixels[:,:,4] = ((w1 >> 16) & 0xFFF)
    pixels[:,:,5] = (((w1 >> 28) | (w2 << 4)) & 0xFFF)
    pixels[:,:,6] = ((w2 >> 8) & 0xFFF)
    pixels[:,:,7] = ((w2 >> 20) & 0xFFF)
    
    return pixels.reshape(HEIGHT, WIDTH)

def convert_raw_to_png(raw_path, output_path, delete_raw=False, verbose=True):
    """Convert a single raw frame to PNG"""
    try:
        # Read raw file
        with open(raw_path, 'rb') as f:
            raw = f.read()
        
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
