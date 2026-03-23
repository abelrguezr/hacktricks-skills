#!/usr/bin/env python3
"""
Extract metadata from WiFi PCAP files using tshark.

Usage:
    python extract-wifi-metadata.py <capture.pcap>
"""

import subprocess
import json
import sys
from collections import defaultdict

def run_tshark(pcap_file, expression):
    """Run tshark with the given expression and return output."""
    try:
        result = subprocess.run(
            ["tshark", "-r", pcap_file, "-T", "fields", "-e", expression],
            capture_output=True,
            text=True,
            timeout=60
        )
        return result.stdout.strip().split("\n") if result.stdout else []
    except subprocess.TimeoutExpired:
        print("Warning: tshark command timed out")
        return []
    except FileNotFoundError:
        print("Error: tshark not found. Please install Wireshark.")
        sys.exit(1)

def extract_bssids(pcap_file):
    """Extract all BSSIDs from the capture."""
    bssids = set(run_tshark(pcap_file, "wlan.bssid"))
    return [b for b in bssids if b and b != ""]

def extract_ssids(pcap_file):
    """Extract all SSIDs from the capture."""
    ssids = set(run_tshark(pcap_file, "wlan.ssid"))
    return [s for s in ssids if s and s != ""]

def check_authentication(pcap_file, bssid):
    """Check if authentication handshake exists for a BSSID."""
    # Count 4-way handshake messages
    result = subprocess.run(
        ["tshark", "-r", pcap_file, "-Y", f"wlan.bssid == {bssid} && eap", "-T", "fields", "-e", "frame.number"],
        capture_output=True,
        text=True,
        timeout=60
    )
    eap_frames = [f for f in result.stdout.strip().split("\n") if f]
    return len(eap_frames) >= 4  # 4-way handshake requires at least 4 EAP frames

def extract_mac_addresses(pcap_file):
    """Extract all unique MAC addresses from the capture."""
    macs = set(run_tshark(pcap_file, "wlan.sa"))
    macs.update(run_tshark(pcap_file, "wlan.da"))
    macs.update(run_tshark(pcap_file, "wlan.ta"))
    macs.update(run_tshark(pcap_file, "wlan.ra"))
    return [m for m in macs if m and m != ""]

def get_packet_count(pcap_file):
    """Get total packet count."""
    result = subprocess.run(
        ["tshark", "-r", pcap_file, "-q", "-z", "io,stat,0"],
        capture_output=True,
        text=True,
        timeout=60
    )
    for line in result.stdout.split("\n"):
        if "Total" in line:
            parts = line.split()
            if len(parts) >= 2:
                return int(parts[1])
    return 0

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract-wifi-metadata.py <capture.pcap>")
        sys.exit(1)
    
    pcap_file = sys.argv[1]
    
    print(f"\nAnalyzing: {pcap_file}")
    print("=" * 50)
    
    metadata = {
        "file": pcap_file,
        "packet_count": get_packet_count(pcap_file),
        "bssids": extract_bssids(pcap_file),
        "ssids": extract_ssids(pcap_file),
        "mac_addresses": extract_mac_addresses(pcap_file),
        "authentication_status": {}
    }
    
    # Check authentication for each BSSID
    for bssid in metadata["bssids"]:
        metadata["authentication_status"][bssid] = check_authentication(pcap_file, bssid)
    
    # Print summary
    print(f"\nTotal Packets: {metadata['packet_count']}")
    print(f"\nBSSIDs Found: {len(metadata['bssids'])}")
    for bssid in metadata["bssids"]:
        auth_status = "✓ Auth captured" if metadata["authentication_status"][bssid] else "✗ No auth"
        print(f"  - {bssid}: {auth_status}")
    
    print(f"\nSSIDs Found: {len(metadata['ssids'])}")
    for ssid in metadata["ssids"]:
        print(f"  - {ssid}")
    
    print(f"\nUnique MAC Addresses: {len(metadata['mac_addresses'])}")
    
    # Output JSON for programmatic use
    print("\n" + "=" * 50)
    print("JSON Output:")
    print(json.dumps(metadata, indent=2))

if __name__ == "__main__":
    main()
