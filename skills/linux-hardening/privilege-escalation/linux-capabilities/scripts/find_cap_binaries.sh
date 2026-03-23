#!/bin/bash
# Find Binaries with Capabilities
# Usage: ./find_cap_binaries.sh [options]
# Options:
#   --dangerous    Only show binaries with dangerous capabilities
#   --all          Show all binaries with any capability
#   --path <dir>   Search specific path (default: /)
#   --output <file> Save results to file

set -e

DANGEROUS_CAPS=("sys_admin" "sys_ptrace" "sys_module" "dac_override" "dac_read_search" "setuid" "setgid" "setfcap")

show_help() {
    echo "Find Binaries with Capabilities"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --dangerous    Only show binaries with dangerous capabilities"
    echo "  --all          Show all binaries with any capability"
    echo "  --path <dir>   Search specific path (default: /)"
    echo "  --output <file> Save results to file"
    echo "  --help         Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --all"
    echo "  $0 --dangerous --path /usr/bin"
    echo "  $0 --all --output /tmp/capabilities.txt"
}

SEARCH_PATH="/"
OUTPUT_FILE=""
SHOW_ALL=false
SHOW_DANGEROUS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dangerous)
            SHOW_DANGEROUS=true
            shift
            ;;
        --all)
            SHOW_ALL=true
            shift
            ;;
        --path)
            SEARCH_PATH="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ "$SHOW_ALL" = false ] && [ "$SHOW_DANGEROUS" = false ]; then
    echo "Please specify --all or --dangerous"
    show_help
    exit 1
fi

echo "=== Finding Binaries with Capabilities ==="
echo "Search path: $SEARCH_PATH"
echo "Started: $(date)"
echo ""

# Create temporary file for results
TEMP_FILE=$(mktemp)

# Get all binaries with capabilities
echo "Scanning for binaries with capabilities..."
getcap -r "$SEARCH_PATH" 2>/dev/null > "$TEMP_FILE" || echo "No binaries found with capabilities"

if [ "$SHOW_ALL" = true ]; then
    echo ""
    echo "=== All Binaries with Capabilities ==="
    cat "$TEMP_FILE"
    echo ""
    echo "Total: $(wc -l < "$TEMP_FILE") binaries"
fi

if [ "$SHOW_DANGEROUS" = true ]; then
    echo ""
    echo "=== Binaries with Dangerous Capabilities ==="
    
    for cap in "${DANGEROUS_CAPS[@]}"; do
        matches=$(grep -i "$cap" "$TEMP_FILE" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            echo ""
            echo "CAP_${cap^^}:"
            echo "$matches"
        fi
    done
    
    echo ""
    echo "=== Summary ==="
    dangerous_count=$(grep -iE "(${DANGEROUS_CAPS[0]}|${DANGEROUS_CAPS[1]}|${DANGEROUS_CAPS[2]})" "$TEMP_FILE" 2>/dev/null | wc -l || echo "0")
    echo "Binaries with critical capabilities (SYS_ADMIN, SYS_PTRACE, SYS_MODULE): $dangerous_count"
fi

# Save to output file if specified
if [ -n "$OUTPUT_FILE" ]; then
    cp "$TEMP_FILE" "$OUTPUT_FILE"
    echo ""
    echo "Results saved to: $OUTPUT_FILE"
fi

# Cleanup
rm -f "$TEMP_FILE"

echo ""
echo "Completed: $(date)"
