#!/usr/bin/env python3
"""Inspect Unicode codepoints in text for steganography detection.

Usage:
    python3 inspect_codepoints.py < file.txt
    cat file.txt | python3 inspect_codepoints.py

Outputs position, hex codepoint, and character representation for:
- Non-ASCII characters (ord > 127)
- Whitespace characters
"""

import sys

def inspect_codepoints(text):
    """Print codepoint information for suspicious characters."""
    for i, ch in enumerate(text):
        # Check for non-ASCII or whitespace
        if ord(ch) > 127 or ch.isspace():
            print(f"{i:6d}  {hex(ord(ch)):8s}  {repr(ch)}")

def main():
    # Read all input from stdin
    text = sys.stdin.read()
    
    if not text:
        print("No input received. Pipe text to this script or use < file.txt")
        sys.exit(1)
    
    print(f"Position  Codepoint  Character")
    print("-" * 40)
    
    inspect_codepoints(text)
    
    # Summary statistics
    non_ascii = sum(1 for ch in text if ord(ch) > 127)
    whitespace = sum(1 for ch in text if ch.isspace())
    
    print(f"\nSummary:")
    print(f"  Total characters: {len(text)}")
    print(f"  Non-ASCII characters: {non_ascii}")
    print(f"  Whitespace characters: {whitespace}")

if __name__ == "__main__":
    main()
