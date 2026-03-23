#!/bin/bash
# Extract and decode csreq from TCC database
# Usage: ./extract-csreq.sh [bundle_id] [output_dir]

set -e

BUNDLE_ID="${1:-}"
OUTPUT_DIR="${2:-./csreq-extracts}"

mkdir -p "$OUTPUT_DIR"

if [[ -z "$BUNDLE_ID" ]]; then
  echo "Usage: $0 <bundle_id> [output_dir]"
  echo "Example: $0 com.apple.Finder"
  echo "Example: $0 telegram ./extracts"
  exit 1
fi

echo "Extracting csreq for: $BUNDLE_ID"
echo "Output directory: $OUTPUT_DIR"
echo ""

USER_DB="$HOME/Library/Application Support/com.apple.TCC/TCC.db"

if [[ ! -f "$USER_DB" ]]; then
  echo "User TCC database not found: $USER_DB"
  exit 1
fi

# Query csreq entries
QUERY="SELECT service, client, hex(csreq) FROM access WHERE client LIKE '%$BUNDLE_ID%' AND csreq IS NOT NULL;"

echo "Query: $QUERY"
echo ""

sqlite3 -separator "|" "$USER_DB" "$QUERY" | while IFS='|' read -r service client csreq_hex; do
  if [[ -n "$csreq_hex" ]]; then
    OUTPUT_FILE="$OUTPUT_DIR/${service//\//_}_${client//\//_}.csreq"
    
    echo "Extracting: $service"
    echo "Client: $client"
    echo "Output: $OUTPUT_FILE"
    echo ""
    
    # Write hex to file
    echo "$csreq_hex" | xxd -r -p > "$OUTPUT_FILE"
    
    # Decode csreq
    echo "Decoded csreq:"
    csreq -t -r "$OUTPUT_FILE" 2>/dev/null || echo "(failed to decode)"
    echo ""
    echo "---"
    echo ""
  fi
done

echo "Done. Extracted files in: $OUTPUT_DIR"
