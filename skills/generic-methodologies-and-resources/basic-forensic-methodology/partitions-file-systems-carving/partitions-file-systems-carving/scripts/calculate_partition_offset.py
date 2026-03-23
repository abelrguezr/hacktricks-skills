#!/usr/bin/env python3
"""
Calculate partition offset for mounting from fdisk output
Usage: python calculate_partition_offset.py <start_sector>
"""

import sys

def calculate_offset(start_sector):
    """Calculate byte offset from sector number."""
    SECTOR_SIZE = 512
    offset = start_sector * SECTOR_SIZE
    return offset

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <start_sector>")
        print(f"\nExample: {sys.argv[0]} 2048")
        print(f"         {sys.argv[0]} 63")
        sys.exit(1)
    
    try:
        start_sector = int(sys.argv[1])
    except ValueError:
        print(f"Error: Invalid sector number: {sys.argv[1]}")
        sys.exit(1)
    
    offset = calculate_offset(start_sector)
    
    print(f"\nPartition Offset Calculation")
    print("=" * 40)
    print(f"Start Sector: {start_sector}")
    print(f"Sector Size: 512 bytes")
    print(f"Byte Offset: {offset}")
    print(f"\nMount command:")
    print(f"  mount -o ro,loop,offset={offset} <image> /mnt/forensics")
    print(f"\nOr with noatime:")
    print(f"  mount -o ro,loop,offset={offset},noatime <image> /mnt/forensics")

if __name__ == "__main__":
    main()
