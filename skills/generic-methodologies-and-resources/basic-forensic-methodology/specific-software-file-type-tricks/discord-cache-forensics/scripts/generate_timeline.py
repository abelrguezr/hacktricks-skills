#!/usr/bin/env python3
"""Generate timeline from Discord cache file modification times."""

import os
import sys
import argparse
from pathlib import Path
from datetime import datetime
import csv


def get_file_info(file_path):
    """Get file metadata including timestamp and size."""
    try:
        stat = file_path.stat()
        return {
            "timestamp": datetime.fromtimestamp(stat.st_mtime).isoformat(),
            "file_path": str(file_path),
            "file_name": file_path.name,
            "file_size": stat.st_size,
            "file_type": "f_entry" if file_path.name.startswith('f_') else "data_block" if file_path.name.startswith('data_') else "other"
        }
    except Exception as e:
        return None


def main():
    parser = argparse.ArgumentParser(description='Generate timeline from Discord cache files')
    parser.add_argument('--cache', required=True, help='Path to Cache_Data directory')
    parser.add_argument('--output', required=True, help='Output CSV file path')
    parser.add_argument('--include-subdirs', action='store_true', help='Include files in subdirectories')
    args = parser.parse_args()
    
    cache_dir = Path(args.cache)
    output_file = Path(args.output)
    
    if not cache_dir.exists():
        print(f"Error: Cache directory not found: {cache_dir}")
        sys.exit(1)
    
    print(f"Generating timeline from: {cache_dir}")
    print(f"Output file: {output_file}")
    print()
    
    # Collect all files
    if args.include_subdirs:
        files = cache_dir.rglob('*')
    else:
        files = cache_dir.glob('*')
    
    entries = []
    for file_path in files:
        if file_path.is_file():
            info = get_file_info(file_path)
            if info:
                entries.append(info)
    
    # Sort by timestamp
    entries.sort(key=lambda x: x['timestamp'])
    
    # Write CSV
    output_file.parent.mkdir(parents=True, exist_ok=True)
    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['timestamp', 'file_path', 'file_name', 'file_size', 'file_type'])
        writer.writeheader()
        writer.writerows(entries)
    
    print(f"Timeline saved to: {output_file}")
    print(f"Total entries: {len(entries)}")
    
    # Summary by file type
    f_entries = [e for e in entries if e['file_type'] == 'f_entry']
    data_entries = [e for e in entries if e['file_type'] == 'data_block']
    
    print(f"\n=== Timeline Summary ===")
    print(f"f_* entries: {len(f_entries)}")
    print(f"data_* blocks: {len(data_entries)}")
    
    if entries:
        print(f"\nTime range:")
        print(f"  First: {entries[0]['timestamp']} ({entries[0]['file_name']})")
        print(f"  Last:  {entries[-1]['timestamp']} ({entries[-1]['file_name']})")
    
    # Show recent activity (last 10 entries)
    if entries:
        print(f"\nMost recent activity (last 10):")
        for entry in entries[-10:]:
            print(f"  {entry['timestamp']} - {entry['file_name']} ({entry['file_size']} bytes)")


if __name__ == '__main__':
    main()
