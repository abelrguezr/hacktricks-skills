#!/usr/bin/env python3
"""Parse Pyarmor obfuscation headers from Python binaries.

Usage:
    python parse_pyarmor_header.py <binary>

This script extracts encryption parameters from Pyarmor-protected
Python executables, including AES keys, nonces, and BCC offsets.
"""

import sys
import struct
import os

def parse_pyarmor_header(binary_path):
    """Parse Pyarmor header and extract encryption parameters."""
    
    if not os.path.exists(binary_path):
        print(f"[-] File not found: {binary_path}")
        return False
    
    with open(binary_path, 'rb') as f:
        data = f.read()
    
    # Check for Pyarmor signature
    if len(data) < 64:
        print("[-] File too small to contain Pyarmor header")
        return False
    
    # Check signature at offset 0x00
    signature = data[0:4]
    if not signature.startswith(b'PY'):
        print("[-] No Pyarmor signature found (expected 'PY<license>')")
        print("[!] This may not be a Pyarmor-protected binary")
        return False
    
    print("[+] Pyarmor signature found: PY<license>")
    
    # Parse header fields
    try:
        python_major = data[0x09]
        python_minor = data[0x0a]
        protection_type = data[0x09]  # 0x09 = BCC enabled, 0x08 = otherwise
        
        # ELF offsets (8 bytes each, little-endian)
        elf_start = struct.unpack('<Q', data[0x1c:0x24])[0]
        elf_end = struct.unpack('<Q', data[0x38:0x40])[0]
        
        # AES-CTR nonce (12 bytes split across two regions)
        nonce_part1 = data[0x24:0x28]
        nonce_part2 = data[0x2c:0x34]
        nonce = nonce_part1 + nonce_part2
        
        print(f"\n[+] Python version: {python_major}.{python_minor}")
        print(f"[+] Protection type: {'BCC enabled' if protection_type == 0x09 else 'Standard'}")
        print(f"[+] ELF start offset: 0x{elf_start:x}")
        print(f"[+] ELF end offset: 0x{elf_end:x}")
        print(f"[+] AES-CTR nonce: {nonce.hex()}")
        
        # Check for second header (after embedded ELF)
        if elf_end < len(data):
            second_sig = data[elf_end:elf_end+4]
            if second_sig.startswith(b'PY'):
                print(f"\n[+] Second Pyarmor header found at offset 0x{elf_end:x}")
                # Parse second header similarly
                second_nonce_part1 = data[elf_end + 0x24:elf_end + 0x28]
                second_nonce_part2 = data[elf_end + 0x2c:elf_end + 0x34]
                second_nonce = second_nonce_part1 + second_nonce_part2
                print(f"[+] Second nonce: {second_nonce.hex()}")
        
        # Look for encrypted string markers (0x81 prefix)
        encrypted_strings = []
        for i in range(len(data) - 1):
            if data[i] == 0x81:
                # Found encrypted string marker
                encrypted_strings.append(i)
        
        if encrypted_strings:
            print(f"\n[+] Found {len(encrypted_strings)} encrypted string markers (0x81)")
            print("[!] These use AES-128-CTR with the runtime key")
        
        # Look for Pyarmor function markers
        pyarmor_markers = []
        markers_to_find = [
            b'__pyarmor_enter_',
            b'__pyarmor_exit_',
            b'__pyarmor_assert_',
            b'__pyarmor_bcc_'
        ]
        
        for marker in markers_to_find:
            pos = 0
            while True:
                pos = data.find(marker, pos)
                if pos == -1:
                    break
                pyarmor_markers.append((pos, marker.decode()))
                pos += 1
        
        if pyarmor_markers:
            print(f"\n[+] Found {len(pyarmor_markers)} Pyarmor markers:")
            for pos, name in pyarmor_markers[:10]:  # Show first 10
                print(f"    0x{pos:x}: {name}")
            if len(pyarmor_markers) > 10:
                print(f"    ... and {len(pyarmor_markers) - 10} more")
        
        print("\n[+] Decryption notes:")
        print("    - Use AES-128-CTR with the runtime key")
        print("    - Derive per-region nonce by XORing with __pyarmor_exit_*__ marker")
        print("    - String nonce example: 692e767673e95c45a1e6876d")
        print("    - Runtime key example: 273b1b1373cf25e054a61e2cb8a947b8")
        
        return True
        
    except struct.error as e:
        print(f"[-] Error parsing header: {e}")
        return False

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    binary_path = sys.argv[1]
    success = parse_pyarmor_header(binary_path)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
