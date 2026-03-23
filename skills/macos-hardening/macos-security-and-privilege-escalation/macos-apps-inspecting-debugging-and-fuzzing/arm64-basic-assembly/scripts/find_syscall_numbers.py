#!/usr/bin/env python3
"""
Find macOS syscall numbers from libsystem_kernel.dylib or syscall.h

Usage:
    python find_syscall_numbers.py
    python find_syscall_numbers.py --search=exec
    python find_syscall_numbers.py --search=socket
"""

import subprocess
import sys
import re
import argparse


def get_syscall_from_header():
    """Parse syscall.h for BSD syscall numbers."""
    header_path = "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/sys/syscall.h"
    
    try:
        with open(header_path, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Warning: {header_path} not found", file=sys.stderr)
        return {}
    
    syscalls = {}
    # Match: #define SYS_execve 59
    pattern = r'#define\s+SYS_(\w+)\s+(\d+)'
    for match in re.finditer(pattern, content):
        name = match.group(1)
        number = int(match.group(2))
        syscalls[name] = number
    
    return syscalls


def get_syscall_from_dylib(dylib_path: str = None):
    """Extract syscall information from libsystem_kernel.dylib."""
    if dylib_path is None:
        # Try common paths
        paths = [
            "/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e",
            "/System/Library/dyld/dyld_shared_cache_arm64e",
        ]
        for p in paths:
            if subprocess.run(["test", "-f", p], capture_output=True).returncode == 0:
                dylib_path = p
                break
    
    if dylib_path is None:
        print("Error: Could not find dyld shared cache", file=sys.stderr)
        return {}
    
    # Use otool to list symbols
    result = subprocess.run(
        ["otool", "-tv", dylib_path],
        capture_output=True,
        text=True
    )
    
    # This is a simplified extraction - in practice you'd want to parse
    # the actual syscall table
    return {}


def search_syscalls(syscalls: dict, search_term: str):
    """Search syscalls by name."""
    results = {}
    search_lower = search_term.lower()
    for name, number in syscalls.items():
        if search_lower in name.lower():
            results[name] = number
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Find macOS syscall numbers"
    )
    parser.add_argument(
        "--search", "-s",
        help="Search for syscalls containing this term"
    )
    parser.add_argument(
        "--all", "-a",
        action="store_true",
        help="Show all syscalls"
    )
    
    args = parser.parse_args()
    
    # Get syscalls from header
    syscalls = get_syscall_from_header()
    
    if not syscalls:
        print("No syscalls found. Make sure Xcode Command Line Tools are installed.", file=sys.stderr)
        print("Run: xcode-select --install", file=sys.stderr)
        sys.exit(1)
    
    # Filter if search term provided
    if args.search:
        syscalls = search_syscalls(syscalls, args.search)
    
    # Display results
    if not syscalls:
        print("No matching syscalls found.")
        sys.exit(0)
    
    print(f"Found {len(syscalls)} syscall(s):")
    print()
    print(f"{'Number':<10} {'Name':<30} {'Description'}")
    print("-" * 60)
    
    # Sort by number
    for name, number in sorted(syscalls.items(), key=lambda x: x[1]):
        # Add common descriptions
        desc = ""
        if name == "exit":
            desc = "Exit process"
        elif name == "fork":
            desc = "Fork process"
        elif name == "execve":
            desc = "Execute program"
        elif name == "socket":
            desc = "Create socket"
        elif name == "connect":
            desc = "Connect socket"
        elif name == "bind":
            desc = "Bind socket"
        elif name == "listen":
            desc = "Listen on socket"
        elif name == "accept":
            desc = "Accept connection"
        elif name == "dup":
            desc = "Duplicate file descriptor"
        elif name == "read":
            desc = "Read from file descriptor"
        elif name == "write":
            desc = "Write to file descriptor"
        elif name == "open":
            desc = "Open file"
        elif name == "close":
            desc = "Close file descriptor"
        
        print(f"{number:<10} {name:<30} {desc}")
    
    print()
    print("Note: macOS uses x16 for syscall numbers (not x8 like Linux)")
    print("BSD syscalls: x16 > 0")
    print("Mach traps: x16 < 0 (negative numbers)")


if __name__ == "__main__":
    main()
