#!/usr/bin/env python3
import numpy as np
import sys
import argparse
from pathlib import Path

# Configuration for the custom hardware format
WIDTH = 4512
HEIGHT = 4581
ROW_PADDING = 16

# Each row has WIDTH pixels = 4512 pixels
# 4512 pixels / 8 pixels per group = 564 groups per row
# Each group is 3 words = 12 bytes
# So each row is 564 * 12 = 6768 bytes of data + 16 bytes padding
DATA_CHUNK = 6768
PAD_CHUNK = 16
BLOCK_SIZE = DATA_CHUNK + PAD_CHUNK


def remove_padding(raw_bytes):
    """Remove row padding from raw frame data"""
    out = bytearray()
    for i in range(0, len(raw_bytes), BLOCK_SIZE):
        out.extend(raw_bytes[i:i+DATA_CHUNK])
    return out


def fix_custom_raw12_bytes(data_bytes):
    """Convert custom hardware RAW12 format to standard RAW12 format"""
    words = np.frombuffer(data_bytes, dtype='>u4')  # Big-endian 32-bit words

    if len(words) % 3 != 0:
        raise ValueError("After padding removal, data is not multiple of 96-bit blocks")

    out = bytearray()

    for i in range(0, len(words), 3):
        w0 = int(words[i])
        w1 = int(words[i+1])
        w2 = int(words[i+2])

        # Extract 8 pixels from 3 words (custom hardware mapping)
        p0 = (w0 >> 0)  & 0xFFF
        p1 = (w0 >> 12) & 0xFFF
        p2 = ((w0 >> 24) & 0xFF) | ((w1 & 0xF) << 8)

        p3 = (w1 >> 4)  & 0xFFF
        p4 = (w1 >> 16) & 0xFFF
        p5 = ((w1 >> 28) & 0xF) | ((w2 & 0xFF) << 4)

        p6 = (w2 >> 8)  & 0xFFF
        p7 = (w2 >> 20) & 0xFFF

        pixels = [p0, p1, p2, p3, p4, p5, p6, p7]

        # Pack into standard RAW12 format (2 pixels per 3 bytes)
        for j in range(0, 8, 2):
            a = pixels[j]
            b = pixels[j+1]
            out.append((a >> 4) & 0xFF)                      # byte 0: pixel 0 bits 11:4
            out.append(((a & 0xF) << 4) | ((b >> 8) & 0xF))  # byte 1: pixel 0 bits 3:0 | pixel 1 bits 11:8
            out.append(b & 0xFF)                             # byte 2: pixel 1 bits 7:0

    return out


def convert_file(input_path, output_path, verbose=True):
    """Convert a single unaligned RAW12 file to aligned RAW12"""
    try:
        with open(input_path, "rb") as f:
            raw = f.read()

        if verbose:
            print(f"Processing {input_path}...")
            print(f"  Input size: {len(raw)} bytes")

        # Remove stride padding
        no_pad = remove_padding(raw)
        if verbose:
            print(f"  After padding removal: {len(no_pad)} bytes")

        # Fix pixel alignment
        fixed = fix_custom_raw12_bytes(no_pad)
        if verbose:
            print(f"  Output size: {len(fixed)} bytes")

        # Write output
        with open(output_path, "wb") as f:
            f.write(fixed)

        if verbose:
            print(f"  [OK] Written to {output_path}")

        return True

    except Exception as e:
        print(f"[ERROR] Failed to convert {input_path}: {e}")
        return False


def batch_convert(input_dir, output_dir, pattern="*.raw"):
    """Convert all raw files in a directory"""
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    
    # Create output directory
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Find all raw files
    raw_files = sorted(input_path.glob(pattern))
    
    if not raw_files:
        print(f"No raw files found in {input_dir}")
        return
    
    print(f"Found {len(raw_files)} raw files to convert")
    print(f"Output directory: {output_dir}\n")
    
    success_count = 0
    for raw_file in raw_files:
        output_file = output_path / raw_file.name
        if convert_file(str(raw_file), str(output_file), verbose=False):
            success_count += 1
            print(f"[OK] {raw_file.name}")
    
    print(f"\n[DONE] Converted {success_count}/{len(raw_files)} files")


def main():
    parser = argparse.ArgumentParser(
        description="Convert custom hardware RAW12 format to standard RAW12 format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Convert single file
  python unaligned_to_aligned.py input.raw output.raw
  
  # Convert all files in directory
  python unaligned_to_aligned.py --input-dir raw_frames --output-dir aligned_frames
        """
    )
    
    parser.add_argument("input", nargs="?", help="Input raw file")
    parser.add_argument("output", nargs="?", help="Output raw file")
    parser.add_argument("--input-dir", help="Input directory for batch conversion")
    parser.add_argument("--output-dir", help="Output directory for batch conversion")
    parser.add_argument("--pattern", default="*.raw", help="File pattern to match (default: *.raw)")
    
    args = parser.parse_args()
    
    if args.input_dir and args.output_dir:
        # Batch mode
        batch_convert(args.input_dir, args.output_dir, args.pattern)
    elif args.input and args.output:
        # Single file mode
        convert_file(args.input, args.output)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()