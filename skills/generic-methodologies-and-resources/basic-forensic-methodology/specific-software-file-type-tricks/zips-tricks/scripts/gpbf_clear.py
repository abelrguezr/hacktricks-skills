#!/usr/bin/env python3
"""Clear encryption bit (bit 0) in ZIP local and central directory headers.

Usage:
    python3 gpbf_clear.py input.apk output.apk

This fixes fake encryption anti-reversing tricks where GPBF bit 0 is set
but no actual encryption is applied, breaking tools like jadx and apktool.
"""
import struct
import sys

SIG_LFH = b"\x50\x4b\x03\x04"  # Local File Header
SIG_CDH = b"\x50\x4b\x01\x02"  # Central Directory Header

def patch_flags(buf: bytes, sig: bytes, flag_off: int) -> tuple[bytes, int]:
    """Clear bit 0 (encryption) in all headers matching signature.
    
    Args:
        buf: ZIP file contents as bytes
        sig: Header signature to search for
        flag_off: Offset of General Purpose Bit Flag from signature start
        
    Returns:
        Tuple of (patched buffer, count of patched headers)
    """
    out = bytearray(buf)
    i = 0
    patched = 0
    
    while True:
        i = out.find(sig, i)
        if i == -1:
            break
        
        flags, = struct.unpack_from('<H', out, i + flag_off)
        if flags & 1:  # encryption bit set
            struct.pack_into('<H', out, i + flag_off, flags & 0xFFFE)
            patched += 1
        
        i += 4  # move past signature to continue search
    
    return bytes(out), patched

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.apk output.apk")
        sys.exit(1)
    
    inp, outp = sys.argv[1], sys.argv[2]
    
    try:
        data = open(inp, 'rb').read()
    except FileNotFoundError:
        print(f"Error: File not found: {inp}")
        sys.exit(1)
    except IOError as e:
        print(f"Error reading file: {e}")
        sys.exit(1)
    
    # Patch Local File Headers (flag at offset +6 from signature)
    data, p_lfh = patch_flags(data, SIG_LFH, 6)
    
    # Patch Central Directory Headers (flag at offset +8 from signature)
    data, p_cdh = patch_flags(data, SIG_CDH, 8)
    
    try:
        open(outp, 'wb').write(data)
    except IOError as e:
        print(f"Error writing file: {e}")
        sys.exit(1)
    
    print(f"Patched: LFH={p_lfh}, CDH={p_cdh}")
    print(f"Output: {outp}")
    
    if p_lfh == 0 and p_cdh == 0:
        print("Note: No encryption bits were set. File may already be clean.")

if __name__ == '__main__':
    main()
