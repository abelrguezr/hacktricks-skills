#!/bin/bash
# Zeek Connection Analysis Script
# Analyzes conn.log for suspicious patterns

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <zeek-logs-directory>"
    echo "Example: $0 /path/to/zeek-logs/"
    exit 1
fi

LOG_DIR="$1"
CONN_LOG="$LOG_DIR/conn.log"

if [ ! -f "$CONN_LOG" ]; then
    echo "Error: conn.log not found in $LOG_DIR"
    exit 1
fi

echo "=== Zeek Connection Analysis ==="
echo "Analyzing: $CONN_LOG"
echo ""

echo "--- Top 10 Longest Connections (potential reverse shells) ---"
cat "$CONN_LOG" | zeek-cut id.orig_h id.orig_p id.resp_h id.resp_p proto service duration 2>/dev/null | sort -nrk 7 | head -n 10 || \
    awk -F'\t' '{print $1, $2, $3, $4, $5, $6, $7}' "$CONN_LOG" | sort -nrk 7 | head -n 10

echo ""
echo "--- Top 10 by Total Duration per Destination ---"
cat "$CONN_LOG" | zeek-cut id.orig_h id.resp_h id.resp_p proto duration 2>/dev/null | \
    awk 'BEGIN{ FS="\t" } { arr[$1 FS $2 FS $3 FS $4] += $5 } END{ for (key in arr) printf "%s\t%s\n", key, arr[key] }' | \
    sort -nrk 5 | head -n 10 || \
    awk -F'\t' '{arr[$1"\t"$3"\t"$4"\t"$5]+=$7} END{for(k in arr) print k"\t"arr[k]}' "$CONN_LOG" | sort -nrk 5 | head -n 10

echo ""
echo "--- Connection Count per IP Pair ---"
cat "$CONN_LOG" | zeek-cut id.orig_h id.resp_h duration 2>/dev/null | \
    awk 'BEGIN{ FS="\t" } { arr[$1 FS $2] += $3; count[$1 FS $2] += 1 } END{ for (key in arr) printf "%s\t%s\t%s\n", key, count[key], arr[key] }' | \
    sort -nrk 4 | head -n 10 || \
    awk -F'\t' '{arr[$1"\t"$3]+=$7; count[$1"\t"$3]++} END{for(k in arr) print k"\t"count[k]"\t"arr[k]}' "$CONN_LOG" | sort -nrk 4 | head -n 10

echo ""
echo "--- Top 10 Source IPs by Connection Count ---"
cat "$CONN_LOG" | zeek-cut id.orig_h 2>/dev/null | sort | uniq -c | sort -nr | head -n 10 || \
    awk -F'\t' '{print $1}' "$CONN_LOG" | sort | uniq -c | sort -nr | head -n 10

echo ""
echo "--- Top 10 Destination IPs by Connection Count ---"
cat "$CONN_LOG" | zeek-cut id.resp_h 2>/dev/null | sort | uniq -c | sort -nr | head -n 10 || \
    awk -F'\t' '{print $3}' "$CONN_LOG" | sort | uniq -c | sort -nr | head -n 10

echo ""
echo "--- Connections to Common C2 Ports (443, 8080, 8443) ---"
cat "$CONN_LOG" | zeek-cut id.orig_h id.resp_h id.resp_p proto 2>/dev/null | grep -E '\t(443|8080|8443)\t' | head -n 20 || \
    awk -F'\t' '$4 ~ /(443|8080|8443)/ {print $1, $3, $4}' "$CONN_LOG" | head -n 20

echo ""
echo "Analysis complete."
