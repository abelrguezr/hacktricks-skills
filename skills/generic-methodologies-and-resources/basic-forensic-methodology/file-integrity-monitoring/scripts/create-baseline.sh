#!/bin/bash
# File Integrity Monitoring - Create Baseline
# Usage: ./create-baseline.sh <directory> <output-file>
# Example: ./create-baseline.sh /etc baseline.txt

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <directory> <output-file>"
    echo "Example: $0 /etc baseline.txt"
    exit 1
fi

DIR="$1"
OUTPUT="$2"

if [ ! -d "$DIR" ]; then
    echo "Error: Directory '$DIR' does not exist"
    exit 1
fi

echo "Creating baseline for: $DIR"
echo "Output file: $OUTPUT"
echo "Timestamp: $(date -Iseconds)"
echo ""

# Create baseline with SHA-256 hashes
find "$DIR" -type f -exec sha256sum {} \; 2>/dev/null | sort > "$OUTPUT"

# Add metadata
echo "# Baseline created: $(date -Iseconds)" | cat - "$OUTPUT" > temp && mv temp "$OUTPUT"

FILE_COUNT=$(wc -l < "$OUTPUT")
echo "Baseline created successfully!"
echo "Total files hashed: $FILE_COUNT"
echo "Output saved to: $OUTPUT"
