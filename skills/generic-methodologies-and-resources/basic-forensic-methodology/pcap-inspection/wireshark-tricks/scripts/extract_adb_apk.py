#!/usr/bin/env python3
"""
Extract APK data from ADB communication in PCAP files.

Usage:
    python extract_adb_apk.py <pcap-file> [output-file]

This script parses ADB WRTE commands and reconstructs the transferred data.
"""

import sys
from scapy.all import rdpcap, Raw


def rm_data(data):
    """Remove DATA markers from ADB protocol data."""
    splitted = data.split(b"DATA")
    if len(splitted) == 1:
        return data
    else:
        return splitted[0] + splitted[1][4:]


def extract_apk_from_pcap(pcap_path, output_path="extracted_apk.data"):
    """Extract APK data from ADB communication in a PCAP file."""
    print(f"Reading PCAP file: {pcap_path}")
    pcap = rdpcap(pcap_path)
    
    all_bytes = b""
    
    for pkt in pcap:
        if Raw in pkt:
            a = pkt[Raw]
            if b"WRTE" == bytes(a)[:4]:
                # WRTE command - skip header
                all_bytes += rm_data(bytes(a)[24:])
            else:
                all_bytes += rm_data(bytes(a))
    
    print(f"Extracted {len(all_bytes)} bytes")
    
    with open(output_path, 'wb') as f:
        f.write(all_bytes)
    
    print(f"Saved to: {output_path}")
    return output_path


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python extract_adb_apk.py <pcap-file> [output-file]")
        sys.exit(1)
    
    pcap_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "extracted_apk.data"
    
    extract_apk_from_pcap(pcap_file, output_file)
