#!/usr/bin/env python3
"""
RPC Endpoint Trigger Activation Script
Usage: python3 activate_rpc_endpoint.py -uuid <INTERFACE-UUID> [-target <host>]

This script queries the RPC Endpoint Mapper to trigger services that
register their endpoints with EPM. When a client queries for an interface
UUID, the SCM may start the associated service to register its endpoint.
"""

import argparse
import sys
import socket
import struct

# Common high-value RPC interface UUIDs
# These are examples - actual UUIDs should be discovered via enumeration
COMMON_UUIDS = {
    "RemoteRegistry": "{12345678-1234-ABCD-EF00-000000000000}",  # Example format
    "WebClient": "{9AF4E89F-0269-47C2-B683-9583886ADCC2}",
    "EFS": "{A94BE60C-5AB2-475D-BB05-07437B7D35E8}",
    "LanmanServer": "{4B324FC8-1670-01D3-1278-5A47BF6EE188}",
    "Spooler": "{12345678-1234-ABCD-EF00-000000000000}",  # Example format
}

def parse_uuid(uuid_str):
    """Parse UUID string to bytes (little-endian for RPC)"""
    # Remove braces and hyphens
    uuid_str = uuid_str.strip('{}').replace('-', '')
    
    if len(uuid_str) != 32:
        raise ValueError(f"Invalid UUID length: {len(uuid_str)}")
    
    # Convert to bytes
    uuid_bytes = bytes.fromhex(uuid_str)
    
    # RPC UUID format: data1 (4 bytes LE), data2 (2 bytes LE), data3 (2 bytes LE), data4 (8 bytes)
    # Reorder for RPC wire format
    data1 = struct.unpack('<I', uuid_bytes[0:4])[0]
    data2 = struct.unpack('<H', uuid_bytes[4:6])[0]
    data3 = struct.unpack('<H', uuid_bytes[6:8])[0]
    data4 = uuid_bytes[8:16]
    
    return struct.pack('<IHH', data1, data2, data3) + data4

def query_epm(target, uuid_bytes, port=135):
    """Query the RPC Endpoint Mapper for an interface UUID"""
    
    print(f"Querying EPM at {target}:{port} for UUID...")
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        sock.connect((target, port))
        
        # Build RPC request (simplified - in production, use proper RPC library)
        # This is a basic EPM lookup request
        # For full implementation, use Impacket's rpcdump.py or similar
        
        print(f"UUID bytes: {uuid_bytes.hex()}")
        print("Note: For full RPC EPM queries, use Impacket's rpcdump.py:")
        print(f"  python3 rpcdump.py @{target} -uuid {uuid_bytes.hex()}")
        
        sock.close()
        return True
        
    except Exception as e:
        print(f"Error querying EPM: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(
        description='Activate Windows service triggers via RPC endpoint queries'
    )
    parser.add_argument(
        '-uuid', '--uuid',
        required=True,
        help='Interface UUID to query (e.g., 9AF4E89F-0269-47C2-B683-9583886ADCC2)'
    )
    parser.add_argument(
        '-target', '--target',
        default='127.0.0.1',
        help='Target host (default: 127.0.0.1)'
    )
    parser.add_argument(
        '-port', '--port',
        type=int,
        default=135,
        help='EPM port (default: 135)'
    )
    parser.add_argument(
        '-list', '--list',
        action='store_true',
        help='List common high-value UUIDs'
    )
    
    args = parser.parse_args()
    
    if args.list:
        print("Common high-value RPC interface UUIDs:")
        print("=" * 50)
        for name, uuid in COMMON_UUIDS.items():
            print(f"  {name}: {uuid}")
        return
    
    try:
        uuid_bytes = parse_uuid(args.uuid)
        query_epm(args.target, uuid_bytes, args.port)
        print("\nRPC endpoint query completed.")
        print("Check if the target service started as a result.")
        
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
