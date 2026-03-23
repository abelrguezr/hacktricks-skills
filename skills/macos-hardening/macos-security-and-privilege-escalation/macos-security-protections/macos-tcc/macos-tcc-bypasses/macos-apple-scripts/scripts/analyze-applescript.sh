#!/bin/bash
# macOS AppleScript Analyzer
# Analyzes .scpt files for security assessment

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <script-file.scpt> [options]"
    echo "Options:"
    echo "  --decompile    Attempt to decompile the script"
    echo "  --disassemble  Disassemble the script (requires applescript-disassembler)"
    echo "  --scan         Scan for suspicious patterns"
    echo "  --all          Run all analysis steps"
    exit 1
fi

SCRIPT_FILE="$1"
shift

if [ ! -f "$SCRIPT_FILE" ]; then
    echo "Error: File not found: $SCRIPT_FILE"
    exit 1
fi

echo "=== AppleScript Analysis ==="
echo "File: $SCRIPT_FILE"
echo ""

# Step 1: Check file type
echo "[1/4] Checking file type..."
FILE_TYPE=$(file "$SCRIPT_FILE")
echo "$FILE_TYPE"
echo ""

# Step 2: Attempt decompile
if [[ "$*" == *"--decompile"* ]] || [[ "$*" == *"--all"* ]]; then
    echo "[2/4] Attempting to decompile..."
    if command -v osadecompile &> /dev/null; then
        DECOMPILE_OUTPUT=$(osadecompile "$SCRIPT_FILE" 2>&1) || true
        if [ -n "$DECOMPILE_OUTPUT" ]; then
            echo "$DECOMPILE_OUTPUT"
        else
            echo "Decompile failed - script may be read-only"
        fi
    else
        echo "osadecompile not found (macOS only)"
    fi
    echo ""
fi

# Step 3: Disassemble if needed
if [[ "$*" == *"--disassemble"* ]] || [[ "$*" == *"--all"* ]]; then
    echo "[3/4] Attempting to disassemble..."
    if command -v applescript-disassembler &> /dev/null; then
        DISASSEMBLE_OUTPUT=$(applescript-disassembler "$SCRIPT_FILE" 2>&1) || true
        if [ -n "$DISASSEMBLE_OUTPUT" ]; then
            echo "$DISASSEMBLE_OUTPUT"
        else
            echo "Disassembly failed"
        fi
    else
        echo "applescript-disassembler not found"
        echo "Install from: https://github.com/Jinmo/applescript-disassembler"
    fi
    echo ""
fi

# Step 4: Security scan
if [[ "$*" == *"--scan"* ]] || [[ "$*" == *"--all"* ]]; then
    echo "[4/4] Scanning for suspicious patterns..."
    
    # Try to get content (decompiled or disassembled)
    CONTENT=""
    if command -v osadecompile &> /dev/null; then
        CONTENT=$(osadecompile "$SCRIPT_FILE" 2>/dev/null) || true
    fi
    
    if [ -z "$CONTENT" ]; then
        echo "Could not extract content for pattern scanning"
        echo "Try --disassemble first if script is read-only"
    else
        echo "Checking for high-risk patterns:"
        
        # Process interaction
        if echo "$CONTENT" | grep -qi "tell process"; then
            echo "  ⚠️  HIGH: Process interaction detected"
            echo "$CONTENT" | grep -i "tell process" | head -3
        fi
        
        # UI automation
        if echo "$CONTENT" | grep -qi "click button"; then
            echo "  ⚠️  HIGH: UI automation (click) detected"
            echo "$CONTENT" | grep -i "click button" | head -3
        fi
        
        # Shell execution
        if echo "$CONTENT" | grep -qi "do shell script"; then
            echo "  ⚠️  MEDIUM: Shell script execution detected"
            echo "$CONTENT" | grep -i "do shell script" | head -3
        fi
        
        # Browser interaction
        if echo "$CONTENT" | grep -qi "tell application.*Safari\|tell application.*Chrome\|tell application.*Firefox"; then
            echo "  ⚠️  MEDIUM: Browser interaction detected"
            echo "$CONTENT" | grep -i "tell application.*Safari\|tell application.*Chrome\|tell application.*Firefox" | head -3
        fi
        
        # JavaScript injection
        if echo "$CONTENT" | grep -qi "do JavaScript"; then
            echo "  ⚠️  HIGH: JavaScript injection detected"
            echo "$CONTENT" | grep -i "do JavaScript" | head -3
        fi
        
        echo ""
        echo "Pattern scan complete"
    fi
fi

echo ""
echo "=== Analysis Complete ==="
echo "For read-only scripts, use:"
echo "  applescript-disassembler <file.scpt>"
echo "  aevt_decompile <output>"
echo ""
echo "Resources:"
echo "  https://github.com/Jinmo/applescript-disassembler"
echo "  https://github.com/SentineLabs/aevt_decompile"
echo "  https://labs.sentinelone.com/fade-dead-adventures-in-reversing-malicious-run-only-applescripts/"
