#!/bin/bash
# Zeek DNS Analysis Script
# Analyzes dns.log for suspicious DNS activity

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <zeek-logs-directory>"
    echo "Example: $0 /path/to/zeek-logs/"
    exit 1
fi

LOG_DIR="$1"
DNS_LOG="$LOG_DIR/dns.log"

if [ ! -f "$DNS_LOG" ]; then
    echo "Error: dns.log not found in $LOG_DIR"
    exit 1
fi

echo "=== Zeek DNS Analysis ==="
echo "Analyzing: $DNS_LOG"
echo ""

echo "--- Top 10 Domains Requested ---"
cat "$DNS_LOG" | zeek-cut query 2>/dev/null | sort | uniq | rev | cut -d '.' -f 1-2 | rev | sort | uniq -c | sort -nr | head -n 10 || \
    awk -F'\t' '{print $2}' "$DNS_LOG" | sort | uniq -c | sort -nr | head -n 10

echo ""
echo "--- Top 10 DNS Query Types ---"
cat "$DNS_LOG" | zeek-cut qtype_name 2>/dev/null | sort | uniq -c | sort -nr | head -n 10 || \
    awk -F'\t' '{print $3}' "$DNS_LOG" | sort | uniq -c | sort -nr | head -n 10

echo ""
echo "--- Top 10 Source IPs Making DNS Queries ---"
cat "$DNS_LOG" | zeek-cut id.orig_h 2>/dev/null | sort | uniq -c | sort -nr | head -n 10 || \
    awk -F'\t' '{print $1}' "$DNS_LOG" | sort | uniq -c | sort -nr | head -n 10

echo ""
echo "--- Unique Domains per Source IP (potential DGA) ---"
cat "$DNS_LOG" | zeek-cut id.orig_h query 2>/dev/null | sort -u | cut -f 1 | sort | uniq -c | sort -nr | head -n 10 || \
    awk -F'\t' '{print $1"\t"$2}' "$DNS_LOG" | sort -u | cut -f 1 | sort | uniq -c | sort -nr | head -n 10

echo ""
echo "--- TXT Record Queries (potential DNS tunneling) ---"
cat "$DNS_LOG" | zeek-cut id.orig_h query qtype_name 2>/dev/null | grep -i 'TXT' | head -n 20 || \
    awk -F'\t' '$3 ~ /TXT/ {print $1, $2}' "$DNS_LOG" | head -n 20

echo ""
echo "--- Queries with No Answers (NXDOMAIN) ---"
cat "$DNS_LOG" | zeek-cut id.orig_h query answers 2>/dev/null | grep -E '\t$|\t-\t' | head -n 20 || \
    awk -F'\t' '$4 == "" || $4 == "-" {print $1, $2}' "$DNS_LOG" | head -n 20

echo ""
echo "--- Sample DNS Queries with Answers ---"
cat "$DNS_LOG" | zeek-cut -c id.orig_h query qtype_name answers 2>/dev/null | head -n 20 || \
    awk -F'\t' '{print $1, $2, $3, $4}' "$DNS_LOG" | head -n 20

echo ""
echo "DNS analysis complete."
