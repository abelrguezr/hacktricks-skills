#!/usr/bin/env python3
"""
Batch demangle C++ symbols from IOKit drivers.

Usage:
    python3 demangle_symbols.py driver.kext          # Demangle all symbols
    python3 demangle_symbols.py -s symbol_name       # Search for specific symbol
    python3 demangle_symbols.py --stdin              # Read symbols from stdin
"""

import argparse
import subprocess
import sys
import re
from typing import List, Tuple, Optional


def run_cxxfilt(symbols: List[str]) -> List[Tuple[str, str]]:
    """Run c++filt on a list of symbols."""
    if not symbols:
        return []
    
    try:
        result = subprocess.run(
            ["c++filt"],
            input='\n'.join(symbols),
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            print(f"Warning: c++filt returned {result.returncode}")
        
        demangled = result.stdout.strip().split('\n')
        return list(zip(symbols, demangled))
    
    except subprocess.TimeoutExpired:
        print("Error: c++filt timed out")
        return []
    except FileNotFoundError:
        print("Error: c++filt not found. Install binutils or use 'c++filt' from Xcode.")
        return []


def extract_symbols_from_kext(kext_path: str) -> List[str]:
    """Extract symbols from a KEXT file using nm."""
    try:
        result = subprocess.run(
            ["nm", "-C", kext_path],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode != 0:
            # Try without -C flag
            result = subprocess.run(
                ["nm", kext_path],
                capture_output=True,
                text=True,
                timeout=60
            )
        
        symbols = []
        for line in result.stdout.split('\n'):
            parts = line.split()
            if len(parts) >= 3:
                # Format: address type name
                symbol_name = parts[-1]
                if symbol_name.startswith('_'):
                    symbols.append(symbol_name)
        
        return symbols
    
    except subprocess.TimeoutExpired:
        print(f"Error: nm timed out on {kext_path}")
        return []
    except FileNotFoundError:
        print("Error: nm not found. Are you on macOS?")
        return []


def main():
    parser = argparse.ArgumentParser(
        description="Batch demangle C++ symbols from IOKit drivers"
    )
    parser.add_argument(
        "kext",
        nargs="?",
        help="Path to KEXT file or binary"
    )
    parser.add_argument(
        "--stdin", "-i",
        action="store_true",
        help="Read symbols from stdin (one per line)"
    )
    parser.add_argument(
        "--search", "-s",
        help="Search for symbols containing this substring"
    )
    parser.add_argument(
        "--external-only", "-e",
        action="store_true",
        help="Only show external symbols (not static)"
    )
    
    args = parser.parse_args()
    
    # Get symbols
    symbols = []
    
    if args.stdin:
        symbols = [line.strip() for line in sys.stdin if line.strip()]
    elif args.kext:
        symbols = extract_symbols_from_kext(args.kext)
    else:
        print("Usage: Provide a KEXT file or use --stdin")
        print("  python3 demangle_symbols.py driver.kext")
        print("  echo '__ZN16IOUserClientE' | python3 demangle_symbols.py --stdin")
        sys.exit(1)
    
    if not symbols:
        print("No symbols found")
        sys.exit(0)
    
    # Filter if needed
    if args.search:
        symbols = [s for s in symbols if args.search.lower() in s.lower()]
    
    # Demangle
    results = run_cxxfilt(symbols)
    
    if not results:
        print("Failed to demangle symbols")
        sys.exit(1)
    
    # Output
    print(f"Demangled {len(results)} symbols:\n")
    print(f"{'Original':<60} {'Demangled'}")
    print("-" * 120)
    
    for original, demangled in results:
        # Truncate long lines
        orig_display = original[:57] + "..." if len(original) > 60 else original
        demangled_display = demangled[:57] + "..." if len(demangled) > 60 else demangled
        print(f"{orig_display:<60} {demangled_display}")
    
    print(f"\nTip: Use 'nm -C <driver>' to get demangled symbols directly")
    print(f"     Or pipe to c++filt: nm <driver> | c++filt")


if __name__ == "__main__":
    main()
