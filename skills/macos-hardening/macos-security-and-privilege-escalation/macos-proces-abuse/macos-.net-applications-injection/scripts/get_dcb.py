#!/usr/bin/env python3
"""Get Debug Control Block from a .NET process.

The DCB contains the base address of libcorclr.dll which is needed
for locating the Dynamic Function Table (DFT).

Usage: python3 get_dcb.py <pipe_in> <pipe_out>
"""

import struct
import sys

MT_GetDCB = 0x00000004

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

def get_dcb(pipe_in, pipe_out):
    """Get Debug Control Block from a .NET process."""
    
    print(f"[*] Requesting Debug Control Block...")
    
    # Build GetDCB request (no data block)
    header = build_message_header(
        MT_GetDCB,
        0,
        4,
        0,
        3
    )
    
    try:
        # Send request
        with open(pipe_in, 'wb') as f:
            f.write(header)
        
        # Read response
        with open(pipe_out, 'rb') as f:
            response_header = f.read(48)
            if len(response_header) < 48:
                print(f"[!] Incomplete response header")
                return None
            
            # Read DCB data (size varies, read up to 2KB)
            dcb_data = f.read(2048)
            
            if len(dcb_data) > 0:
                print(f"[+] Received DCB data ({len(dcb_data)} bytes)")
                
                # Try to extract m_helperRemoteStartAddr
                # This is typically at a known offset in the DCB structure
                # For .NET Core, it's often around offset 0x100-0x200
                
                # Display raw hex
                print(f"\n[*] DCB data (first 128 bytes):")
                for i in range(0, min(128, len(dcb_data)), 16):
                    hex_str = ' '.join(f'{b:02x}' for b in dcb_data[i:i+16])
                    ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in dcb_data[i:i+16])
                    print(f"  0x{i:04x}: {hex_str:<48} {ascii_str}")
                
                return dcb_data
            else:
                print("[!] No DCB data received")
                return None
                
    except Exception as e:
        print(f"[!] Error: {e}")
        return None

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <pipe_in> <pipe_out>")
        print("\nExample:")
        print(f"  {sys.argv[0]} /tmp/dotnet_debug_12345-in /tmp/dotnet_debug_12345-out")
        sys.exit(1)
    
    pipe_in = sys.argv[1]
    pipe_out = sys.argv[2]
    
    get_dcb(pipe_in, pipe_out)

if __name__ == "__main__":
    main()
