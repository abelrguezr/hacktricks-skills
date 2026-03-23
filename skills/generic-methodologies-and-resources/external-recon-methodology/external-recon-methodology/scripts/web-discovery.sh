#!/bin/bash
# Web Server Discovery and Screenshot Script
# Usage: ./web-discovery.sh <input-file-with-domains>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <input-file-with-domains>"
    echo "Example: $0 subdomains.txt"
    exit 1
fi

INPUT_FILE="$1"
TARGET=$(basename "$INPUT_FILE" .txt)
OUTPUT_DIR="./recon-output/${TARGET}"
mkdir -p "$OUTPUT_DIR"

echo "[*] Web Discovery for: $TARGET"
echo "[*] Input file: $INPUT_FILE"
echo "[*] Output directory: $OUTPUT_DIR"

WEB_SERVERS_FILE="$OUTPUT_DIR/web_servers.txt"
SCREENSHOTS_DIR="$OUTPUT_DIR/screenshots"
mkdir -p "$SCREENSHOTS_DIR"

# Find web servers
echo ""
echo "========================================"
echo "Phase 1: Web Server Discovery"
echo "========================================"

if command -v httprobe &> /dev/null; then
    echo "[*] Running httprobe..."
    cat "$INPUT_FILE" | httprobe 2>/dev/null > "$WEB_SERVERS_FILE" || true
    WEB_COUNT=$(wc -l < "$WEB_SERVERS_FILE")
    echo "[*] Found $WEB_COUNT web servers"
else
    echo "[!] httprobe not found - installing..."
    echo "    go install github.com/tomnomnom/httprobe@latest"
    exit 1
fi

# Also try httpx for more details
echo ""
echo "[*] Running httpx for additional details..."
if command -v httpx &> /dev/null; then
    httpx -l "$INPUT_FILE" -title -tech-detect -o "$OUTPUT_DIR/httpx-results.json" 2>/dev/null || true
    echo "[*] httpx results saved to: $OUTPUT_DIR/httpx-results.json"
else
    echo "[!] httpx not found - skipping detailed analysis"
fi

# Take screenshots
echo ""
echo "========================================"
echo "Phase 2: Screenshot Capture"
echo "========================================"

if command -v gowitness &> /dev/null; then
    echo "[*] Running Gowitness..."
    gowitness file "$WEB_SERVERS_FILE" -o "$SCREENSHOTS_DIR" 2>/dev/null || true
    echo "[*] Screenshots saved to: $SCREENSHOTS_DIR"
    echo "[*] View results: $SCREENSHOTS_DIR/index.html"
elif command -v eyewitness &> /dev/null; then
    echo "[*] Running EyeWitness..."
    eyewitness --file "$WEB_SERVERS_FILE" --webserver 0.0.0.0:8000 2>/dev/null || true
    echo "[*] EyeWitness results available at: http://localhost:8000"
else
    echo "[!] Neither gowitness nor eyewitness found"
    echo "    Install gowitness: go install github.com/sensepost/gowitness/v2@latest"
    echo "    Or use: webscreenshot, aquatone, shutter"
fi

# Analyze screenshots with eyeballer (if available)
echo ""
echo "[*] Running eyeballer analysis..."
if command -v eyeballer &> /dev/null; then
    eyeballer -i "$SCREENSHOTS_DIR" -o "$OUTPUT_DIR/eyeballer-results.json" 2>/dev/null || true
    echo "[*] Eyeballer results saved to: $OUTPUT_DIR/eyeballer-results.json"
else
    echo "[!] eyeballer not found - skipping automated analysis"
    echo "    Install: pip install eyeballer"
fi

# Summary
echo ""
echo "========================================"
echo "Web Discovery Summary"
echo "========================================"
echo "Input: $INPUT_FILE"
echo "Web servers found: $WEB_COUNT"
echo "Web servers list: $WEB_SERVERS_FILE"
echo "Screenshots: $SCREENSHOTS_DIR"
echo "View screenshots: $SCREENSHOTS_DIR/index.html"
echo ""
echo "Next steps:"
echo "  1. Review screenshots: open $SCREENSHOTS_DIR/index.html"
echo "  2. Check eyeballer results for likely vulnerable pages"
echo "  3. Manually inspect interesting endpoints"
echo "  4. Run vulnerability scanners on web applications"
echo "========================================"
