#!/bin/bash
# Objective-C Compilation Helper
# Compiles Objective-C source files with proper framework linking

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <source_file.m> [options]"
    echo "Options:"
    echo "  -o, --output <name>    Output binary name (default: a.out)"
    echo "  -f, --framework <name> Additional framework to link"
    echo "  -d, --debug            Include debug symbols"
    exit 1
fi

SOURCE_FILE="$1"
shift

OUTPUT_NAME="a.out"
FRAMEWORKS=("Foundation")
DEBUG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_NAME="$2"
            shift 2
            ;;
        -f|--framework)
            FRAMEWORKS+=("$2")
            shift 2
            ;;
        -d|--debug)
            DEBUG=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file not found: $SOURCE_FILE"
    exit 1
fi

if ! command -v clang &> /dev/null; then
    echo "Error: clang not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

echo "=== Compiling Objective-C ==="
echo "Source: $SOURCE_FILE"
echo "Output: $OUTPUT_NAME"
echo "Frameworks: ${FRAMEWORKS[*]}"
echo ""

# Build framework flags
FRAMEWORK_FLAGS=""
for framework in "${FRAMEWORKS[@]}"; do
    FRAMEWORK_FLAGS="$FRAMEWORK_FLAGS -framework $framework"
done

# Build debug flags
DEBUG_FLAGS=""
[ "$DEBUG" = true ] && DEBUG_FLAGS="-g -O0"

# Compile
echo "Compiling..."
clang $DEBUG_FLAGS $FRAMEWORK_FLAGS "$SOURCE_FILE" -o "$OUTPUT_NAME"

echo ""
echo "=== Compilation Successful ==="
echo "Binary: $OUTPUT_NAME"

if [ "$DEBUG" = true ]; then
    echo ""
    echo "Debug symbols included. Use with:"
    echo "  lldb $OUTPUT_NAME"
    echo "  otool -tv $OUTPUT_NAME"
fi
