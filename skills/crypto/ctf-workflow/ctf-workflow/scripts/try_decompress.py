#!/usr/bin/env python3
"""
Try multiple decompression methods on input data.
Usage: python3 try_decompress.py <file> or echo "data" | python3 try_decompress.py
"""

import sys
import zlib
import gzip
import io

def try_decompress(data):
    """Try various decompression methods."""
    results = []
    
    # Try zlib with different window bits
    for wbits in [zlib.MAX_WBITS, -zlib.MAX_WBITS, zlib.MAX_WBITS|16, zlib.MAX_WBITS|32]:
        try:
            decompressed = zlib.decompress(data, wbits=wbits)
            results.append((f"zlib (wbits={wbits})", decompressed))
        except Exception as e:
            pass
    
    # Try gzip
    try:
        decompressed = gzip.decompress(data)
        results.append(("gzip", decompressed))
    except Exception as e:
        pass
    
    # Try raw deflate
    try:
        decompressed = zlib.decompress(data, -zlib.MAX_WBITS)
        results.append(("raw deflate", decompressed))
    except Exception as e:
        pass
    
    return results

def main():
    if len(sys.argv) > 1:
        # Read from file
        with open(sys.argv[1], 'rb') as f:
            data = f.read()
    else:
        # Read from stdin
        data = sys.stdin.buffer.read()
    
    print(f"Input size: {len(data)} bytes")
    print(f"First 20 bytes (hex): {data[:20].hex()}")
    print()
    
    results = try_decompress(data)
    
    if results:
        print(f"Found {len(results)} successful decompression(s):")
        print()
        for method, decompressed in results:
            print(f"=== {method} ===")
            # Show first 200 bytes as text if printable
            try:
                text = decompressed[:200].decode('utf-8', errors='replace')
                print(text)
                if len(decompressed) > 200:
                    print(f"... ({len(decompressed) - 200} more bytes)")
            except:
                print(decompressed[:200].hex())
            print()
    else:
        print("No decompression method succeeded.")
        print("Try: CyberChef Raw Deflate/Raw Inflate")

if __name__ == "__main__":
    main()
