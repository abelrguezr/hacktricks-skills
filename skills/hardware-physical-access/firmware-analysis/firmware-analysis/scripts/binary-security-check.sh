#!/bin/bash
# Binary Security Check Script
# Analyzes compiled binaries for security features

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <binary> [output_file]"
    echo "Analyzes binary for security features (NX, PIE, RELRO, etc.)"
    exit 1
fi

BINARY="$1"
OUTPUT_FILE="${2:-security_check_$(basename "$BINARY").txt}"

if [ ! -f "$BINARY" ]; then
    echo "Error: File not found: $BINARY"
    exit 1
fi

echo "=== Binary Security Check ==="
echo "Target: $BINARY"
echo "Output: $OUTPUT_FILE"
echo ""

# Initialize output
echo "Binary Security Analysis Report" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "Binary: $BINARY" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# File type
echo "[1/5] File type analysis..."
file "$BINARY" >> "$OUTPUT_FILE"
echo "File type: $(file -b "$BINARY")"
echo ""

# Check for checksec.sh
if command -v checksec &> /dev/null; then
    echo "[2/5] Running checksec.sh..."
    checksec --file="$BINARY" >> "$OUTPUT_FILE" 2>&1 || {
        echo "checksec.sh analysis failed or binary not supported"
        echo "checksec.sh analysis failed or binary not supported" >> "$OUTPUT_FILE"
    }
    echo "checksec.sh results saved to output file"
else
    echo "[2/5] checksec.sh not available, using manual checks..."
    echo "checksec.sh not available - using manual checks" >> "$OUTPUT_FILE"
    echo ""
    
    # Manual checks using readelf
    if command -v readelf &> /dev/null; then
        echo "[Manual] Checking ELF headers..."
        
        # Check PIE
        if readelf -h "$BINARY" 2>/dev/null | grep -q "DYN"; then
            echo "PIE: Likely enabled (ET_DYN)" >> "$OUTPUT_FILE"
            echo "PIE: Likely enabled"
        else
            echo "PIE: Disabled (ET_EXEC)" >> "$OUTPUT_FILE"
            echo "PIE: Disabled"
        fi
        
        # Check RELRO
        if readelf -l "$BINARY" 2>/dev/null | grep -q "BIND_NOW"; then
            echo "RELRO: Full" >> "$OUTPUT_FILE"
            echo "RELRO: Full"
        elif readelf -l "$BINARY" 2>/dev/null | grep -q "NOW"; then
            echo "RELRO: Partial" >> "$OUTPUT_FILE"
            echo "RELRO: Partial"
        else
            echo "RELRO: None" >> "$OUTPUT_FILE"
            echo "RELRO: None"
        fi
        
        # Check NX (GNU_STACK)
        if readelf -l "$BINARY" 2>/dev/null | grep -q "GNU_STACK"; then
            if readelf -l "$BINARY" 2>/dev/null | grep "GNU_STACK" | grep -q "RWE"; then
                echo "NX: Disabled (executable stack)" >> "$OUTPUT_FILE"
                echo "NX: Disabled"
            else
                echo "NX: Enabled" >> "$OUTPUT_FILE"
                echo "NX: Enabled"
            fi
        else
            echo "NX: Unknown (no GNU_STACK)" >> "$OUTPUT_FILE"
            echo "NX: Unknown"
        fi
    else
        echo "readelf not available for manual checks"
        echo "readelf not available" >> "$OUTPUT_FILE"
    fi
fi
echo ""

# Architecture detection
echo "[3/5] Architecture detection..."
ARCH=$(file -b "$BINARY" | grep -oP '(?<=ELF ).*(?=,)' || echo "Unknown")
echo "Architecture: $ARCH" >> "$OUTPUT_FILE"
echo "Architecture: $ARCH"
echo ""

# String analysis for potential vulnerabilities
echo "[4/5] Searching for dangerous functions..."
DANGEROUS_FUNCS="strcpy|strcat|sprintf|gets|system|popen|execve|eval"
DANGEROUS=$(strings "$BINARY" | grep -E "$DANGEROUS_FUNCS" | head -20 || true)
if [ -n "$DANGEROUS" ]; then
    echo "[Dangerous Functions]" >> "$OUTPUT_FILE"
    echo "$DANGEROUS" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "Found potentially dangerous functions:"
    echo "$DANGEROUS"
else
    echo "No obvious dangerous functions found"
    echo "No obvious dangerous functions found" >> "$OUTPUT_FILE"
fi
echo ""

# Symbol analysis
echo "[5/5] Symbol analysis..."
if command -v nm &> /dev/null; then
    SYMBOLS=$(nm "$BINARY" 2>/dev/null | wc -l || echo "0")
    echo "Total symbols: $SYMBOLS" >> "$OUTPUT_FILE"
    echo "Total symbols: $SYMBOLS"
    
    # Check for common vulnerability indicators
    VULN_SYMBOLS=$(nm "$BINARY" 2>/dev/null | grep -E "(strcpy|strcat|sprintf|gets)" | head -10 || true)
    if [ -n "$VULN_SYMBOLS" ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "[Vulnerable Symbols]" >> "$OUTPUT_FILE"
        echo "$VULN_SYMBOLS" >> "$OUTPUT_FILE"
        echo "Found vulnerable symbols:"
        echo "$VULN_SYMBOLS"
    fi
else
    echo "nm not available for symbol analysis"
    echo "nm not available" >> "$OUTPUT_FILE"
fi
echo ""

echo "=== Analysis Complete ==="
echo "Results saved to: $OUTPUT_FILE"
echo ""
echo "Security features summary:"
grep -E "(PIE|RELRO|NX):" "$OUTPUT_FILE" 2>/dev/null || echo "See output file for details"
