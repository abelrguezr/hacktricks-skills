#!/bin/bash
# PDF Deep Analysis Script
# Comprehensive forensic analysis of PDF files

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <pdf-file> [output-dir]"
    echo "Example: $0 suspicious.pdf ./deep-analysis"
    exit 1
fi

PDF_FILE="$1"
OUTPUT_DIR="${2:-./pdf-deep-analysis-$(date +%Y%m%d-%H%M%S)}"

if [ ! -f "$PDF_FILE" ]; then
    echo "Error: File not found: $PDF_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR/extracted"
mkdir -p "$OUTPUT_DIR/streams"
mkdir -p "$OUTPUT_DIR/javascript"

echo "=== PDF Deep Analysis ==="
echo "File: $PDF_FILE"
echo "Output: $OUTPUT_DIR"
echo ""

# 1. Create clean copy for analysis
echo "--- Preparing Clean Copy ---"
CLEAN_FILE="$OUTPUT_DIR/clean.pdf"
cp "$PDF_FILE" "$CLEAN_FILE"
echo "Working copy: $CLEAN_FILE"
echo ""

# 2. Extract all streams
echo "--- Extracting Streams ---"
if command -v pdf-parser.py &> /dev/null; then
    pdf-parser.py -extract "$PDF_FILE" -o "$OUTPUT_DIR/streams/" 2>&1 || echo "Stream extraction completed with warnings"
    echo "Streams saved to: $OUTPUT_DIR/streams/"
else
    echo "pdf-parser.py not installed - run: pip install pdf-parser"
fi
echo ""

# 3. Search and extract JavaScript
echo "--- JavaScript Extraction ---"
if command -v pdf-parser.py &> /dev/null; then
    echo "Searching for /JS objects..."
    JS_COUNT=$(grep -c '/JS' "$PDF_FILE" 2>/dev/null || echo "0")
    echo "Found $JS_COUNT JavaScript references"
    
    if [ "$JS_COUNT" -gt 0 ]; then
        echo "Extracting JavaScript content..."
        pdf-parser.py -search "/JS" -raw "$PDF_FILE" > "$OUTPUT_DIR/javascript/js-raw.txt" 2>&1 || true
        
        # Try to beautify if js-beautify is available
        if command -v js-beautify &> /dev/null; then
            js-beautify "$OUTPUT_DIR/javascript/js-raw.txt" > "$OUTPUT_DIR/javascript/js-beautified.txt" 2>/dev/null || true
            echo "JavaScript beautified and saved"
        fi
        
        # Decode base64 if present
        echo "Checking for base64 encoded JavaScript..."
        grep -oP '[A-Za-z0-9+/=]{100,}' "$OUTPUT_DIR/javascript/js-raw.txt" 2>/dev/null | while read -r b64; do
            echo "Decoding base64 block..."
            echo "$b64" | base64 -d 2>/dev/null >> "$OUTPUT_DIR/javascript/js-decoded.txt" || true
        done
    fi
else
    echo "pdf-parser.py not installed"
fi
echo ""

# 4. Extract embedded files
echo "--- Embedded File Extraction ---"
if command -v peepdf &> /dev/null; then
    echo "Scanning for embedded files..."
    peepdf "open $PDF_FILE" "objects embeddedfile" > "$OUTPUT_DIR/embedded-files.txt" 2>&1 || true
    
    # Extract embedded files if found
    if grep -q 'EmbeddedFile' "$OUTPUT_DIR/embedded-files.txt" 2>/dev/null; then
        echo "Embedded files found - extracting..."
        # Extract all embedded file objects
        peepdf "open $PDF_FILE" "objects embeddedfile" "extract all" -o "$OUTPUT_DIR/extracted/" 2>&1 || true
        echo "Embedded files saved to: $OUTPUT_DIR/extracted/"
    else
        echo "No embedded files found"
    fi
else
    echo "peepdf not installed - run: pip install peepdf"
fi
echo ""

# 5. Decrypt if password protected
echo "--- Decryption Check ---"
if command -v qpdf &> /dev/null; then
    # Check if encrypted
    if qpdf --show-encryption "$PDF_FILE" &> /dev/null; then
        echo "File appears to be encrypted"
        echo "To decrypt, use: qpdf --password='<password>' --decrypt $PDF_FILE decrypted.pdf"
    else
        echo "File is not encrypted"
    fi
    
    # Create linearized version
    echo "Creating linearized version..."
    qpdf --qdf "$PDF_FILE" "$OUTPUT_DIR/linearized.pdf" 2>&1 || true
    echo "Linearized version: $OUTPUT_DIR/linearized.pdf"
