#!/bin/bash
# Analyze kernel panic dump
# Usage: ./analyze-panic.sh [panic-file]

set -e

PANIC_FILE="${1:-latest.kcdata}"
OUTPUT_DIR="./panic-analysis"
mkdir -p "$OUTPUT_DIR"

echo "=== Kernel Panic Analysis ==="
echo ""

# Check if panic file exists
if [ ! -f "$PANIC_FILE" ]; then
    echo "Panic file not found: $PANIC_FILE"
    echo "Attempting to capture latest panic..."
    sudo kdpwrit dump "$PANIC_FILE" 2>/dev/null || {
        echo "ERROR: Could not capture panic dump"
        echo "Make sure a panic has occurred and you have sudo access"
        exit 1
    }
fi

echo "Analyzing: $PANIC_FILE"
echo ""

# Analyze with kmutil
if command -v kmutil &> /dev/null; then
    echo "Running kmutil analyze-panic..."
    kmutil analyze-panic "$PANIC_FILE" -o "$OUTPUT_DIR/panic_report.txt" 2>&1 || {
        echo "WARNING: kmutil analysis failed, trying alternative methods"
    }
    
    if [ -f "$OUTPUT_DIR/panic_report.txt" ]; then
        echo ""
        echo "=== Panic Report Summary ==="
        head -50 "$OUTPUT_DIR/panic_report.txt"
        echo ""
        echo "Full report saved to: $OUTPUT_DIR/panic_report.txt"
    fi
else
    echo "WARNING: kmutil not found. Install Xcode Command Line Tools."
fi

echo ""
echo "=== Panic File Info ==="
ls -lh "$PANIC_FILE"
file "$PANIC_FILE"

echo ""
echo "=== Recommendations ==="
echo "1. Review panic_report.txt for backtrace"
echo "2. Check for recent kernel extension changes"
echo "3. Verify KDK matches running kernel version"
echo "4. For live debugging, set up KDP:"
echo "   sudo nvram boot-args='debug=0x100 kdp_match_name=hostname'"
echo ""
echo "Analysis output: $OUTPUT_DIR/"
