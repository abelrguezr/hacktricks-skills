#!/bin/bash
# PCAP Quick Information Script
# Extracts basic information from a PCAP file

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <pcap-file>"
    echo "Example: $0 capture.pcap"
    exit 1
fi

PCAP_FILE="$1"

if [ ! -f "$PCAP_FILE" ]; then
    echo "Error: File not found: $PCAP_FILE"
    exit 1
fi

echo "=== PCAP Quick Information ==="
echo "File: $PCAP_FILE"
echo ""

echo "--- File Size ---"
ls -lh "$PCAP_FILE" | awk '{print $5}'
echo ""

echo "--- Capinfos Output ---"
if command -v capinfos &> /dev/null; then
    capinfos "$PCAP_FILE" 2>/dev/null || echo "capinfos not available or file unreadable"
else
    echo "capinfos not installed. Install with: apt-get install wireshark-common"
fi
echo ""

echo "--- TShark Statistics ---"
if command -v tshark &> /dev/null; then
    echo "Packet count and duration:"
    tshark -r "$PCAP_FILE" -q -z io,stat,0 2>/dev/null | head -n 20 || echo "tshark failed to read file"
    
    echo ""
    echo "Protocol hierarchy:"
    tshark -r "$PCAP_FILE" -q -z io,phs 2>/dev/null | head -n 30 || echo "Failed to get protocol hierarchy"
    
    echo ""
    echo "Conversations (top 10 by packets):"
    tshark -r "$PCAP_FILE" -q -z conv,tcp 2>/dev/null | head -n 15 || echo "Failed to get conversations"
else
    echo "tshark not installed. Install with: apt-get install tshark"
fi
echo ""

echo "--- Unique IP Addresses ---"
if command -v tshark &> /dev/null; then
    echo "Source IPs:"
    tshark -r "$PCAP_FILE" -T fields -e ip.src 2>/dev/null | sort -u | grep -v '^$' | head -n 20 || echo "No IP sources found"
    
    echo ""
    echo "Destination IPs:"
    tshark -r "$PCAP_FILE" -T fields -e ip.dst 2>/dev/null | sort -u | grep -v '^$' | head -n 20 || echo "No IP destinations found"
else
    echo "tshark required for IP analysis"
fi
echo ""

echo "--- HTTP Requests (if any) ---"
if command -v tshark &> /dev/null; then
    tshark -r "$PCAP_FILE" -Y "http.request" -T fields -e http.host -e http.request.uri 2>/dev/null | head -n 20 || echo "No HTTP requests found"
else
    echo "tshark required for HTTP analysis"
fi
echo ""

echo "Quick info extraction complete."
