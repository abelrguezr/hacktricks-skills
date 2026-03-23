#!/usr/bin/env python3
"""Detect overlapping entry bombs in ZIP files.

Usage:
    python3 detect_overlaps.py file.zip

Modern zip bombs reuse a highly compressed kernel via overlapping local
headers. Every central directory entry points to the same compressed data,
achieving extreme compression ratios (>28M:1) without nesting.
"""
import struct
import sys

def detect_overlaps(zip_path: str) -> tuple[bool, int, set[int]]:
    """Check for duplicate relative offsets in central directory.
    
    Args:
        zip_path: Path to ZIP file
        
    Returns:
        Tuple of (has_overlaps, total_entries, duplicate_offsets)
    """
    try:
        buf = open(zip_path, 'rb').read()
    except FileNotFoundError:
        print(f"Error: File not found: {zip_path}")
        sys.exit(1)
    except IOError as e:
        print(f"Error reading file: {e}")
        sys.exit(1)
    
    seen = set()
    duplicates = set()
    off = 0
    total_entries = 0
    
    # Search for Central Directory Headers (PK\x01\x02)
    while True:
        i = buf.find(b'PK\x01\x02', off)
        if i < 0:
            break
        
        total_entries += 1
        
        # Relative offset of local header is at +42 from CDH signature
        try:
            rel = struct.unpack_from('<I', buf, i + 42)[0]
        except struct.error:
            print(f"Warning: Malformed header at offset {i}")
            off = i + 4
            continue
        
        if rel in seen:
            duplicates.add(rel)
        else:
            seen.add(rel)
        
        off = i + 4
    
    has_overlaps = len(duplicates) > 0
    return has_overlaps, total_entries, duplicates

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} file.zip")
        sys.exit(1)
    
    zip_path = sys.argv[1]
    has_overlaps, total_entries, duplicates = detect_overlaps(zip_path)
    
    print(f"ZIP: {zip_path}")
    print(f"Total central directory entries: {total_entries}")
    
    if has_overlaps:
        print(f"\n⚠️  WARNING: Overlapping entries detected!")
        print(f"   Duplicate offsets: {len(duplicates)}")
        print(f"   This may be a zip bomb or malicious archive.")
        print(f"\nDuplicate relative offsets:")
        for offset in sorted(duplicates)[:10]:  # Show first 10
            print(f"   - Offset 0x{offset:08x}")
        if len(duplicates) > 10:
            print(f"   ... and {len(duplicates) - 10} more")
        
        print(f"\nRecommendations:")
        print(f"  1. Do NOT extract without limits")
        print(f"  2. Use zipdetails -v to inspect uncompressed sizes")
        print(f"  3. Extract in a VM/cgroup with CPU+disk limits")
        print(f"  4. Cap total uncompressed size before extraction")
    else:
        print(f"\n✓ No overlapping entries detected.")
        print(f"  All {total_entries} entries have unique offsets.")

if __name__ == '__main__':
    main()
