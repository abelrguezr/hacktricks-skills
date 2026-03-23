#!/bin/bash
# File Integrity Monitoring - Continuous Monitor
# Usage: ./monitor-changes.sh <baseline-file> <directory> [--interval SECONDS]
# Example: ./monitor-changes.sh baseline.txt /etc --interval 60

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <baseline-file> <directory> [--interval SECONDS]"
    echo "Example: $0 baseline.txt /etc --interval 60"
    exit 1
fi

BASELINE="$1"
DIR="$2"
INTERVAL=60

# Parse optional interval argument
if [ "$3" = "--interval" ]; then
    INTERVAL="$4"
fi

if [ ! -f "$BASELINE" ]; then
    echo "Error: Baseline file '$BASELINE' does not exist"
    exit 1
fi

if [ ! -d "$DIR" ]; then
    echo "Error: Directory '$DIR' does not exist"
    exit 1
fi

echo "Starting continuous monitoring..."
echo "Baseline: $BASELINE"
echo "Directory: $DIR"
echo "Check interval: ${INTERVAL} seconds"
echo "Press Ctrl+C to stop"
echo ""

# Create temporary file for current hashes
CURRENT=$(mktemp)

while true; do
    echo "[$(date -Iseconds)] Checking for changes..."
    
    # Generate current hashes
    find "$DIR" -type f -exec sha256sum {} \; 2>/dev/null | sort > "$CURRENT"
    
    # Check for modifications
    MODIFIED_COUNT=0
    while read file; do
        OLD_HASH=$(grep -v '^#' "$BASELINE" | grep "$file" | awk '{print $1}')
        NEW_HASH=$(grep "$file" "$CURRENT" | awk '{print $1}')
        if [ "$OLD_HASH" != "$NEW_HASH" ]; then
            echo "  [MODIFIED] $file"
            MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
        fi
    done < <(comm -12 <(grep -v '^#' "$BASELINE" | awk '{print $2}' | sort) <(awk '{print $2}' "$CURRENT" | sort))
    
    # Check for new files
    while read file; do
        echo "  [NEW] $file"
        MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    done < <(comm -13 <(grep -v '^#' "$BASELINE" | awk '{print $2}' | sort) <(awk '{print $2}' "$CURRENT" | sort))
    
    # Check for deleted files
    while read file; do
        echo "  [DELETED] $file"
        MODIFIED_COUNT=$((MODIFIED_COUNT + 1))
    done < <(comm -23 <(grep -v '^#' "$BASELINE" | awk '{print $2}' | sort) <(awk '{print $2}' "$CURRENT" | sort))
    
    if [ $MODIFIED_COUNT -eq 0 ]; then
        echo "  No changes detected"
    else
        echo "  Total changes: $MODIFIED_COUNT"
    fi
    
    sleep "$INTERVAL"
done

# Cleanup on exit
rm -f "$CURRENT"
