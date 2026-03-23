#!/usr/bin/env python3
"""Decode extracted steganography payloads.

Tries common encodings: base64, hex, rot13, gzip, zlib, etc.
"""

import argparse
import base64
import gzip
import zlib
import codecs
import sys
from pathlib import Path


def try_decode(data: bytes, name: str = ""):
    """Try various decodings on the data."""
    results = []
    
    # Try base64
    try:
        decoded = base64.b64decode(data)
        if all(32 <= b < 127 or b in (9, 10, 13) for b in decoded):
            results.append(("base64", decoded.decode('ascii')))
    except Exception:
        pass
    
    # Try hex
    try:
        if all(c in b'0123456789abcdefABCDEF' for c in data):
            decoded = bytes.fromhex(data.decode('ascii'))
            if all(32 <= b < 127 or b in (9, 10, 13) for b in decoded):
                results.append(("hex", decoded.decode('ascii')))
    except Exception:
        pass
    
    # Try rot13
    try:
        decoded = codecs.decode(data.decode('ascii', errors='ignore'), 'rot_13')
        results.append(("rot13", decoded))
    except Exception:
        pass
    
    # Try gzip
    try:
        decoded = gzip.decompress(data).decode('ascii', errors='ignore')
        results.append(("gzip", decoded))
    except Exception:
        pass
    
    # Try zlib
    try:
        decoded = zlib.decompress(data).decode('ascii', errors='ignore')
        results.append(("zlib", decoded))
    except Exception:
        pass
    
    # Try raw ASCII/UTF-8
    try:
        decoded = data.decode('ascii', errors='ignore')
        if decoded.strip():
            results.append(("ascii", decoded))
    except Exception:
        pass
    
    try:
        decoded = data.decode('utf-8', errors='ignore')
        if decoded.strip():
            results.append(("utf-8", decoded))
    except Exception:
        pass
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Decode extracted steganography payloads"
    )
    parser.add_argument(
        "input",
        nargs="?",
        help="Input file or string to decode"
    )
    parser.add_argument(
        "-f", "--file",
        action="store_true",
        help="Treat input as filename (default: treat as string)"
    )
    
    args = parser.parse_args()
    
    # Get input data
    if args.input is None:
        # Read from stdin
        data = sys.stdin.read().encode('utf-8')
    elif args.file:
        # Read from file
        path = Path(args.input)
        if not path.exists():
            print(f"Error: File not found: {args.input}")
            sys.exit(1)
        data = path.read_bytes()
    else:
        # Treat as string
        data = args.input.encode('utf-8')
    
    print(f"Input ({len(data)} bytes):")
    print(data[:200])
    if len(data) > 200:
        print("... (truncated)")
    print()
    
    # Try decodings
    results = try_decode(data)
    
    if results:
        print("Decoding results:")
        print("=" * 60)
        for method, decoded in results:
            print(f"\n[{method}]")
            print(decoded[:500])
            if len(decoded) > 500:
                print("... (truncated)")
    else:
        print("No successful decodings found.")
        print(f"\nRaw hex: {data.hex()}")


if __name__ == "__main__":
    main()
