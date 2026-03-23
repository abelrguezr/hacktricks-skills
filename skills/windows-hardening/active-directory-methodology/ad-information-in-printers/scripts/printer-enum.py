#!/usr/bin/env python3
"""
Printer Enumeration Tool for AD Credential Harvesting
Scans printers for open ports and potential attack vectors
"""

import socket
import sys
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed

# Common printer ports and their significance
PRINTER_PORTS = {
    80: "HTTP (Web Interface)",
    443: "HTTPS (Web Interface)",
    389: "LDAP (Credential Harvesting Target)",
    636: "LDAPS (Secure LDAP)",
    3269: "LDAP Global Catalog",
    9100: "Raw Printing (JetDirect)",
    515: "LPD (Line Printer Daemon)",
    631: "IPP (Internet Printing Protocol)",
    161: "SNMP (Configuration Discovery)",
    162: "SNMP Trap",
    21: "FTP (Scan-to-Folder)",
    22: "SSH (Management)",
    23: "Telnet (Management - Insecure)",
    25: "SMTP (Scan-to-Email)",
    110: "POP3 (Email)",
    143: "IMAP (Email)",
}

def check_port(ip, port, timeout=2):
    """Check if a port is open on the target IP"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((ip, port))
        sock.close()
        return port, result == 0
    except socket.error:
        return port, False

def check_udp_port(ip, port, timeout=2):
    """Check if a UDP port is open (SNMP)"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(timeout)
        # Send empty SNMP request
        sock.sendto(b'\x30\x2b\x02\x01\x03\x04\x00\x02\x01\x03\x04\x00\xa0\x19\x30\x17\x02\x01\x00\x04\x00\x30\x0f\x06\x08\x2b\x06\x01\x02\x01\x01\x02\x01\x00', (ip, port))
        try:
            data, addr = sock.recvfrom(1024)
            sock.close()
            return port, True
        except socket.timeout:
            sock.close()
            return port, False
    except socket.error:
        return port, False

def scan_printer(ip, timeout=2):
    """Scan a single printer for open ports"""
    results = {}
    
    # TCP ports
    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = {executor.submit(check_port, ip, port, timeout): port 
                   for port in PRINTER_PORTS.keys() if port not in [161, 162]}
        
        for future in as_completed(futures):
            port, is_open = future.result()
            if is_open:
                results[port] = PRINTER_PORTS[port]
    
    # UDP ports (SNMP)
    for port in [161, 162]:
        port_num, is_open = check_udp_port(ip, port, timeout)
        if is_open:
            results[port_num] = PRINTER_PORTS[port_num]
    
    return ip, results

def main():
    parser = argparse.ArgumentParser(
        description='Printer Enumeration Tool for AD Credential Harvesting',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s 192.168.1.50
  %(prog)s 192.168.1.50 192.168.1.51 192.168.1.52
  %(prog)s -f targets.txt
  %(prog)s 192.168.1.0/24 --timeout 1
        """
    )
    parser.add_argument('targets', nargs='*', help='Target IP addresses or CIDR ranges')
    parser.add_argument('-f', '--file', help='File containing target IPs (one per line)')
    parser.add_argument('-t', '--timeout', type=int, default=2, help='Connection timeout in seconds (default: 2)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Show closed ports')
    
    args = parser.parse_args()
    
    # Collect targets
    targets = []
    
    if args.file:
        try:
            with open(args.file, 'r') as f:
                targets.extend([line.strip() for line in f if line.strip() and not line.startswith('#')])
        except FileNotFoundError:
            print(f"Error: File '{args.file}' not found")
            sys.exit(1)
    
    targets.extend(args.targets)
    
    if not targets:
        print("Error: No targets specified. Use IP addresses, CIDR ranges, or -f for a file.")
        sys.exit(1)
    
    print(f"[*] Scanning {len(targets)} target(s)...")
    print("[*] Ports of interest for credential harvesting: 389 (LDAP), 636 (LDAPS), 80/443 (Web Interface)")
    print("[*] Ports for configuration discovery: 161 (SNMP), 21 (FTP), 25 (SMTP)")
    print("=" * 80)
    
    # Scan targets
    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = {executor.submit(scan_printer, target, args.timeout): target for target in targets}
        
        for future in as_completed(futures):
            ip, results = future.result()
            
            if results:
                print(f"\n[+] {ip} - {len(results)} open port(s):")
                for port in sorted(results.keys()):
                    service = results[port]
                    # Highlight credential harvesting targets
                    if port in [389, 636, 80, 443]:
                        print(f"    ⚠️  {port}/tcp - {service} <--- CREDENTIAL HARVESTING TARGET")
                    elif port in [161, 21, 25]:
                        print(f"    ℹ️  {port} - {service} <--- CONFIGURATION DISCOVERY")
                    else:
                        print(f"    • {port}/tcp - {service}")
            elif args.verbose:
                print(f"\n[-] {ip} - No open ports found")
    
    print("\n" + "=" * 80)
    print("[+] Scan complete")
    print("\nNext steps for credential harvesting:")
    print("  1. Set up rogue LDAP server: ./setup-ldap-listener.sh")
    print("  2. Access web interface (port 80/443) and change LDAP server to your IP")
    print("  3. Click 'Test Connection' or 'Address Book Sync' to trigger credential leak")
    print("  4. Use PRET/Praeda for automated configuration extraction")

if __name__ == "__main__":
    main()
