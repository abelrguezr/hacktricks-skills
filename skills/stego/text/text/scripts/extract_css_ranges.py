#!/usr/bin/env python3
"""Extract and decode unicode-range values from CSS files.

CSS @font-face rules can encode bytes in unicode-range: U+.. entries.
This script extracts those codepoints, concatenates the hex, and decodes as bytes.

Usage:
    python3 extract_css_ranges.py < styles.css
    cat styles.css | python3 extract_css_ranges.py

Example CSS:
    @font-face {
        unicode-range: U+0046, U+004C, U+0041, U+0047;
    }
    # Decodes to: FLAG
"""

import sys
import re

def extract_unicode_ranges(css_content):
    """Extract all unicode-range values from CSS content."""
    # Match unicode-range declarations
    # Handles: U+0046, U+004C, U+0041, U+0047
    # Also handles ranges like: U+0046-004F
    pattern = r'unicode-range:\s*([^;]+)'
    matches = re.findall(pattern, css_content, re.IGNORECASE)
    
    all_codepoints = []
    
    for match in matches:
        # Split on commas and extract individual U+ values
        parts = match.split(',')
        for part in parts:
            part = part.strip()
            # Extract hex values after U+
            hex_values = re.findall(r'U\+([0-9A-Fa-f]+)', part)
            all_codepoints.extend(hex_values)
    
    return all_codepoints

def decode_codepoints(codepoints):
    """Convert hex codepoints to bytes and decode as text."""
    # Concatenate all hex values
    hex_string = ''.join(codepoints)
    
    # Convert hex to bytes
    try:
        byte_data = bytes.fromhex(hex_string)
        return byte_data
    except ValueError as e:
        return None, f"Error decoding hex: {e}"

def main():
    # Read CSS content from stdin
    css_content = sys.stdin.read()
    
    if not css_content:
        print("No CSS input received. Pipe CSS to this script or use < file.css")
        sys.exit(1)
    
    # Extract unicode-range values
    codepoints = extract_unicode_ranges(css_content)
    
    if not codepoints:
        print("No unicode-range declarations found in CSS")
        sys.exit(1)
    
    print(f"Found {len(codepoints)} unicode-range values:")
    print(f"  {', '.join(codepoints[:10])}{'...' if len(codepoints) > 10 else ''}")
    
    # Decode the codepoints
    result = decode_codepoints(codepoints)
    
    if result is None:
        print(f"Error: {result}")
        sys.exit(1)
    
    byte_data, = result if isinstance(result, tuple) else (result,)
    
    print(f"\nDecoded bytes ({len(byte_data)} bytes):")
    print(f"  Hex: {byte_data.hex()}")
    
    # Try to decode as text
    try:
        text = byte_data.decode('utf-8')
        print(f"  Text: {text}")
    except UnicodeDecodeError:
        # Try latin-1 as fallback
        try:
            text = byte_data.decode('latin-1')
            print(f"  Text (latin-1): {text}")
        except:
            print(f"  Raw bytes: {byte_data}")

if __name__ == "__main__":
    main()
