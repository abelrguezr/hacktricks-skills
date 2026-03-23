#!/bin/bash
# Extract all DYLD_* environment variables from dyld binary
# Usage: ./list_dyld_env_vars.sh [dyld_path]

DYLD_PATH="${1:-/usr/lib/dyld}"

if [[ ! -f "$DYLD_PATH" ]]; then
    echo "Error: dyld not found at $DYLD_PATH"
    exit 1
fi

echo "DYLD Environment Variables from $DYLD_PATH"
echo "==========================================="
echo ""

# Method 1: strings grep
strings "$DYLD_PATH" | grep "^DYLD_" | sort -u | while read -r var; do
    echo "$var"
done

echo ""
echo "Total: $(strings "$DYLD_PATH" | grep "^DYLD_" | sort -u | wc -l | tr -d ' ') variables"
