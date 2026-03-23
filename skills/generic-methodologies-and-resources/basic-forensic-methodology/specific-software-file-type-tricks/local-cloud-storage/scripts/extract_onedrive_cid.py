#!/usr/bin/env python3
"""
Extract CID (Customer ID) from OneDrive SyncDiagnostics.log

Usage:
    python extract_onedrive_cid.py <path-to-SyncDiagnostics.log>

The CID is a unique identifier for the OneDrive user account.
Once extracted, search for files containing this ID (e.g., <CID>.ini, <CID>.dat)
"""

import re
import sys
import argparse
from pathlib import Path


def extract_cid(log_path: str) -> list[str]:
    """
    Extract CID values from OneDrive SyncDiagnostics.log
    
    Args:
        log_path: Path to SyncDiagnostics.log file
        
    Returns:
        List of CID strings found in the log
    """
    cid_pattern = re.compile(r'CID[:\s]+([A-F0-9]{32})', re.IGNORECASE)
    
    cids = []
    log_file = Path(log_path)
    
    if not log_file.exists():
        print(f"Error: File not found: {log_path}", file=sys.stderr)
        sys.exit(1)
    
    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
        for line_num, line in enumerate(f, 1):
            matches = cid_pattern.findall(line)
            for cid in matches:
                cids.append(cid)
                print(f"Line {line_num}: CID = {cid}")
    
    return cids


def extract_all_metadata(log_path: str) -> dict:
    """
    Extract all available metadata from SyncDiagnostics.log
    
    Returns:
        Dictionary with all extracted metadata fields
    """
    metadata = {
        'cid': None,
        'size_bytes': None,
        'creation_date': None,
        'modification_date': None,
        'files_in_cloud': None,
        'files_in_folder': None,
        'report_time': None,
        'hd_size': None
    }
    
    patterns = {
        'cid': re.compile(r'CID[:\s]+([A-F0-9]{32})', re.IGNORECASE),
        'size_bytes': re.compile(r'Size[:\s]+(\d+)', re.IGNORECASE),
        'creation_date': re.compile(r'Creation Date[:\s]+([\d\-\sT:]+)', re.IGNORECASE),
        'modification_date': re.compile(r'Modification Date[:\s]+([\d\-\sT:]+)', re.IGNORECASE),
        'files_in_cloud': re.compile(r'Files in Cloud[:\s]+(\d+)', re.IGNORECASE),
        'files_in_folder': re.compile(r'Files in Folder[:\s]+(\d+)', re.IGNORECASE),
        'report_time': re.compile(r'Report Time[:\s]+([\d\-\sT:]+)', re.IGNORECASE),
        'hd_size': re.compile(r'HD Size[:\s]+(\d+)', re.IGNORECASE)
    }
    
    log_file = Path(log_path)
    
    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
        for field, pattern in patterns.items():
            match = pattern.search(content)
            if match:
                metadata[field] = match.group(1)
    
    return metadata


def main():
    parser = argparse.ArgumentParser(
        description='Extract CID and metadata from OneDrive SyncDiagnostics.log'
    )
    parser.add_argument(
        'log_path',
        help='Path to SyncDiagnostics.log file'
    )
    parser.add_argument(
        '--all', '-a',
        action='store_true',
        help='Extract all metadata, not just CID'
    )
    
    args = parser.parse_args()
    
    if args.all:
        metadata = extract_all_metadata(args.log_path)
        print("\n=== OneDrive SyncDiagnostics.log Metadata ===")
        for key, value in metadata.items():
            print(f"{key.replace('_', ' ').title()}: {value}")
    else:
        cids = extract_cid(args.log_path)
        if not cids:
            print("No CID found in log file.", file=sys.stderr)
            sys.exit(1)
        
        print(f"\nFound {len(cids)} CID(s)")
        print("\nSearch for these files on the system:")
        for cid in cids:
            print(f"  - {cid}.ini")
            print(f"  - {cid}.dat")


if __name__ == '__main__':
    main()
