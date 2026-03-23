#!/bin/bash
# Quick debug script for dyld loading behavior
# Usage: ./debug_dyld_loading.sh <binary_path> [options]

BINARY="${1:-}"

if [[ -z "$BINARY" ]]; then
    echo "Usage: $0 <binary_path> [options]"
    echo "Options:"
    echo "  --libs       Print loaded libraries"
    echo "  --segments   Print segment mappings"
    echo "  --init       Print initializers"
    echo "  --all        Print all debug info"
    echo "  --file=path  Write output to file"
    exit 1
fi

if [[ ! -f "$BINARY" ]]; then
    echo "Error: File not found: $BINARY"
    exit 1
fi

OUTPUT_FILE=""
RUN_LIBS=0
RUN_SEGMENTS=0
RUN_INIT=0
RUN_ALL=0

# Parse options
while [[ $# -gt 1 ]]; do
    case $1 in
        --libs)
            RUN_LIBS=1
            shift
            ;;
        --segments)
            RUN_SEGMENTS=1
            shift
            ;;
        --init)
            RUN_INIT=1
            shift
            ;;
        --all)
            RUN_ALL=1
            shift
            ;;
        --file=*)
            OUTPUT_FILE="${1#*=}"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set defaults
if [[ $RUN_ALL -eq 1 ]]; then
    RUN_LIBS=1
    RUN_SEGMENTS=1
    RUN_INIT=1
fi

if [[ $RUN_LIBS -eq 0 && $RUN_SEGMENTS -eq 0 && $RUN_INIT -eq 0 ]]; then
    RUN_LIBS=1
fi

# Output function
output() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$1" >> "$OUTPUT_FILE"
    else
        echo "$1"
    fi
}

# Clear output file if specified
if [[ -n "$OUTPUT_FILE" ]]; then
    > "$OUTPUT_FILE"
fi

output "Dyld Debug Analysis: $BINARY"
output "==========================================="
output ""

if [[ $RUN_LIBS -eq 1 ]]; then
    output "Loaded Libraries:"
    output "-----------------"
    DYLD_PRINT_LIBRARIES=1 "$BINARY" 2>&1 | head -50
    output ""
fi

if [[ $RUN_SEGMENTS -eq 1 ]]; then
    output "Segment Mappings:"
    output "-----------------"
    DYLD_PRINT_SEGMENTS=1 "$BINARY" 2>&1 | head -50
    output ""
fi

if [[ $RUN_INIT -eq 1 ]]; then
    output "Initializers:"
    output "-------------"
    DYLD_PRINT_INITIALIZERS=1 "$BINARY" 2>&1 | head -50
    output ""
fi

if [[ -n "$OUTPUT_FILE" ]]; then
    output ""
    output "Output written to: $OUTPUT_FILE"
else
    echo ""
    echo "Done."
fi
