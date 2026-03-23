#!/bin/bash
# Network Artifact Extraction Script
# Extracts key network artifacts from PCAP files

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <pcap_file> [output_directory]"
    exit 1
fi

PCAP_FILE="$1"
OUTPUT_DIR="${2:-./network_artifacts}"

if [ ! -f "$PCAP_FILE" ]; then
    echo "Error: PCAP file not found: $PCAP_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Network Artifact Extraction ==="
echo "PCAP File: $PCAP_FILE"
echo "Output Directory: $OUTPUT_DIR"
echo ""

# Check if tshark is available
if ! command -v tshark &> /dev/null; then
    echo "Warning: tshark not found. Using tcpdump fallback."
    USE_TSHARK=false
else
    USE_TSHARK=true
fi

echo "1. Extracting DNS Queries..."
if [ "$USE_TSHARK" = true ]; then
    tshark -r "$PCAP_FILE" -Y "dns.qry.name" -T fields -e dns.qry.name 2>/dev/null | \
        sort | uniq -c | sort -rn > "$OUTPUT_DIR/dns_queries.txt"
else
    tcpdump -r "$PCAP_FILE" -n 2>/dev/null | grep -i "dns" > "$OUTPUT_DIR/dns_queries.txt"
fi
echo "   Saved: $OUTPUT_DIR/dns_queries.txt"

echo "2. Extracting HTTP Requests..."
if [ "$USE_TSHARK" = true ]; then
    tshark -r "$PCAP_FILE" -Y "http.request" -T fields -e http.host -e http.request.uri 2>/dev/null | \
        sort | uniq -c | sort -rn > "$OUTPUT_DIR/http_requests.txt"
else
    tcpdump -r "$PCAP_FILE" -n 2>/dev/null | grep -i "http" > "$OUTPUT_DIR/http_requests.txt"
fi
echo "   Saved: $OUTPUT_DIR/http_requests.txt"

echo "3. Extracting IP Connections..."
if [ "$USE_TSHARK" = true ]; then
    tshark -r "$PCAP_FILE" -T fields -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport 2>/dev/null | \
        sort | uniq -c | sort -rn > "$OUTPUT_DIR/ip_connections.txt"
else
    tcpdump -r "$PCAP_FILE" -n 2>/dev/null | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | \
        sort | uniq -c | sort -rn > "$OUTPUT_DIR/ip_connections.txt"
fi
echo "   Saved: $OUTPUT_DIR/ip_connections.txt"

echo "4. Extracting Suspicious Ports..."
if [ "$USE_TSHARK" = true ]; then
    tshark -r "$PCAP_FILE" -Y "tcp.port == 4444 or tcp.port == 5555 or tcp.port == 6666 or tcp.port == 8080" 2>/dev/null | \
        head -100 > "$OUTPUT_DIR/suspicious_ports.txt"
else
    tcpdump -r "$PCAP_FILE" -n 2>/dev/null | grep -E "port (4444|5555|6666|8080)" > "$OUTPUT_DIR/suspicious_ports.txt"
fi
echo "   Saved: $OUTPUT_DIR/suspicious_ports.txt"

echo "5. Generating Summary Statistics..."
if [ "$USE_TSHARK" = true ]; then
    tshark -r "$PCAP_FILE" -q -z io,phs 2>/dev/null > "$OUTPUT_DIR/summary.txt"
    tshark -r "$PCAP_FILE" -q -z conv,tcp 2>/dev/null >> "$OUTPUT_DIR/summary.txt"
else
    echo "Total packets: $(tcpdump -r "$PCAP_FILE" -c 0 2>&1 | tail -1)" > "$OUTPUT_DIR/summary.txt"
fi
echo "   Saved: $OUTPUT_DIR/summary.txt"

echo ""
echo "=== Extraction Complete ==="
echo "Artifacts saved to: $OUTPUT_DIR/"
echo ""
echo "Quick stats:"
wc -l "$OUTPUT_DIR"/*.txt 2>/dev/null | tail -1
