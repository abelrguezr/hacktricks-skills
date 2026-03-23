#!/bin/bash
# macOS Bundle RPATH Analyzer
# Analyze rpaths and linked libraries for potential vulnerabilities

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-bundle>"
    echo "Example: $0 /Applications/Safari.app"
    exit 1
fi

BUNDLE_PATH="$1"

if [ ! -d "$BUNDLE_PATH" ]; then
    echo "Error: Path does not exist: $BUNDLE_PATH"
    exit 1
fi

echo "========================================"
echo "macOS Bundle RPATH Analyzer"
echo "========================================"
echo "Bundle: $BUNDLE_PATH"
echo ""

# Get executable name
EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$BUNDLE_PATH/Contents/Info.plist" 2>/dev/null)

if [ -z "$EXECUTABLE_NAME" ]; then
    echo "[!] Cannot determine executable name from Info.plist"
    exit 1
fi

EXECUTABLE_PATH="$BUNDLE_PATH/Contents/MacOS/$EXECUTABLE_NAME"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "[!] Executable not found: $EXECUTABLE_PATH"
    exit 1
fi

echo "--- Executable: $EXECUTABLE_NAME ---"
echo ""

echo "--- RPATH Entries ---"
echo "RPATHs define runtime library search paths."
echo "@executable_path and @rpath can be vulnerable to hijacking."
echo ""

RPATHS=$(otool -l "$EXECUTABLE_PATH" 2>/dev/null | grep -A1 "RPATH" | grep "path" || true)

if [ -n "$RPATHS" ]; then
    echo "$RPATHS"
    
    # Check for potentially vulnerable rpaths
    if echo "$RPATHS" | grep -q "@executable_path"; then
        echo ""
        echo "[!] WARNING: @executable_path found in RPATH"
        echo "   Libraries may be loaded relative to executable location"
    fi
    
    if echo "$RPATHS" | grep -q "@rpath"; then
        echo ""
        echo "[!] WARNING: @rpath found in RPATH"
        echo "   Runtime path resolution may be vulnerable to hijacking"
    fi
    
    if echo "$RPATHS" | grep -q "@loader_path"; then
        echo ""
        echo "[!] WARNING: @loader_path found in RPATH"
        echo "   Libraries may be loaded relative to loader location"
    fi
else
    echo "[+] No RPATH entries found"
fi

echo ""
echo "--- Linked Libraries ---"
echo "Libraries loaded by this executable:"
echo ""

otool -L "$EXECUTABLE_PATH" 2>/dev/null | while read line; do
    if echo "$line" | grep -q "@rpath"; then
        echo "[!] $line"
    elif echo "$line" | grep -q "@executable_path"; then
        echo "[!] $line"
    elif echo "$line" | grep -q "@loader_path"; then
        echo "[!] $line"
    else
        echo "  $line"
    fi
done

echo ""
echo "--- Bundle Frameworks ---"
if [ -d "$BUNDLE_PATH/Contents/Frameworks" ]; then
    echo "Frameworks found in bundle:"
    ls -la "$BUNDLE_PATH/Contents/Frameworks/" 2>/dev/null || echo "[!] Cannot read Frameworks directory"
else
    echo "[+] No Frameworks directory in bundle"
fi

echo ""
echo "--- Bundle PlugIns ---"
if [ -d "$BUNDLE_PATH/Contents/PlugIns" ]; then
    echo "PlugIns found in bundle:"
    ls -la "$BUNDLE_PATH/Contents/PlugIns/" 2>/dev/null || echo "[!] Cannot read PlugIns directory"
else
    echo "[+] No PlugIns directory in bundle"
fi

echo ""
echo "--- Vulnerability Assessment ---"
echo ""

# Check for common vulnerability patterns
VULNERABILITY_SCORE=0

if otool -L "$EXECUTABLE_PATH" 2>/dev/null | grep -q "@rpath"; then
    echo "[!] Uses @rpath in library loading"
    VULNERABILITY_SCORE=$((VULNERABILITY_SCORE + 1))
fi

if otool -L "$EXECUTABLE_PATH" 2>/dev/null | grep -q "@executable_path"; then
    echo "[!] Uses @executable_path in library loading"
    VULNERABILITY_SCORE=$((VULNERABILITY_SCORE + 1))
fi

if [ -d "$BUNDLE_PATH/Contents/Frameworks" ]; then
    echo "[!] Contains bundled Frameworks (potential hijacking vector)"
    VULNERABILITY_SCORE=$((VULNERABILITY_SCORE + 1))
fi

if [ -d "$BUNDLE_PATH/Contents/PlugIns" ]; then
    echo "[!] Contains bundled PlugIns (potential hijacking vector)"
    VULNERABILITY_SCORE=$((VULNERABILITY_SCORE + 1))
fi

if [ $VULNERABILITY_SCORE -eq 0 ]; then
    echo "[+] No obvious RPATH-related vulnerabilities detected"
else
    echo ""
    echo "Vulnerability score: $VULNERABILITY_SCORE/4"
    echo "Higher scores indicate more potential attack vectors"
fi

echo ""
echo "========================================"
echo "RPATH analysis complete"
echo "========================================"
