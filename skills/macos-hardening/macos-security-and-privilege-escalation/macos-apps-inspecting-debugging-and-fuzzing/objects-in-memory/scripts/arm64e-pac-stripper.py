#!/usr/bin/env python3
"""
Strip Pointer Authentication Code (PAC) from arm64e pointers.

This script helps analyze and strip PAC bits from arm64e pointers
for use in memory inspection and debugging.

Usage:
    python arm64e-pac-stripper.py 0x000000016f123abc
    python arm64e-pac-stripper.py --interactive
"""

import argparse
import sys
import struct

# PAC key types (from ptrauth.h)
PAC_KEYS = {
    'asda': 0,  # Data authentication, general
    'aut': 1,   # Data authentication, user
    'apc': 2,   # Code authentication, return address
    'ibc': 3,   # Code authentication, branch
    'iwa': 4,   # Code authentication, data
    'gd': 5,    # Data authentication, general (alternative)
    'gdma': 6,  # Data authentication, memory address
}

# arm64e pointer layout (simplified)
# Bits 63-56: PAC (8 bits)
# Bits 55-3: Address (53 bits)
# Bits 2-0: Reserved/alignment

def strip_pac_simple(pointer):
    """Simple PAC stripping - remove top 8 bits."""
    # Mask out top 8 bits (PAC)
    return pointer & 0x0000FFFFFFFFFFFF


def analyze_pointer(pointer):
    """Analyze an arm64e pointer for PAC bits."""
    result = {
        'original': f'0x{pointer:016x}',
        'has_pac': (pointer >> 56) != 0,
        'pac_bits': (pointer >> 56) & 0xFF,
        'stripped': f'0x{strip_pac_simple(pointer):016x}',
        'address_bits': pointer & 0x0000FFFFFFFFFFFF,
    }
    return result


def format_analysis(analysis):
    """Format analysis results for display."""
    lines = [
        f"Original pointer: {analysis['original']}",
        f"Has PAC: {analysis['has_pac']}",
        f"PAC bits: 0x{analysis['pac_bits']:02x}",
        f"Stripped pointer: {analysis['stripped']}",
        f"Address bits: 0x{analysis['address_bits']:014x}",
    ]
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Strip PAC from arm64e pointers'
    )
    parser.add_argument(
        'pointer',
        nargs='?',
        help='Pointer address (hex or decimal)'
    )
    parser.add_argument(
        '-i', '--interactive',
        action='store_true',
        help='Interactive mode'
    )
    parser.add_argument(
        '-b', '--batch',
        nargs='+',
        help='Batch process multiple pointers'
    )
    
    args = parser.parse_args()
    
    def process_pointer(ptr_str):
        """Process a single pointer."""
        try:
            # Try hex first
            if ptr_str.lower().startswith('0x'):
                pointer = int(ptr_str, 16)
            else:
                pointer = int(ptr_str, 10)
            
            analysis = analyze_pointer(pointer)
            return format_analysis(analysis)
        except ValueError as e:
            return f"Error parsing pointer '{ptr_str}': {e}"
    
    if args.interactive:
        print("Interactive mode. Enter pointers to analyze (or 'quit' to exit):")
        while True:
            try:
                ptr = input("\n> ").strip()
                if ptr.lower() in ('quit', 'exit', 'q'):
                    break
                if not ptr:
                    continue
                
                print(process_pointer(ptr))
            except EOFError:
                break
        return
    
    if args.batch:
        for ptr in args.batch:
            print(f"\n=== {ptr} ===")
            print(process_pointer(ptr))
        return
    
    if args.pointer:
        print(process_pointer(args.pointer))
    else:
        parser.print_help()
        print("\nExamples:")
        print("  python arm64e-pac-stripper.py 0x000000016f123abc")
        print("  python arm64e-pac-stripper.py --interactive")
        print("  python arm64e-pac-stripper.py --batch 0x123 0x456")
        sys.exit(1)


if __name__ == '__main__':
    main()