else
    echo "qpdf not installed - run: apt install qpdf"
fi
echo ""

# 6. Validate PDF structure
echo "--- PDF Validation ---"
if command -v pdfcpu &> /dev/null; then
    echo "Validating PDF structure..."
    pdfcpu validate -mode strict "$PDF_FILE" > "$OUTPUT_DIR/validation.txt" 2>&1 || true
    cat "$OUTPUT_DIR/validation.txt"
else
    echo "pdfcpu not installed - run: go install github.com/pdfcpu/pdfcpu/cmd/pdfcpu@latest"
fi
echo ""

# 7. Extract metadata
echo "--- Metadata Extraction ---"
if command -v exiftool &> /dev/null; then
    exiftool "$PDF_FILE" > "$OUTPUT_DIR/metadata.txt" 2>&1 || true
    echo "Metadata saved to: $OUTPUT_DIR/metadata.txt"
else
    echo "exiftool not installed"
fi
echo ""

# 8. Generate YARA rule for this file
echo "--- YARA Rule Generation ---"
cat > "$OUTPUT_DIR/detection-rule.yar" << 'YARA_EOF'
rule Suspicious_PDF_Custom {
    meta:
        description = "Custom detection rule for analyzed PDF"
        author      = "PDF Forensics Analysis"
        last_update = "$(date +%Y-%m-%d)"
    strings:
        $pdf_magic = { 25 50 44 46 }
        $aa        = "/AA" ascii nocase
        $openact   = "/OpenAction" ascii nocase
        $js        = "/JS" ascii nocase
        $launch    = "/Launch" ascii nocase
        $embedded  = "/EmbeddedFile" ascii nocase
        $worddoc   = "<w:WordDocument>" ascii
    condition:
        $pdf_magic at 0 and (
            ($aa and $js) or 
            ($openact and $js) or 
            $launch or 
            $embedded or
            $worddoc
        )
}
YARA_EOF
echo "YARA rule saved to: $OUTPUT_DIR/detection-rule.yar"
echo ""

# 9. Create analysis summary
echo "--- Creating Summary ---"
cat > "$OUTPUT_DIR/ANALYSIS-SUMMARY.md" << SUMMARY_EOF
# PDF Forensic Analysis Summary

**File:** $PDF_FILE
**Analysis Date:** $(date)
**Output Directory:** $OUTPUT_DIR

## Quick Findings

- **JavaScript Objects:** $(grep -c '/JS' "$PDF_FILE" 2>/dev/null || echo "0")
- **OpenAction Objects:** $(grep -c '/OpenAction' "$PDF_FILE" 2>/dev/null || echo "0")
- **AA Objects:** $(grep -c '/AA' "$PDF_FILE" 2>/dev/null || echo "0")
- **Embedded Files:** $(grep -c '/EmbeddedFile' "$PDF_FILE" 2>/dev/null || echo "0")
- **EOF Markers:** $(grep -c '%%EOF' "$PDF_FILE" 2>/dev/null || echo "0")
- **Catalog Objects:** $(grep -c '/Catalog' "$PDF_FILE" 2>/dev/null || echo "0")

## Files Generated

- `streams/` - Extracted PDF streams
- `extracted/` - Embedded files
- `javascript/` - JavaScript content (raw, beautified, decoded)
- `metadata.txt` - File metadata
- `validation.txt` - PDF structure validation
- `detection-rule.yar` - YARA detection rule
- `linearized.pdf` - Linearized version of PDF

## Next Steps

1. Review JavaScript content in `javascript/` directory
2. Analyze extracted embedded files in `extracted/` directory
3. Check validation results for structural anomalies
4. Run YARA rule against file collection if needed
5. Open linearized.pdf in sandboxed environment if safe
SUMMARY_EOF
echo "Summary saved to: $OUTPUT_DIR/ANALYSIS-SUMMARY.md"
echo ""

echo "=== Deep Analysis Complete ==="
echo "Review the summary at: $OUTPUT_DIR/ANALYSIS-SUMMARY.md"
