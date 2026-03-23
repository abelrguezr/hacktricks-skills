#!/bin/bash
# Find weak linked libraries in macOS binaries
# Usage: ./find_weak_libraries.sh <binary_path> [binary_path2 ...]

if [ -z "$1" ]; then
    echo "Usage: $0 <binary_path> [binary_path2 ...]"
    echo "Example: $0 /usr/bin/ls /Applications/Calculator.app/Contents/MacOS/Calculator"
    exit 1
fi

echo "=== Weak Linked Library Analysis ==="
echo ""

for BINARY in "$@"; do
    if [ ! -f "$BINARY" ]; then
        echo "[!] File not found: $BINARY"
        continue
    fi
    
    echo "--- $BINARY ---"
    
    # Find LC_LOAD_WEAK_DYLIB entries
    WEAK_LIBS=$(otool -l "$BINARY" 2>/dev/null | grep -A 5 "LC_LOAD_WEAK_DYLIB")
    
    if [ -z "$WEAK_LIBS" ]; then
        echo "[+] No weak linked libraries found"
    else
        echo "[!] Weak linked libraries found:"
        echo "$WEAK_LIBS" | grep "name " | while read -r line; do
            LIB_PATH=$(echo "$line" | awk '{print $2}')
            echo "  - $LIB_PATH"
            
            # Check if library exists
            if [ -f "$LIB_PATH" ]; then
                echo "    [i] Library exists at this path"
            else
                echo "    [!] Library MISSING - potential hijack target"
                
                # Check if path is writable
                LIB_DIR=$(dirname "$LIB_PATH")
                if [ -d "$LIB_DIR" ]; then
                    if [ -w "$LIB_DIR" ]; then
                        echo "    [!] Directory is writable - HIGH RISK"
                    else
                        echo "    [i] Directory is not writable"
                    fi
                else
                    echo "    [i] Directory does not exist"
                fi
            fi
        done
    fi
    echo ""
done

echo "=== Notes ==="
echo "Weak linked libraries (LC_LOAD_WEAK_DYLIB) are optional dependencies."
echo "If the library is missing, the application continues running."
echo "This makes them potential hijack targets if:"
echo "  1. The library path is writable by the attacker"
echo "  2. Library validation restrictions are satisfied"
echo "  3. The binary is executed with appropriate privileges"
