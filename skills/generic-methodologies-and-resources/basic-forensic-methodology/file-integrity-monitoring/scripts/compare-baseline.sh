#!/bin/bash
# File Integrity Monitoring - Compare Baseline
# Usage: ./compare-baseline.sh <baseline-file> <directory>
# Example: ./compare-baseline.sh baseline.txt /etc

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <baseline-file> <directory>"
    echo "Example: $0 baseline.txt /etc"
    exit 1
fi

BASELINE="$1"
DIR="$2"

if [ ! -f "$BASELINE" ]; then
    echo "Error: Baseline file '$BASELINE' does not exist"
    exit 1
fi

if [ ! -d "$DIR" ]; then
    echo "Error: Directory '$DIR' does not exist"
    exit 1
fi

echo "Comparing current state against baseline..."
echo "Baseline: $BASELINE"
echo "Directory: $DIR"
echo ""

# Create temporary file for current hashes
CURRENT=$(mktemp)
find "$DIR" -type f -exec sha256sum {} \; 2>/dev/null | sort > "$CURRENT"

# Extract just the file paths from baseline (skip comments)
BASELINE_FILES=$(grep -v '^#' "$BASELINE" | awk '{print $2}' | sort)
CURRENT_FILES=$(awk '{print $2}' "$CURRENT" | sort)

# Find modified files (hash changed)
echo "=== MODIFIED FILES ==="
MODIFIED=$(comm -12 <(grep -v '^#' "$BASELINE" | awk '{print $2}' | sort) <(awk '{print $2}' "$CURRENT" | sort) | while read file; do
    OLD_HASH=$(grep -v '^#' "$BASELINE" | grep "$file" | awk '{print $1}')
    NEW_HASH=$(grep "$file" "$CURRENT" | awk '{print $1}')
    if [ "$OLD_HASH" != "$NEW_HASH" ]; then
        echo "$file"
    fi
done)

if [ -z "$MODIFIED" ]; then
    echo "No modified files detected"
else
    echo "$MODIFIED"
fi

echo ""
echo "=== NEW FILES (not in baseline) ==="
NEW_FILES=$(comm -13 <(grep -v '^#' "$BASELINE" | awk '{print $2}' | sort) <(awk '{print $2}' "$CURRENT" | sort))
if [ -z "$NEW_FILES" ]; then
    echo "No new files detected"
else
    echo "$NEW_FILES"
fi

echo ""
echo "=== DELETED FILES (in baseline but missing) ==="
DELETED_FILES=$(comm -23 <(grep -v '^#' "$BASELINE" | awk '{print $2}' | sort) <(awk '{print $2}' "$CURRENT" | sort))
if [ -z "$DELETED_FILES" ]; then
    echo "No deleted files detected"
else
    echo "$DELETED_FILES"
fi

# Cleanup
rm -f "$CURRENT"

echo ""
echo "Comparison complete."
