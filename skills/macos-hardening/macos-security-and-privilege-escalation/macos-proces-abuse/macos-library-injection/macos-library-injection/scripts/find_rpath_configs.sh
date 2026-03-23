#!/bin/bash
# Find rpath configurations in macOS binaries
# Usage: ./find_rpath_configs.sh <binary_path> [binary_path2 ...]

if [ -z "$1" ]; then
    echo "Usage: $0 <binary_path> [binary_path2 ...]"
    echo "Example: $0 /usr/bin/ls /Applications/Calculator.app/Contents/MacOS/Calculator"
    exit 1
fi

echo "=== RPATH Configuration Analysis ==="
echo ""

for BINARY in "$@"; do
    if [ ! -f "$BINARY" ]; then
        echo "[!] File not found: $BINARY"
        continue
    fi
    
    echo "--- $BINARY ---"
    
    # Find LC_RPATH entries
    echo "RPATH directories:"
    RPATHS=$(otool -l "$BINARY" 2>/dev/null | grep -A 2 "LC_RPATH")
    
    if [ -z "$RPATHS" ]; then
        echo "  [i] No rpath directories configured"
    else
        echo "$RPATHS" | grep "path " | while read -r line; do
            PATH_VAL=$(echo "$line" | awk '{print $2}')
            echo "  - $PATH_VAL"
            
            # Check if path is writable
            if [ -d "$PATH_VAL" ]; then
                if [ -w "$PATH_VAL" ]; then
                    echo "    [!] Directory is writable - potential hijack target"
                else
                    echo "    [i] Directory is not writable"
                fi
            else
                echo "    [i] Directory does not exist"
            fi
        done
    fi
    echo ""
    
    # Find LC_LOAD_DYLIB entries with @rpath
    echo "Library load commands with @rpath:"
    LOAD_LIBS=$(otool -l "$BINARY" 2>/dev/null | grep -A 5 "LC_LOAD_DYLIB")
    
    if echo "$LOAD_LIBS" | grep -q "@rpath"; then
        echo "$LOAD_LIBS" | grep "name " | grep "@rpath" | while read -r line; do
            LIB_PATH=$(echo "$line" | awk '{print $2}')
            echo "  - $LIB_PATH"
            echo "    [!] Uses @rpath - will search all rpath directories"
        done
    else
        echo "  [i] No @rpath references found"
    fi
    echo ""
    
    # Find @executable_path and @loader_path references
    echo "Special path references:"
    SPECIAL_PATHS=$(otool -l "$BINARY" 2>/dev/null | grep -E "@executable_path|@loader_path")
    
    if [ -n "$SPECIAL_PATHS" ]; then
        echo "$SPECIAL_PATHS" | while read -r line; do
            echo "  - $line"
        done
        echo "  [!] Special paths found - check for relative path hijacking"
    else
        echo "  [i] No special path references found"
    fi
    echo ""
done

echo "=== Notes ==="
echo "@rpath: Replaced by all LC_RPATH directory values in order"
echo "@executable_path: Directory containing the main executable"
echo "@loader_path: Directory containing the Mach-O binary with the load command"
echo ""
echo "RPATH hijacking is possible when:"
echo "  1. Binary uses @rpath in LC_LOAD_DYLIB"
echo "  2. One of the rpath directories is writable"
echo "  3. Library validation restrictions are satisfied"
