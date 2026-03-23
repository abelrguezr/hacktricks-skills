#!/usr/bin/env python3
"""
Registry Key Extractor for Forensic Analysis

Extracts specific forensic-relevant keys from Windows Registry hives.

Usage:
    python extract-registry-keys.py --hive SYSTEM --keys usb,runkeys --output extracted.json
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional

# Forensic registry paths organized by category
FORENSIC_PATHS = {
    "system_info": [
        "Software\\Microsoft\\Windows NT\\CurrentVersion",
        "System\\ControlSet001\\Control\\ComputerName\\ComputerName",
        "System\\ControlSet001\\Control\\TimeZoneInformation",
        "System\\ControlSet001\\Control\\Windows",
    ],
    "usb_history": [
        "System\\ControlSet001\\Enum\\USBSTOR",
        "System\\ControlSet001\\Enum\\USB",
        "System\\MountedDevices",
        "Software\\Microsoft\\Windows NT\\CurrentVersion\\EMDMgmt",
    ],
    "user_activity": [
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\RecentDocs",
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\TypedPaths",
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\UserAssist",
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\ComDlg32",
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\Shell",
    ],
    "persistence": [
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\CurrentVersion\\Run",
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        "Software\\Microsoft\\Windows\\CurrentVersion\\Run",
        "Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce",
        "Software\\Microsoft\\Windows NT\\CurrentVersion\\Windows",
        "Software\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon",
    ],
    "network": [
        "System\\ControlSet001\\Services\\Tcpip\\Parameters\\Interfaces",
        "Software\\Microsoft\\Windows NT\\CurrentVersion\\NetworkList",
    ],
    "shellbags": [
        "NTUSER.DAT\\Software\\Microsoft\\Windows\\Shell",
        "USRCLASS.DAT\\Software\\Microsoft\\Windows\\Shell",
    ],
}


def get_forensic_paths(key_filter: Optional[str] = None) -> Dict[str, List[str]]:
    """
    Get forensic registry paths, optionally filtered by category.
    
    Args:
        key_filter: Category to filter by (usb_history, persistence, etc.)
    
    Returns:
        Dictionary of category to paths
    """
    if key_filter:
        if key_filter in FORENSIC_PATHS:
            return {key_filter: FORENSIC_PATHS[key_filter]}
        else:
            print(f"Warning: Unknown key filter '{key_filter}'. Available filters:")
            for k in FORENSIC_PATHS.keys():
                print(f"  - {k}")
            return FORENSIC_PATHS
    return FORENSIC_PATHS


def extract_keys_from_hive(
    hive_path: str,
    key_filter: Optional[str] = None
) -> Dict[str, Any]:
    """
    Extract forensic keys from a registry hive.
    
    Args:
        hive_path: Path to the registry hive file
        key_filter: Optional category filter
    
    Returns:
        Dictionary containing extracted data
    """
    result = {
        "hive_path": hive_path,
        "extraction_time": datetime.now().isoformat(),
        "paths_checked": [],
        "data": {},
        "errors": [],
        "warnings": []
    }
    
    # Validate hive file
    if not os.path.exists(hive_path):
        result["errors"].append(f"Hive file not found: {hive_path}")
        return result
    
    result["file_size"] = os.path.getsize(hive_path)
    
    # Get paths to check
    paths_to_check = get_forensic_paths(key_filter)
    
    # Record which paths we're checking
    for category, paths in paths_to_check.items():
        result["paths_checked"].append({
            "category": category,
            "paths": paths
        })
    
    # In a real implementation, this would parse the registry hive
    # For now, we document what would be extracted
    result["extraction_notes"] = [
        "This script documents the forensic paths to check.",
        "For actual extraction, use regipy or similar registry parsing library.",
        "Key categories available: system_info, usb_history, user_activity, persistence, network, shellbags"
    ]
    
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Extract forensic keys from Windows Registry hives",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Key Categories:
  system_info     - Windows version, computer name, timezone
  usb_history     - USB device connection history
  user_activity   - Recent docs, typed paths, user assist
  persistence     - Run keys, startup programs
  network         - Network interfaces, connection history
  shellbags       - Folder access history

Examples:
  python extract-registry-keys.py --hive SYSTEM --keys usb_history --output usb.json
  python extract-registry-keys.py --hive NTUSER.DAT --keys persistence --output persistence.json
  python extract-registry-keys.py --hive SYSTEM --output all-keys.json
        """
    )
    
    parser.add_argument(
        "--hive", "-H",
        required=True,
        help="Path to the registry hive file"
    )
    
    parser.add_argument(
        "--keys", "-k",
        help="Category of keys to extract (usb_history, persistence, etc.)"
    )
    
    parser.add_argument(
        "--output", "-o",
        required=True,
        help="Output JSON file path"
    )
    
    parser.add_argument(
        "--list-categories",
        action="store_true",
        help="List available key categories and exit"
    )
    
    args = parser.parse_args()
    
    # List categories if requested
    if args.list_categories:
        print("Available key categories:")
        for category in FORENSIC_PATHS.keys():
            print(f"\n  {category}:")
            for path in FORENSIC_PATHS[category]:
                print(f"    - {path}")
        sys.exit(0)
    
    # Extract keys
    result = extract_keys_from_hive(args.hive, args.keys)
    
    # Write output
    try:
        with open(args.output, 'w') as f:
            json.dump(result, f, indent=2)
        print(f"Successfully wrote output to: {args.output}")
    except Exception as e:
        print(f"Error writing output: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Print summary
    print(f"\nExtraction Summary:")
    print(f"  Hive: {args.hive}")
    print(f"  Categories checked: {len(result['paths_checked'])}")
    
    for item in result["paths_checked"]:
        print(f"    - {item['category']}: {len(item['paths'])} paths")
    
    if result.get("errors"):
        print(f"\nErrors:")
        for err in result["errors"]:
            print(f"  - {err}")
    
    if result.get("extraction_notes"):
        print(f"\nNotes:")
        for note in result["extraction_notes"]:
            print(f"  - {note}")


if __name__ == "__main__":
    main()
