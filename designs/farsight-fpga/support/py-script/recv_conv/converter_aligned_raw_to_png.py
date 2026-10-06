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

# Default directories
RAW_DIR = "raw_frames"
OUT_DIR = "captured_4512x4512"

# ----------------------------------------------------------------------
def unpack_payload(payload: bytes) -> np.ndarray:
    """Unpack 12-bit packed data into 16-bit numpy array"""
    if not payload:
        return np.zeros((HEIGHT, WIDTH), dtype=np.uint16)
    
    # Calculate expected number of pixels
    expected_pixels = HEIGHT * WIDTH
    # Each pixel is 12 bits, so we need 1.5 bytes per pixel
    expected_bytes = expected_pixels * 3 // 2
    
    # Truncate or pad payload to expected size
    if len(payload) < expected_bytes:
        payload = payload + b'\x00' * (expected_bytes - len(payload))
    else:
        payload = payload[:expected_bytes]
    
    # Convert to numpy array
    data = np.frombuffer(payload, dtype=np.uint8)
    
    # Ensure data length is multiple of 3
    remainder = len(data) % 3
    if remainder != 0:
        data = data[:len(data) - remainder]
    
    # Reshape to process 3 bytes at a time
    data = data.reshape(-1, 3)
    
    b0 = data[:, 0].astype(np.uint16)
    b1 = data[:, 1].astype(np.uint16)
    b2 = data[:, 2].astype(np.uint16)
    
    # Standard RAW12 format:
    # Byte 0: pixel 0 bits 11:4
    # Byte 1: pixel 0 bits 3:0 (high nibble) | pixel 1 bits 11:8 (low nibble)
    # Byte 2: pixel 1 bits 7:0
    p0 = (b0 << 4) | ((b1 >> 4) & 0xF)
    p1 = ((b1 & 0xF) << 8) | b2
    
    # Stack pairs of pixels side by side, then flatten
    pixels = np.column_stack((p0, p1)).ravel()
    
    return pixels[:expected_pixels].reshape(HEIGHT, WIDTH)

def convert_raw_to_png(raw_path, output_path, delete_raw=False, verbose=True):
    """Convert a single raw frame to PNG"""
    try:
        # Read raw file
        with open(raw_path, 'rb') as f:
            raw = f.read()
        
        # Unpack the raw data
        img12 = unpack_payload(raw)
        
        # Scale 12-bit (0-4095) to full 16-bit range (0-65535)
        img16 = (img12 << 4).astype(np.uint16)
        
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