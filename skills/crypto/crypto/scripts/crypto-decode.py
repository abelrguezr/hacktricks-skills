#!/usr/bin/env python3
"""Decode various encodings commonly found in CTF challenges."""

import base64
import binascii
import sys
import re


def try_base64(data):
    """Try to decode base64 (standard and URL-safe)."""
    # Add padding if needed
    padded = data + '=' * (4 - len(data) % 4) if len(data) % 4 else data
    
    # Standard base64
    try:
        decoded = base64.b64decode(padded)
        if is_printable(decoded):
            return 'base64', decoded.decode('utf-8', errors='replace')
    except:
        pass
    
    # URL-safe base64
    try:
        decoded = base64.urlsafe_b64decode(padded)
        if is_printable(decoded):
            return 'base64-urlsafe', decoded.decode('utf-8', errors='replace')
    except:
        pass
    
    return None, None


def try_hex(data):
    """Try to decode hex string."""
    if re.match(r'^[0-9a-fA-F]+$', data):
        try:
            decoded = binascii.unhexlify(data)
            if is_printable(decoded):
                return 'hex', decoded.decode('utf-8', errors='replace')
        except:
            pass
    return None, None


def try_rot13(data):
    """Apply ROT13 transformation."""
    result = ''
    for char in data:
        if 'a' <= char <= 'z':
            result += chr((ord(char) - ord('a') + 13) % 26 + ord('a'))
        elif 'A' <= char <= 'Z':
            result += chr((ord(char) - ord('A') + 13) % 26 + ord('A'))
        else:
            result += char
    return 'rot13', result


def try_url_decode(data):
    """URL decode the string."""
    import urllib.parse
    try:
        decoded = urllib.parse.unquote(data)
        if decoded != data:
            return 'url', decoded
    except:
        pass
    return None, None


def try_ascii85(data):
    """Try ASCII85 decoding."""
    try:
        decoded = base64.a85decode(data.encode())
        if is_printable(decoded):
            return 'ascii85', decoded.decode('utf-8', errors='replace')
    except:
        pass
    return None, None


def is_printable(data):
    """Check if bytes are mostly printable ASCII."""
    if not data:
        return False
    printable_count = sum(1 for b in data if 32 <= b < 127 or b in (9, 10, 13))
    return printable_count / len(data) > 0.8


def detect_encoding(data):
    """Try multiple decodings and return results."""
    results = []
    
    # Try each decoder
    decoders = [
        ('base64', try_base64),
        ('hex', try_hex),
        ('rot13', try_rot13),
        ('url', try_url_decode),
        ('ascii85', try_ascii85),
    ]
    
    for name, decoder in decoders:
        encoding, decoded = decoder(data)
        if encoding and decoded:
            results.append((encoding, decoded))
    
    return results


def main():
    if len(sys.argv) < 2:
        print("Usage: crypto-decode.py <encoded_string>")
        print("\nAttempts to decode: base64, hex, rot13, URL, ASCII85")
        sys.exit(1)
    
    data = sys.argv[1]
    results = detect_encoding(data)
    
    if not results:
        print("No successful decodings found.")
        print(f"Input: {data}")
        sys.exit(1)
    
    print(f"Input: {data}")
    print(f"\nFound {len(results)} possible decoding(s):\n")
    
    for i, (encoding, decoded) in enumerate(results, 1):
        print(f"{i}. {encoding.upper()}:")
        print(f"   {decoded}")
        print()


if __name__ == '__main__':
    main()
