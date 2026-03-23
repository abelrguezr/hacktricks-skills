#!/bin/bash
# PDF Quick Triage Script
# Performs initial security assessment of a PDF file

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <pdf-file> [output-dir]"
    echo "Example: $0 suspicious.pdf ./analysis"
    exit 1
fi

PDF_FILE="$1"
OUTPUT_DIR="${2:-./pdf-analysis-$(date +%Y%m%d-%H%M%S)}"

if [ ! -f "$PDF_FILE" ]; then
    echo "Error: File not found: $PDF_FILE"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== PDF Quick Triage ==="
echo "File: $PDF_FILE"
echo "Output: $OUTPUT_DIR"
echo ""

# 1. Basic file info
echo "--- File Information ---"
file "$PDF_FILE" > "$OUTPUT_DIR/file-info.txt"
cat "$OUTPUT_DIR/file-info.txt"
echo ""

# 2. Check PDF magic bytes
echo "--- PDF Magic Bytes ---"
head -c 8 "$PDF_FILE" | xxd > "$OUTPUT_DIR/magic-bytes.txt"
cat "$OUTPUT_DIR/magic-bytes.txt"
echo ""

# 3. Count EOF markers (incremental updates indicator)
echo "--- EOF Markers ---"
EOF_COUNT=$(grep -c '%%EOF' "$PDF_FILE" 2>/dev/null || echo "0")
echo "%%EOF count: $EOF_COUNT"
echo "%%EOF count: $EOF_COUNT" > "$OUTPUT_DIR/analysis-summary.txt"
if [ "$EOF_COUNT" -gt 1 ]; then
    echo "WARNING: Multiple EOF markers detected - possible incremental updates"
    echo "WARNING: Multiple EOF markers detected" >> "$OUTPUT_DIR/analysis-summary.txt"
fi
echo ""

# 4. Check for polyglot indicators
echo "--- Polyglot Detection ---"
if grep -qa '<w:WordDocument>' "$PDF_FILE" 2>/dev/null; then
    echo "WARNING: Word document markers found - possible MalDoc polyglot"
    echo "WARNING: Word document markers found" >> "$OUTPUT_DIR/analysis-summary.txt"
else
    echo "No Word document markers detected"
fi
echo ""

# 5. Count suspicious objects
echo "--- Suspicious Object Counts ---"
for obj in "/JS" "/JavaScript" "/OpenAction" "/AA" "/Launch" "/EmbeddedFile" "/URI" "/GoToE"; do
    COUNT=$(grep -c "$obj" "$PDF_FILE" 2>/dev/null || echo "0")
    echo "$obj: $COUNT"
    if [ "$COUNT" -gt 0 ]; then
        echo "$obj: $COUNT" >> "$OUTPUT_DIR/analysis-summary.txt"
    fi
done
echo ""

# 6. Check for multiple catalogs
echo "--- Catalog Objects ---"
CATALOG_COUNT=$(grep -c '/Catalog' "$PDF_FILE" 2>/dev/null || echo "0")
echo "/Catalog count: $CATALOG_COUNT"
if [ "$CATALOG_COUNT" -gt 1 ]; then
    echo "WARNING: Multiple catalog objects detected - possible shadow updates"
    echo "WARNING: Multiple catalog objects detected" >> "$OUTPUT_DIR/analysis-summary.txt"
fi
echo ""

# 7. Extract XMP metadata if present
echo "--- XMP Metadata ---"
if grep -q 'x:xmpMetadata' "$PDF_FILE" 2>/dev/null; then
    echo "XMP metadata found - extracting..."
    grep -oP '(?<=x:xmpMetadata).*(?=endstream)' "$PDF_FILE" > "$OUTPUT_DIR/xmp-metadata.txt" 2>/dev/null || true
    echo "Saved to: $OUTPUT_DIR/xmp-metadata.txt"
else
    echo "No XMP metadata found"
fi
echo ""

# 8. Check for base64 encoded content
echo "--- Base64 Detection ---"
BASE64_LINES=$(grep -c '[A-Za-z0-9+/=]\{50,\}' "$PDF_FILE" 2>/dev/null || echo "0")
echo "Potential base64 blocks: $BASE64_LINES"
if [ "$BASE64_LINES" -gt 5 ]; then
    echo "WARNING: High number of potential base64 blocks"
    echo "WARNING: High number of potential base64 blocks" >> "$OUTPUT_DIR/analysis-summary.txt"
fi
echo ""

# 9. Check for suspicious executables
echo "--- Suspicious Executable References ---"
for exe in "powershell" "cmd.exe" "calc.exe" "mshta" "wscript" "cscript" "certutil" "bitsadmin"; do
    if grep -qi "$exe" "$PDF_FILE" 2>/dev/null; then
        echo "WARNING: Found reference to: $exe"
        echo "WARNING: Found reference to: $exe" >> "$OUTPUT_DIR/analysis-summary.txt"
    fi
done
echo ""

# 10. Run pdfid if available
echo "--- PDFiD Analysis ---"
if command -v pdfid.py &> /dev/null; then
    pdfid.py "$PDF_FILE" > "$OUTPUT_DIR/pdfid-output.txt" 2>&1 || echo "pdfid.py failed"
    cat "$OUTPUT_DIR/pdfid-output.txt"
else
    echo "pdfid.py not installed - run: pip install pdfid"
fi
echo ""

echo "=== Triage Complete ==="
echo "Summary saved to: $OUTPUT_DIR/analysis-summary.txt"
echo "Full output directory: $OUTPUT_DIR"
