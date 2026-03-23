#!/bin/bash
# Discord Cache Scanner - Scan for high-signal artifacts
# Usage: ./scan_discord_cache.sh --cache /path/to/Cache_Data --output /path/to/results

set -e

# Parse arguments
CACHE_DIR=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --cache)
      CACHE_DIR="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 --cache /path/to/Cache_Data --output /path/to/results"
      exit 1
      ;;
  esac
done

if [[ -z "$CACHE_DIR" || -z "$OUTPUT_DIR" ]]; then
  echo "Error: --cache and --output are required"
  echo "Usage: $0 --cache /path/to/Cache_Data --output /path/to/results"
  exit 1
fi

if [[ ! -d "$CACHE_DIR" ]]; then
  echo "Error: Cache directory not found: $CACHE_DIR"
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Scanning Discord cache: $CACHE_DIR"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Scan for webhook endpoints
echo "[*] Scanning for webhook endpoints..."
strings -a "$CACHE_DIR"/* 2>/dev/null | grep -i "https://discord.com/api/webhooks/" > "$OUTPUT_DIR/webhooks.txt" || true
echo "    Found $(wc -l < "$OUTPUT_DIR/webhooks.txt") webhook references"

# Scan for attachment/CDN URLs
echo "[*] Scanning for attachment/CDN URLs..."
strings -a "$CACHE_DIR"/* 2>/dev/null | grep -Ei "https://(cdn|media)\.discord(app)?\.com/attachments/" > "$OUTPUT_DIR/attachments.txt" || true
echo "    Found $(wc -l < "$OUTPUT_DIR/attachments.txt") attachment references"

# Scan for Discord API calls
echo "[*] Scanning for Discord API calls..."
strings -a "$CACHE_DIR"/* 2>/dev/null | grep -Ei "https://discord(app)?\.com/api/v[0-9]+/" > "$OUTPUT_DIR/api_calls.txt" || true
echo "    Found $(wc -l < "$OUTPUT_DIR/api_calls.txt") API call references"

# List f_* files with timestamps
echo "[*] Listing f_* files with timestamps..."
find "$CACHE_DIR" -maxdepth 1 -name "f_*" -type f -printf "%T+ %p %s\n" 2>/dev/null | sort > "$OUTPUT_DIR/f_files_timeline.txt" || true
echo "    Found $(wc -l < "$OUTPUT_DIR/f_files_timeline.txt") f_* files"

# List data_* files with timestamps
echo "[*] Listing data_* files with timestamps..."
find "$CACHE_DIR" -maxdepth 1 -name "data_*" -type f -printf "%T+ %p %s\n" 2>/dev/null | sort > "$OUTPUT_DIR/data_files_timeline.txt" || true
echo "    Found $(wc -l < "$OUTPUT_DIR/data_files_timeline.txt") data_* files"

# Generate summary
echo ""
echo "=== Scan Summary ==="
echo "Webhook references: $(wc -l < "$OUTPUT_DIR/webhooks.txt")"
echo "Attachment references: $(wc -l < "$OUTPUT_DIR/attachments.txt")"
echo "API call references: $(wc -l < "$OUTPUT_DIR/api_calls.txt")"
echo "f_* files: $(wc -l < "$OUTPUT_DIR/f_files_timeline.txt")"
echo "data_* files: $(wc -l < "$OUTPUT_DIR/data_files_timeline.txt")"
echo ""
echo "Results saved to: $OUTPUT_DIR"
echo "Next steps:"
echo "  - Review webhooks.txt for potential C2 endpoints"
echo "  - Use parse_cache_entries.py to extract f_* content"
echo "  - Use extract_media.py to carve media files"
