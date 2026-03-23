#!/bin/bash
# Mini Dump Crash Report Analysis Script
# Analyzes small crash dumps (KB to few MB)

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <mini_dump_file> [options]"
    echo "Options:"
    echo "  --vs        Analyze with Visual Studio (if available)"
    echo "  --ida       Analyze with IDA Pro (if available)"
    echo "  --radare    Analyze with Radare2 (if available)"
    echo "  --strings   Extract strings from dump"
    echo "  --output    Specify output directory (default: ./mini-dump-results/)"
    exit 1
fi

DUMP_FILE="$1"
OUTPUT_DIR="./mini-dump-results/"
USE_VS=false
USE_IDA=false
USE_RADARE=false
EXTRACT_STRINGS=false

# Parse options
shift
while [[ $# -gt 0 ]]; do
    case $1 in
        --vs)
            USE_VS=true
            shift
            ;;
        --ida)
            USE_IDA=true
            shift
            ;;
        --radare)
            USE_RADARE=true
            shift
            ;;
        --strings)
            EXTRACT_STRINGS=true
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check file size to confirm it's a mini dump
FILE_SIZE=$(stat -f%z "$DUMP_FILE" 2>/dev/null || stat -c%s "$DUMP_FILE" 2>/dev/null)
FILE_SIZE_MB=$((FILE_SIZE / 1024 / 1024))

echo "=== Mini Dump Analysis ==="
echo "File: $DUMP_FILE"
echo "Size: $FILE_SIZE bytes ($FILE_SIZE_MB MB)"
echo ""

# Extract basic information
echo "=== Basic Information ==="

# Check file type
file "$DUMP_FILE" > "$OUTPUT_DIR/file-type.txt"
cat "$OUTPUT_DIR/file-type.txt"
echo ""

# Extract strings if requested
if [ "$EXTRACT_STRINGS" = true ]; then
    echo "=== Extracting Strings ==="
    strings "$DUMP_FILE" > "$OUTPUT_DIR/strings.txt" 2>/dev/null || true
    
    # Look for interesting patterns
    echo "Searching for IP addresses..."
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' "$OUTPUT_DIR/strings.txt" | sort -u > "$OUTPUT_DIR/ips.txt" 2>/dev/null || true
    
    echo "Searching for URLs..."
    grep -oE 'https?://[^ ]+' "$OUTPUT_DIR/strings.txt" | sort -u > "$OUTPUT_DIR/urls.txt" 2>/dev/null || true
    
    echo "Searching for file paths..."
    grep -oE '[A-Za-z]:\\[^ ]+' "$OUTPUT_DIR/strings.txt" | sort -u > "$OUTPUT_DIR/paths.txt" 2>/dev/null || true
    
    echo "Strings extracted to: $OUTPUT_DIR/strings.txt"
    echo ""
fi

# Visual Studio analysis
if [ "$USE_VS" = true ]; then
    echo "=== Visual Studio Analysis ==="
    if command -v devenv &> /dev/null || [ -d "/Applications/Visual Studio.app" ]; then
        echo "Visual Studio found. Opening dump file..."
        echo "Instructions:"
        echo "1. Open Visual Studio"
        echo "2. Go to Debug > Start Debugging > Open Dump File"
        echo "3. Select: $DUMP_FILE"
        echo "4. View:"
        echo "   - Process name and architecture"
        echo "   - Exception information"
        echo "   - Loaded modules"
        echo "   - Decompiled instructions"
        echo ""
        echo "For automated analysis, use:"
        echo "  devenv /debug $DUMP_FILE"
    else
        echo "Visual Studio not found. Install Visual Studio for mini dump analysis."
    fi
    echo ""
fi

# IDA Pro analysis
if [ "$USE_IDA" = true ]; then
    echo "=== IDA Pro Analysis ==="
    if command -v idaq &> /dev/null || command -v idag &> /dev/null; then
        echo "IDA Pro found. Opening dump file..."
        echo "Instructions:"
        echo "1. Open IDA Pro"
        echo "2. File > Open > Select: $DUMP_FILE"
        echo "3. Analyze the exception context"
        echo "4. Examine memory regions"
        echo "5. Look for malicious code patterns"
        echo ""
    else
        echo "IDA Pro not found. Install IDA Pro for deep analysis."
    fi
    echo ""
fi

# Radare2 analysis
if [ "$USE_RADARE" = true ]; then
    echo "=== Radare2 Analysis ==="
    if command -v r2 &> /dev/null; then
        echo "Radare2 found. Analyzing dump..."
        
        # Basic analysis
        r2 -qc 'i' "$DUMP_FILE" > "$OUTPUT_DIR/radare-info.txt" 2>/dev/null || true
        r2 -qc 'iz' "$DUMP_FILE" > "$OUTPUT_DIR/radare-strings.txt" 2>/dev/null || true
        r2 -qc 'aa' "$DUMP_FILE" > "$OUTPUT_DIR/radare-analysis.txt" 2>/dev/null || true
        
        echo "Radare2 analysis saved to:"
        echo "  - $OUTPUT_DIR/radare-info.txt"
        echo "  - $OUTPUT_DIR/radare-strings.txt"
        echo "  - $OUTPUT_DIR/radare-analysis.txt"
        echo ""
        
        echo "For interactive analysis, run:"
        echo "  r2 $DUMP_FILE"
    else
        echo "Radare2 not found. Install with:"
        echo "  macOS: brew install radare2"
        echo "  Linux: apt install radare2"
    fi
    echo ""
fi

# Generate summary
echo "=== Analysis Complete ==="
echo "Results saved to: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Review extracted strings for suspicious content"
echo "2. Check IP addresses and URLs against threat intelligence"
echo "3. Use IDA or Radare2 for deeper code analysis"
echo "4. Correlate with other forensic evidence"
