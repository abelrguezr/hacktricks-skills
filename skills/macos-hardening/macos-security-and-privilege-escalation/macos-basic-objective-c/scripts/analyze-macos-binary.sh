#!/bin/bash
# macOS Binary Analysis Helper
# Analyzes Mach-O binaries for Objective-C class information

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <binary_path> [options]"
    echo "Options:"
    echo "  -h, --headers    Include header output"
    echo "  -r, --recursive  Recursive dump for frameworks"
    echo "  -s, --search     Search for sensitive methods"
    echo "  -o, --output     Output file path"
    exit 1
fi

BINARY_PATH="$1"
shift

OUTPUT_FILE=""
INCLUDE_HEADERS=false
RECURSIVE=false
SEARCH_SENSITIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--headers)
            INCLUDE_HEADERS=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        -s|--search)
            SEARCH_SENSITIVE=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ ! -f "$BINARY_PATH" ]; then
    echo "Error: File not found: $BINARY_PATH"
    exit 1
fi

if ! command -v class-dump &> /dev/null; then
    echo "Error: class-dump not found. Install with: brew install class-dump"
    exit 1
fi

echo "=== Analyzing: $BINARY_PATH ==="
echo ""

# Build class-dump command
CLASS_DUMP_CMD="class-dump"
[ "$INCLUDE_HEADERS" = true ] && CLASS_DUMP_CMD="$CLASS_DUMP_CMD -H"
[ "$RECURSIVE" = true ] && CLASS_DUMP_CMD="$CLASS_DUMP_CMD -r"

# Run class-dump
if [ -n "$OUTPUT_FILE" ]; then
    $CLASS_DUMP_CMD "$BINARY_PATH" > "$OUTPUT_FILE"
    echo "Output saved to: $OUTPUT_FILE"
    OUTPUT_CONTENT=$(cat "$OUTPUT_FILE")
else
    OUTPUT_CONTENT=$($CLASS_DUMP_CMD "$BINARY_PATH")
    echo "$OUTPUT_CONTENT"
fi

# Search for sensitive methods if requested
if [ "$SEARCH_SENSITIVE" = true ]; then
    echo ""
    echo "=== Sensitive Method Search ==="
    
    SENSITIVE_PATTERNS=(
        "password"
        "credential"
        "auth"
        "token"
        "key"
        "secret"
        "private"
        "decrypt"
        "encrypt"
        "encode"
        "decode"
        "admin"
        "root"
        "sudo"
        "privilege"
        "file"
        "path"
        "document"
        "home"
    )
    
    for pattern in "${SENSITIVE_PATTERNS[@]}"; do
        MATCHES=$(echo "$OUTPUT_CONTENT" | grep -i "$pattern" | head -20)
        if [ -n "$MATCHES" ]; then
            echo ""
            echo "--- Matches for '$pattern' ---"
            echo "$MATCHES"
        fi
    done
fi

echo ""
echo "=== Analysis Complete ==="
