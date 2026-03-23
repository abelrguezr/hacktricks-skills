#!/usr/bin/env python3
"""
Enumerate Forwarded Exports in Windows DLLs
For authorized security research and detection engineering

Usage: python enumerate_forwarded_exports.py <dll_path>
       python enumerate_forwarded_exports.py --system
"""

import argparse
import os
import sys
import subprocess
from pathlib import Path

def run_dumpbin(dll_path):
    """Run dumpbin to get exports from a DLL"""
    try:
        result = subprocess.run(
            ['dumpbin', '/exports', dll_path],
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout
    except FileNotFoundError:
        print("Error: dumpbin not found. Install Windows SDK.")
        return None
    except subprocess.TimeoutExpired:
        print(f"Error: Timeout analyzing {dll_path}")
        return None

def parse_exports(output):
    """Parse dumpbin output for forwarded exports"""
    forwarded = []
    lines = output.split('\n')
    
    for line in lines:
        # Look for forwarder strings (contain a dot)
        if '.' in line and 'forward' in line.lower():
            parts = line.split()
            if len(parts) >= 4:
                ordinal = parts[1]
                name = parts[3] if len(parts) > 3 else ''
                forwarder = ' '.join(parts[4:]) if len(parts) > 4 else ''
                
                if forwarder and '.' in forwarder:
                    forwarded.append({
                        'ordinal': ordinal,
                        'name': name,
                        'forwarder': forwarder
                    })
    
    return forwarded

def check_known_dll(target_dll):
    """Check if target DLL is a KnownDLL"""
    known_dlls = [
        'ntdll.dll', 'kernel32.dll', 'kernelbase.dll', 'user32.dll',
        'gdi32.dll', 'advapi32.dll', 'ole32.dll', 'shell32.dll',
        'msvcrt.dll', 'rpcrt4.dll', 'combase.dll', 'bcrypt.dll'
    ]
    return target_dll.lower() in [dll.lower() for dll in known_dlls]

def analyze_dll(dll_path):
    """Analyze a single DLL for forwarded exports"""
    print(f"\n{'='*60}")
    print(f"Analyzing: {dll_path}")
    print('='*60)
    
    output = run_dumpbin(dll_path)
    if not output:
        return
    
    forwarded = parse_exports(output)
    
    if not forwarded:
        print("No forwarded exports found.")
        return
    
    print(f"\nFound {len(forwarded)} forwarded export(s):")
    print("-" * 60)
    
    for fwd in forwarded:
        target = fwd['forwarder'].split('.')[0]
        is_known = check_known_dll(target)
        risk = "HIGH" if not is_known else "LOW"
        
        print(f"\nExport: {fwd['name']} (Ordinal: {fwd['ordinal']})")
        print(f"  Forwarder: {fwd['forwarder']}")
        print(f"  Target DLL: {target}")
        print(f"  KnownDLL: {is_known}")
        print(f"  Risk Level: {risk}")
    
    return forwarded

def scan_system_dlls():
    """Scan System32 for DLLs with forwarded exports"""
    system32 = Path(r"C:\Windows\System32")
    
    if not system32.exists():
        print("System32 not found. Are you on Windows?")
        return
    
    print("Scanning System32 for forwarded exports...")
    print("This may take several minutes.")
    
    all_forwarded = []
    dll_count = 0
    
    for dll in system32.glob("*.dll"):
        dll_count += 1
        if dll_count % 100 == 0:
            print(f"  Scanned {dll_count} DLLs...")
        
        forwarded = analyze_dll(str(dll))
        if forwarded:
            all_forwarded.extend(forwarded)
    
    print(f"\n{'='*60}")
    print(f"Summary: {len(all_forwarded)} forwarded exports found")
    print(f"Total DLLs scanned: {dll_count}")
    print('='*60)

def main():
    parser = argparse.ArgumentParser(
        description='Enumerate forwarded exports in Windows DLLs'
    )
    parser.add_argument(
        'dll_path',
        nargs='?',
        help='Path to DLL to analyze'
    )
    parser.add_argument(
        '--system',
        action='store_true',
        help='Scan all System32 DLLs'
    )
    
    args = parser.parse_args()
    
    if args.system:
        scan_system_dlls()
    elif args.dll_path:
        if not os.path.exists(args.dll_path):
            print(f"Error: File not found: {args.dll_path}")
            sys.exit(1)
        analyze_dll(args.dll_path)
    else:
        parser.print_help()
        print("\nNote: This tool is for authorized security research only.")

if __name__ == '__main__':
    main()
