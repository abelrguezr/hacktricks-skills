#!/usr/bin/env python3
"""Read memory from a .NET process on macOS.

Usage: python3 read_memory.py <pipe_in> <pipe_out> <address> <length>
"""

import struct
import sys

MT_ReadMemory = 0x00000002

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

def read_memory(pipe_in, pipe_out, address, length):
    """Read memory from a .NET process."""
    
    print(f"[*] Reading {length} bytes from 0x{address:016X}")
    
    # Build read request
    data_block = struct.pack('<QQ', address, length)
    header = build_message_header(
        MT_ReadMemory,
        len(data_block),
        2,
        0,
        1
    )
    
    try:
        # Send request
        with open(pipe_in, 'wb') as f:
            f.write(header)
            f.write(data_block)
        
        # Read response
        with open(pipe_out, 'rb') as f:
            response_header = f.read(48)
            if len(response_header) < 48:
                print(f"[!] Incomplete response header")
                return None
            
            # Read memory data
            memory_data = f.read(length)
            
            if len(memory_data) < length:
                print(f"[!] Incomplete memory read: {len(memory_data)}/{length} bytes")
            else:
                print(f"[+] Successfully read {len(memory_data)} bytes")
                
                # Display as hex
                print(f"\n[*] Memory dump (first 64 bytes):")
                for i in range(0, min(64, len(memory_data)), 16):
                    hex_str = ' '.join(f'{b:02x}' for b in memory_data[i:i+16])
                    ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in memory_data[i:i+16])
                    print(f"  0x{i:04x}: {hex_str:<48} {ascii_str}")
                
                return memory_data
                
    except Exception as e:
        print(f"[!] Error: {e}")
        return None

def main():
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <pipe_in> <pipe_out> <address> <length>")
        print("\nExample:")
        print(f"  {sys.argv[0]} /tmp/dotnet_debug_12345-in /tmp/dotnet_debug_12345-out 0x7fff5fbff000 256")
        sys.exit(1)
    
    pipe_in = sys.argv[1]
    pipe_out = sys.argv[2]
    address = int(sys.argv[3], 16) if sys.argv[3].startswith('0x') else int(sys.argv[3])
    length = int(sys.argv[4])
    
    read_memory(pipe_in, pipe_out, address, length)

if __name__ == "__main__":
    main()
