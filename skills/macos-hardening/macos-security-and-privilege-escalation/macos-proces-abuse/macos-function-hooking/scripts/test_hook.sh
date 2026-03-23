#!/bin/bash
# Test function hook injection
# Usage: ./test_hook.sh <dylib> <target_program> [args...]

set -e

DYLIB="${1:-interpose.dylib}"
TARGET="${2:-./hello}"
shift 2 || true
ARGS=("$@")

if [ ! -f "$DYLIB" ]; then
    echo "Error: Dylib '$DYLIB' not found"
    exit 1
fi

if [ ! -f "$TARGET" ]; then
    echo "Error: Target program '$TARGET' not found"
    exit 1
fi

echo "Testing hook injection..."
echo "Dylib: $DYLIB"
echo "Target: $TARGET"
echo "---"

DYLD_INSERT_LIBRARIES="$DYLIB" "$TARGET" "${ARGS[@]}"

echo "---"
echo "Hook test complete"
