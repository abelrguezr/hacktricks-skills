#!/usr/bin/env python3
"""Establish a debugging session with a .NET process on macOS.

Usage: python3 establish_session.py <pipe_in> <pipe_out>
"""

import struct
import sys
import os

# Message types
MT_SessionRequest = 0x00000001
MT_ReadMemory = 0x00000002
MT_WriteMemory = 0x00000003
MT_GetDCB = 0x00000004

# Protocol version
MAJOR_VERSION = 2
MINOR_VERSION = 0

def build_message_header(msg_type, data_block_size, msg_id, reply_id=0, last_seen_id=0):
    """Build a MessageHeader struct."""
    header = struct.pack('<IIIIII',
        msg_type,           # m_eType
        data_block_size,    # m_cbDataBlock
        msg_id,             # m_dwId
        reply_id,           # m_dwReplyId
        last_seen_id,       # m_dwLastSeenId
        0                   # m_dwReserved
    )
    
    # Version info (for SessionRequest)
    if msg_type == MT_SessionRequest:
        version_data = struct.pack('<II', MAJOR_VERSION, MINOR_VERSION)
        header += version_data
    
    # Padding
    header += b'\x00' * 8  # m_sMustBeZero
    
    return header

def establish_session(pipe_in, pipe_out):
    """Establish a debugging session with a .NET process."""
    
    print(f"[*] Establishing debugging session...")
    print(f"[*] Pipe IN:  {pipe_in}")
    print(f"[*] Pipe OUT: {pipe_out}")
    
    # Check if pipes exist
    if not os.path.exists(pipe_in):
        print(f"[!] Pipe not found: {pipe_in}")
        return False
    
    # Build SessionRequest header
    session_guid = b'\x09' * 16  # 16-byte GUID
    header = build_message_header(
        MT_SessionRequest,
        len(session_guid),
        1
    )
    
    try:
        # Write to pipe
        with open(pipe_in, 'wb') as f:
            print(f"[*] Writing header ({len(header)} bytes)...")
            f.write(header)
            print(f"[*] Writing session GUID ({len(session_guid)} bytes)...")
            f.write(session_guid)
        
        # Read response
        with open(pipe_out, 'rb') as f:
            print(f"[*] Reading response...")
            response = f.read(48)  # MessageHeader size
            
            if len(response) < 48:
                print(f"[!] Incomplete response: {len(response)} bytes")
                return False
            
            # Parse response
            resp_type = struct.unpack('<I', response[:4])[0]
            print(f"[*] Response type: 0x{resp_type:08X}")
            
            if resp_type == MT_SessionRequest:
                print("[+] Debugging session established successfully!")
                return True
            else:
                print(f"[!] Unexpected response type: 0x{resp_type:08X}")
                return False
                
    except PermissionError as e:
        print(f"[!] Permission denied: {e}")
        return False
    except Exception as e:
        print(f"[!] Error: {e}")
        return False

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <pipe_in> <pipe_out>")
        print("\nExample:")
        print(f"  {sys.argv[0]} /tmp/dotnet_debug_12345-in /tmp/dotnet_debug_12345-out")
        sys.exit(1)
    
    pipe_in = sys.argv[1]
    pipe_out = sys.argv[2]
    
    success = establish_session(pipe_in, pipe_out)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
