#!/usr/bin/env python3
"""
Check if a file size is a perfect square.
Useful for detecting potential QR code or raw pixel data.
"""

import sys
import math
import os

def check_perfect_square(filepath):
    """Check if file size is a perfect square."""
    if not os.path.exists(filepath):
        print(f"Error: File '{filepath}' not found")
        return False
    
    size = os.path.getsize(filepath)
    sqrt_size = math.isqrt(size)
    is_perfect = (sqrt_size * sqrt_size == size)
    
    print(f"File: {filepath}")
    print(f"Size: {size} bytes")
    print(f"Square root: {sqrt_size}")
    
    if is_perfect:
        print(f"✓ PERFECT SQUARE: {sqrt_size} x {sqrt_size} = {size}")
        print("  This could indicate:")
        print("  - Raw pixel data for an image")
        print("  - QR code data")
        print("  - Binary image representation")
        print("")
        print("  Try converting to image:")
        print(f"  - Online: https://www.dcode.fr/binary-image")
        print(f"  - Or use PIL to create {sqrt_size}x{sqrt_size} image")
        return True
    else:
        print("✗ Not a perfect square")
        remainder = size - (sqrt_size * sqrt_size)
        print(f"  Difference from nearest square: {remainder} bytes")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python check-perfect-square.py <filepath>")
        print("Example: python check-perfect-square.py suspicious.bin")
        sys.exit(1)
    
    check_perfect_square(sys.argv[1])
