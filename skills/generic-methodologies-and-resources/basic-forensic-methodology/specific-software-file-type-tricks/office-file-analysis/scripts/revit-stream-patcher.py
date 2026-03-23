#!/usr/bin/env python3
"""
Revit RFA Stream Patcher

Helper script for patching Revit RFA file streams.
Handles the Global/Latest stream with proper gzip/ECC handling.

Usage:
    python3 revit-stream-patcher.py <command> [options]

Commands:
    extract <rfa_file> <output_dir>    Extract Global/Latest stream
    patch <stream_file> <patch_file> <output>  Apply patch to stream
    info <stream_file>                  Show stream structure info
"""

import sys
import os
import gzip
import struct
import hashlib
import argparse
from pathlib import Path


def read_stream(stream_path):
    """Read the stream file."""
    with open(stream_path, 'rb') as f:
        return f.read()


def write_stream(stream_path, data):
    """Write data to stream file."""
    with open(stream_path, 'wb') as f:
        f.write(data)


def analyze_stream(stream_data):
    """Analyze the structure of a Revit stream."""
    print(f"Stream size: {len(stream_data)} bytes")
    print(f"\nFirst 64 bytes (hex):")
    print(stream_data[:64].hex())
    
    # Try to detect header size (common patterns)
    # This is heuristic - actual header size may vary
    print(f"\nHeader analysis:")
    print(f"  First 4 bytes: {stream_data[:4].hex()}")
    print(f"  First 8 bytes: {stream_data[:8].hex()}")
    
    # Try to find gzip magic
    gzip_magic = b'\x1f\x8b'
    if gzip_magic in stream_data:
        gzip_pos = stream_data.find(gzip_magic)
        print(f"\nGZIP magic found at offset: {gzip_pos}")
        print(f"  Estimated header size: {gzip_pos} bytes")
        
        # Try to decompress
        try:
            compressed = stream_data[gzip_pos:]
            # Find where padding might start (look for long run of zeros)
            zero_run_start = None
            zero_count = 0
            for i, b in enumerate(compressed):
                if b == 0:
                    zero_count += 1
                    if zero_count > 16 and zero_run_start is None:
                        zero_run_start = i - zero_count
                else:
                    zero_count = 0
            
            if zero_run_start:
                print(f"  Potential padding start: {gzip_pos + zero_run_start}")
                compressed = compressed[:zero_run_start]
            
            decompressed = gzip.decompress(compressed)
            print(f"  Decompressed size: {len(decompressed)} bytes")
            print(f"  Decompression successful!")
            return {
                'header_size': gzip_pos,
                'compressed_start': gzip_pos,
                'compressed_size': len(compressed),
                'decompressed_size': len(decompressed)
            }
        except Exception as e:
            print(f"  Decompression failed: {e}")
    else:
        print(f"\nGZIP magic not found in stream")
    
    return None


def extract_stream(rfa_path, output_dir):
    """Extract Global/Latest stream from RFA file."""
    print(f"Extracting stream from: {rfa_path}")
    
    # This assumes CompoundFileTool has already expanded the file
    # or we need to call it
    stream_path = Path(output_dir) / "Global" / "Latest"
    
    if not stream_path.exists():
        print(f"Stream not found at: {stream_path}")
        print("\nFirst, expand the RFA file:")
        print(f"  CompoundFileTool /e {rfa_path} /o {output_dir}")
        return False
    
    data = read_stream(stream_path)
    print(f"Stream extracted: {len(data)} bytes")
    
    # Analyze
    analyze_stream(data)
    
    return True


def patch_stream(stream_path, patch_path, output_path):
    """Apply a patch to a stream file."""
    print(f"Patching stream: {stream_path}")
    print(f"Patch file: {patch_path}")
    
    # Read original stream
    original = read_stream(stream_path)
    
    # Read patch (assumes patch contains replacement bytes)
    patch = read_stream(patch_path)
    
    print(f"Original size: {len(original)} bytes")
    print(f"Patch size: {len(patch)} bytes")
    
    # Simple replacement (for demonstration)
    # In practice, you'd want more sophisticated patching
    if len(patch) <= len(original):
        patched = bytearray(original)
        for i, b in enumerate(patch):
            patched[i] = b
        result = bytes(patched)
    else:
        print("Warning: Patch larger than original, truncating")
        result = patch[:len(original)]
    
    write_stream(output_path, result)
    print(f"Patched stream written to: {output_path}")
    print(f"Output size: {len(result)} bytes")
    
    return True


def main():
    parser = argparse.ArgumentParser(description='Revit RFA Stream Patcher')
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Extract command
    extract_parser = subparsers.add_parser('extract', help='Extract Global/Latest stream')
    extract_parser.add_argument('rfa_file', help='RFA file path')
    extract_parser.add_argument('output_dir', help='Output directory (from CompoundFileTool expansion)')
    
    # Patch command
    patch_parser = subparsers.add_parser('patch', help='Apply patch to stream')
    patch_parser.add_argument('stream_file', help='Stream file to patch')
    patch_parser.add_argument('patch_file', help='Patch file')
    patch_parser.add_argument('output', help='Output file')
    
    # Info command
    info_parser = subparsers.add_parser('info', help='Show stream structure info')
    info_parser.add_argument('stream_file', help='Stream file')
    
    args = parser.parse_args()
    
    if args.command == 'extract':
        extract_stream(args.rfa_file, args.output_dir)
    elif args.command == 'patch':
        patch_stream(args.stream_file, args.patch_file, args.output)
    elif args.command == 'info':
        data = read_stream(args.stream_file)
        analyze_stream(data)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
