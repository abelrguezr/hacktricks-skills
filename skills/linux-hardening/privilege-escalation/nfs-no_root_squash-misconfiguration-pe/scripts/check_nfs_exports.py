#!/usr/bin/env python3
"""
check_nfs_exports - Analyze NFS exports for privilege escalation opportunities

Usage:
    ./check_nfs_exports.py <exports_file>
    ./check_nfs_exports.py /etc/exports

This script parses /etc/exports and identifies:
- Shares with no_root_squash (root privilege escalation)
- Shares with insecure flag (local libnfs exploitation)
- Shares accessible to specific IPs
"""

import sys
import re
from pathlib import Path


def parse_exports(filepath):
    """
    Parse /etc/exports file and extract share configurations.
    
    Returns a list of dicts with share info.
    """
    exports = []
    
    try:
        with open(filepath, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: File not found: {filepath}")
        sys.exit(1)
    except PermissionError:
        print(f"Error: Permission denied: {filepath}")
        sys.exit(1)
    
    # Remove comments and empty lines
    lines = []
    for line in content.split('\n'):
        line = line.strip()
        if line and not line.startswith('#'):
            lines.append(line)
    
    # Parse each export line
    for line in lines:
        # Split on first space/tab
        parts = line.split(None, 1)
        if len(parts) < 2:
            continue
        
        share_path = parts[0]
        options_str = parts[1]
        
        # Remove parentheses
        options_str = options_str.replace('(', '').replace(')', '')
        
        # Parse options
        options = {}
        for opt in options_str.split():
            if '=' in opt:
                key, value = opt.split('=', 1)
                options[key] = value
            else:
                options[opt] = True
        
        exports.append({
            'path': share_path,
            'options': options,
            'raw': line
        })
    
    return exports


def analyze_exports(exports):
    """
    Analyze exports for privilege escalation opportunities.
    """
    results = {
        'no_root_squash': [],
        'insecure': [],
        'all_squash': [],
        'root_squash': [],
        'others': []
    }
    
    for export in exports:
        options = export['options']
        
        if 'no_root_squash' in options:
            results['no_root_squash'].append(export)
        elif 'all_squash' in options:
            results['all_squash'].append(export)
        elif 'root_squash' in options:
            results['root_squash'].append(export)
        else:
            # Default is root_squash
            results['root_squash'].append(export)
        
        if 'insecure' in options:
            results['insecure'].append(export)
        
        if export not in results['no_root_squash'] and \
           export not in results['all_squash'] and \
           export not in results['root_squash']:
            results['others'].append(export)
    
    return results


def print_results(results):
    """
    Print analysis results in a readable format.
    """
    print("\n" + "="*60)
    print("NFS EXPORTS PRIVILEGE ESCALATION ANALYSIS")
    print("="*60)
    
    # CRITICAL: no_root_squash
    if results['no_root_squash']:
        print("\n[CRITICAL] Shares with no_root_squash (ROOT PRIVILEGE ESCALATION):")
        print("-"*60)
        for export in results['no_root_squash']:
            print(f"  Path: {export['path']}")
            print(f"  Options: {export['raw']}")
            print(f"  Exploitation: Remote mount + SUID binary")
            print()
    else:
        print("\n[OK] No shares with no_root_squash found")
    
    # HIGH: insecure flag
    if results['insecure']:
        print("\n[HIGH] Shares with insecure flag (LOCAL EXPLOITATION):")
        print("-"*60)
        for export in results['insecure']:
            print(f"  Path: {export['path']}")
            print(f"  Options: {export['raw']}")
            print(f"  Exploitation: libnfs + LD_PRELOAD")
            print()
    else:
        print("\n[OK] No shares with insecure flag found")
    
    # INFO: all_squash
    if results['all_squash']:
        print("\n[INFO] Shares with all_squash (all users mapped to nobody):")
        print("-"*60)
        for export in results['all_squash']:
            print(f"  Path: {export['path']}")
            print(f"  Options: {export['raw']}")
        print()
    
    # INFO: root_squash (default)
    if results['root_squash']:
        print("\n[INFO] Shares with root_squash (default, root mapped to nobody):")
        print("-"*60)
        for export in results['root_squash']:
            print(f"  Path: {export['path']}")
            print(f"  Options: {export['raw']}")
        print()
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"  Total shares analyzed: {len(results['no_root_squash']) + len(results['all_squash']) + len(results['root_squash'])}")
    print(f"  Critical (no_root_squash): {len(results['no_root_squash'])}")
    print(f"  High (insecure): {len(results['insecure'])}")
    print(f"  Medium (all_squash): {len(results['all_squash'])}")
    print(f"  Low (root_squash): {len(results['root_squash'])}")
    print("="*60 + "\n")


def main():
    if len(sys.argv) < 2:
        print("Usage: check_nfs_exports.py <exports_file>")
        print("Example: ./check_nfs_exports.py /etc/exports")
        sys.exit(1)
    
    filepath = sys.argv[1]
    
    # Parse exports
    exports = parse_exports(filepath)
    
    if not exports:
        print("No NFS exports found in file.")
        sys.exit(0)
    
    # Analyze
    results = analyze_exports(exports)
    
    # Print results
    print_results(results)


if __name__ == "__main__":
    main()
