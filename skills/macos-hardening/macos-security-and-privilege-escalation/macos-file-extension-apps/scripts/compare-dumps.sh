#!/bin/bash
# macOS LaunchServices Database Comparison Tool
# Usage: ./compare-dumps.sh baseline.json after-changes.json

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BASELINE=""
AFTER_CHANGES=""
OUTPUT_FILE=""

# Print usage
usage() {
    echo "Usage: $0 baseline.json after-changes.json [OPTIONS]"
    echo ""
    echo "Compare two LaunchServices database dumps to identify changes"
    echo ""
    echo "Options:"
    echo "  --output FILE       Save comparison results to file"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 baseline.json after-changes.json"
    echo "  $0 baseline.json after-changes.json --output comparison.txt"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            if [[ -z "$BASELINE" ]]; then
                BASELINE="$1"
            elif [[ -z "$AFTER_CHANGES" ]]; then
                AFTER_CHANGES="$1"
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$BASELINE" || -z "$AFTER_CHANGES" ]]; then
    echo "Error: Please specify both baseline and after-changes files"
    usage
fi

# Check if files exist
if [[ ! -f "$BASELINE" ]]; then
    echo -e "${RED}Error: Baseline file not found: $BASELINE${NC}"
    exit 1
fi

if [[ ! -f "$AFTER_CHANGES" ]]; then
    echo -e "${RED}Error: After-changes file not found: $AFTER_CHANGES${NC}"
    exit 1
fi

echo -e "${BLUE}[*] Comparing LaunchServices database dumps${NC}"
echo "  Baseline: $BASELINE"
echo "  After: $AFTER_CHANGES"
echo ""

# Extract raw data from JSON (assuming JSON format from dump-launchservices.sh)
BASELINE_DATA=$(cat "$BASELINE" | grep -v "dump_timestamp\|total_lines\|raw_data" | grep -v "^\[\]" | grep -v "^\{\}" | tr -d '"' | tr -d ',' | tr -d '\n' | sed 's/    //g')
AFTER_DATA=$(cat "$AFTER_CHANGES" | grep -v "dump_timestamp\|total_lines\|raw_data" | grep -v "^\[\]" | grep -v "^\{\}" | tr -d '"' | tr -d ',' | tr -d '\n' | sed 's/    //g')

# Create temporary files for comparison
BASELINE_TMP=$(mktemp)
AFTER_TMP=$(mktemp)

# Extract and normalize data
cat "$BASELINE" | grep -v "dump_timestamp\|total_lines\|raw_data" | grep -v "^\[\]" | grep -v "^\{\}" | tr -d '"' | tr -d ',' | sort > "$BASELINE_TMP"
cat "$AFTER_CHANGES" | grep -v "dump_timestamp\|total_lines\|raw_data" | grep -v "^\[\]" | grep -v "^\{\}" | tr -d '"' | tr -d ',' | sort > "$AFTER_TMP"

# Find differences
echo -e "${GREEN}[+] Changes Detected${NC}"
echo ""

# Added entries (in after but not in baseline)
echo -e "${GREEN}[+] Added entries:${NC}"
ADDED=$(comm -13 "$BASELINE_TMP" "$AFTER_TMP" | head -20)
if [[ -n "$ADDED" ]]; then
    echo "$ADDED" | while read -r line; do
        echo "  + $line"
    done
else
    echo "  (none)"
fi
echo ""

# Removed entries (in baseline but not in after)
echo -e "${RED}[-] Removed entries:${NC}"
REMOVED=$(comm -23 "$BASELINE_TMP" "$AFTER_TMP" | head -20)
if [[ -n "$REMOVED" ]]; then
    echo "$REMOVED" | while read -r line; do
        echo "  - $line"
    done
else
    echo "  (none)"
fi
echo ""

# Statistics
BASELINE_COUNT=$(wc -l < "$BASELINE_TMP" | tr -d ' ')
AFTER_COUNT=$(wc -l < "$AFTER_TMP" | tr -d ' ')
ADDED_COUNT=$(comm -13 "$BASELINE_TMP" "$AFTER_TMP" | wc -l | tr -d ' ')
REMOVED_COUNT=$(comm -23 "$BASELINE_TMP" "$AFTER_TMP" | wc -l | tr -d ' ')

echo -e "${BLUE}[*] Statistics${NC}"
echo "  Baseline entries: $BASELINE_COUNT"
echo "  After entries: $AFTER_COUNT"
echo "  Added: $ADDED_COUNT"
echo "  Removed: $REMOVED_COUNT"
echo ""

# Security alert for sensitive changes
if [[ $ADDED_COUNT -gt 0 || $REMOVED_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}[!] Security Note: Handler changes detected. Review for potential privilege escalation vectors.${NC}"
fi

# Save output if requested
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "Comparison saved to: $OUTPUT_FILE"
fi

# Cleanup
rm -f "$BASELINE_TMP" "$AFTER_TMP"

echo -e "${BLUE}[*] Done${NC}"
