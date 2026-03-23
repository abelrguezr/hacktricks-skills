#!/usr/bin/env python3
"""
Find MIG-based services on macOS system.

Usage:
    python find_mig_services.py [directory]

Searches for binaries that use MIG IPC.
"""

import subprocess
import sys
from pathlib import Path


def check_binary_uses_mig(binary_path):
    """Check if a binary uses MIG."""
    try:
        result = subprocess.run(
            ['jtool2', '-S', str(binary_path)],
            capture_output=True,
            text=True,
            timeout=5
        )
        output = result.stdout
        return '_NDR_record' in output or '__mach_msg' in output
    except:
        return False


def extract_bootstrap_names(binary_path):
    """Extract potential bootstrap service names from binary."""
    try:
        result = subprocess.run(
            ['strings', str(binary_path)],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        # Look for bootstrap-like service names
        # Pattern: domain.service or com.domain.service
        names = []
        for line in result.stdout.split('\n'):
            if len(line) > 5 and len(line) < 100:
                # Check if it looks like a service name
                if ('.' in line and 
                    line.replace('.', '').replace('-', '').replace('_', '').isalnum() and
                    not line.startswith('/') and
                    not line.startswith('http')):
                    names.append(line)
        
        return list(set(names))[:10]  # Return unique, limit to 10
    except:
        return []


def scan_directory(directory):
    """Scan directory for MIG binaries."""
    dir_path = Path(directory)
    if not dir_path.exists():
        print(f"Error: Directory not found: {directory}")
        sys.exit(1)
    
    print(f"Scanning: {directory}")
    print("=" * 60)
    
    mig_binaries = []
    
    # Scan common system directories
    for binary in dir_path.rglob('*'):
        if binary.is_file() and binary.suffix == '':
            try:
                if check_binary_uses_mig(binary):
                    names = extract_bootstrap_names(binary)
                    mig_binaries.append({
                        'path': str(binary),
                        'service_names': names
                    })
            except:
                continue
    
    return mig_binaries


def main():
    if len(sys.argv) < 2:
        print("Usage: python find_mig_services.py <directory>")
        print("\nExample directories:")
        print("  /System/Library/PrivateFrameworks")
        print("  /usr/libexec")
        print("  /usr/sbin")
        sys.exit(1)
    
    directory = sys.argv[1]
    
    print("\nSearching for MIG-based services...")
    print("This may take a while.\n")
    
    binaries = scan_directory(directory)
    
    if not binaries:
        print("No MIG binaries found in this directory.")
        return
    
    print(f"\nFound {len(binaries)} MIG binaries:\n")
    
    for i, binary in enumerate(binaries[:20], 1):  # Limit to 20
        print(f"{i}. {binary['path']}")
        if binary['service_names']:
            print(f"   Potential service names: {', '.join(binary['service_names'][:3])}")
        print()
    
    if len(binaries) > 20:
        print(f"... and {len(binaries) - 20} more")
    
    print("\n" + "=" * 60)
    print("\nTo analyze a specific binary:")
    print("  python extract_mig_dispatch.py <binary_path>")


if __name__ == '__main__':
    main()
