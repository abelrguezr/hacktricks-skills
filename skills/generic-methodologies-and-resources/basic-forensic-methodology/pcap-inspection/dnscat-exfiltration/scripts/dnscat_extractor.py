#!/usr/bin/env python3
"""
DNSCat Exfiltration Extractor

Extracts exfiltrated data from DNSCat traffic in pcap files.
DNSCat encodes data as hex in DNS subdomain queries with a 9-byte C&C header.

Usage:
    python3 dnscat_extractor.py <pcap_file> <c2_domain>

Example:
    python3 dnscat_extractor.py ch21.pcap jz-n-bs.local
"""

import sys
import argparse
from scapy.all import rdpcap, DNSQR, DNSRR


def extract_dnscat_data(pcap_file: str, c2_domain: str) -> str:
    """
    Extract exfiltrated data from DNSCat traffic.
    
    Args:
        pcap_file: Path to the pcap file
        c2_domain: The C2 domain used for DNSCat communication
        
    Returns:
        The extracted exfiltrated data as a string
    """
    # Normalize domain - remove trailing dot if present
    c2_domain = c2_domain.rstrip('.')
    
    # Read the pcap file
    print(f"[*] Reading pcap file: {pcap_file}")
    packets = rdpcap(pcap_file)
    print(f"[*] Found {len(packets)} packets")
    
    # Collect DNS query data
    chunks = []
    seen_queries = set()
    query_count = 0
    
    print(f"[*] Searching for DNS queries to {c2_domain}...")
    
    for packet in packets:
        # Look for DNS queries (not responses)
        if packet.haslayer(DNSQR) and not packet.haslayer(DNSRR):
            dns_layer = packet[DNSQR]
            qname = dns_layer.qname.decode() if isinstance(dns_layer.qname, bytes) else str(dns_layer.qname)
            
            # Check if this query is for our C2 domain
            if c2_domain in qname:
                query_count += 1
                
                # Extract the subdomain part (before the C2 domain)
                # Format: hex_data.c2_domain.tld
                parts = qname.split('.')
                
                # Remove the C2 domain and TLD from the parts
                subdomain_parts = []
                for part in parts:
                    if part.lower() == c2_domain.lower():
                        break
                    if part:  # Skip empty parts
                        subdomain_parts.append(part)
                
                if subdomain_parts:
                    # Join and decode hex
                    hex_string = ''.join(subdomain_parts)
                    
                    # Skip if we've seen this exact query before
                    if hex_string in seen_queries:
                        continue
                    seen_queries.add(hex_string)
                    
                    try:
                        # Decode hex to bytes
                        decoded = bytes.fromhex(hex_string)
                        chunks.append(decoded)
                    except ValueError as e:
                        print(f"[!] Skipping invalid hex: {hex_string[:50]}... ({e})")
    
    if not chunks:
        print(f"[!] No DNSCat data found for domain: {c2_domain}")
        print(f"    Found {query_count} DNS queries to this domain, but none contained valid hex data")
        return ""
    
    print(f"[*] Found {len(chunks)} DNSCat chunks")
    
    # Strip the 9-byte C&C header from the first chunk
    if len(chunks) > 0 and len(chunks[0]) > 9:
        print(f"[*] Stripping 9-byte C&C header from first chunk")
        chunks[0] = chunks[0][9:]
    
    # Concatenate all chunks
    extracted_data = b''.join(chunks)
    
    # Print each chunk as we go (for visibility)
    print("\n[+] Extracted chunks:")
    for i, chunk in enumerate(chunks):
        try:
            text = chunk.decode('utf-8', errors='replace')
            print(f"    Chunk {i}: {text[:100]}{'...' if len(text) > 100 else ''}")
        except:
            print(f"    Chunk {i}: {chunk[:100]}...")
    
    # Return the full extracted data
    return extracted_data


def main():
    parser = argparse.ArgumentParser(
        description='Extract exfiltrated data from DNSCat traffic in pcap files',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 dnscat_extractor.py capture.pcap evil-domain.com
    python3 dnscat_extractor.py network_traffic.pcap c2.attacker.net
        """
    )
    parser.add_argument('pcap_file', help='Path to the pcap file')
    parser.add_argument('c2_domain', help='The C2 domain used for DNSCat communication')
    parser.add_argument('-o', '--output', help='Output file to save extracted data (default: stdout)')
    parser.add_argument('-v', '--verbose', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    try:
        # Extract the data
        extracted = extract_dnscat_data(args.pcap_file, args.c2_domain)
        
        if not extracted:
            print("\n[!] No data was extracted")
            sys.exit(1)
        
        # Output the results
        print(f"\n{'='*60}")
        print(f"[+] EXFILTRATED DATA ({len(extracted)} bytes):")
        print(f"{'='*60}")
        
        try:
            # Try to decode as text
            text_output = extracted.decode('utf-8', errors='replace')
            print(text_output)
        except:
            # Fall back to hex dump
            print(extracted.hex())
        
        # Save to file if requested
        if args.output:
            with open(args.output, 'wb') as f:
                f.write(extracted)
            print(f"\n[+] Saved to: {args.output}")
        
    except FileNotFoundError:
        print(f"[!] Error: File not found: {args.pcap_file}")
        sys.exit(1)
    except Exception as e:
        print(f"[!] Error: {e}")
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
