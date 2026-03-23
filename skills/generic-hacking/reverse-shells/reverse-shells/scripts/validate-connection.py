#!/usr/bin/env python3
"""
Connection Validator for Reverse Shell Testing

This script validates network connectivity for reverse shell testing.
ONLY USE IN AUTHORIZED SECURITY TESTING ENVIRONMENTS.

Usage:
    python validate-connection.py --ip 192.168.1.100 --port 4444
"""

import argparse
import socket
import sys


def check_port_open(ip: str, port: int, timeout: int = 5) -> bool:
    """Check if a port is open on the specified IP."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((ip, port))
        sock.close()
        return result == 0
    except Exception as e:
        print(f"Error checking port: {e}")
        return False


def get_external_ip() -> str:
    """Get the external IP address of the machine."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.connect(("8.8.8.8", 80))
        ip = sock.getsockname()[0]
        sock.close()
        return ip
    except Exception as e:
        print(f"Error getting IP: {e}")
        return "UNKNOWN"


def test_reverse_connection(ip: str, port: int, timeout: int = 5) -> bool:
    """Test if a reverse connection can be established."""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        sock.connect((ip, port))
        sock.close()
        return True
    except socket.timeout:
        print(f"⚠️  Connection timed out to {ip}:{port}")
        return False
    except ConnectionRefusedError:
        print(f"⚠️  Connection refused by {ip}:{port}")
        return False
    except Exception as e:
        print(f"⚠️  Connection error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description='Validate network connectivity for reverse shell testing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
⚠️  LEGAL NOTICE: Only use in authorized security testing environments.

Examples:
    python validate-connection.py --ip 192.168.1.100 --port 4444
    python validate-connection.py --check-external --port 4444
"""
    )
    
    parser.add_argument('--ip', help='Target IP address to test')
    parser.add_argument('--port', type=int, required=True, help='Port to test')
    parser.add_argument('--check-external', action='store_true',
                        help='Check external IP address')
    parser.add_argument('--timeout', type=int, default=5,
                        help='Connection timeout in seconds (default: 5)')
    
    args = parser.parse_args()
    
    print("🔍 Connection Validator")
    print("=" * 40)
    
    if args.check_external:
        external_ip = get_external_ip()
        print(f"\n🌐 External IP: {external_ip}")
        print(f"   Use this IP as LHOST in your payloads\n")
    
    if args.ip:
        print(f"\n📡 Testing connection to {args.ip}:{args.port}")
        
        if check_port_open(args.ip, args.port, args.timeout):
            print(f"✅ Port {args.port} is OPEN on {args.ip}")
            
            if test_reverse_connection(args.ip, args.port, args.timeout):
                print(f"✅ Reverse connection test PASSED")
            else:
                print(f"❌ Reverse connection test FAILED")
        else:
            print(f"❌ Port {args.port} is CLOSED or FILTERED on {args.ip}")
            print(f"\n💡 Troubleshooting:")
            print(f"   1. Check if listener is running: netstat -tlnp | grep {args.port}")
            print(f"   2. Check firewall: sudo ufw status")
            print(f"   3. Verify IP address is correct")
    else:
        print("\n❌ Please specify --ip to test a connection")
        print("   Or use --check-external to get your external IP\n")
    
    print("\n⚠️  REMINDER: Only use in authorized security testing environments.")


if __name__ == '__main__':
    main()
