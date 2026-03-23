#!/bin/bash
# Compile Objective-C method swizzle code
# Usage: ./compile_swizzle.sh <source.m> [output]

set -e

SOURCE="${1:-swizzle.m}"
OUTPUT="${2:-swizzle}"

if [ ! -f "$SOURCE" ]; then
    echo "Error: Source file '$SOURCE' not found"
    exit 1
fi

echo "Compiling swizzle code: $SOURCE -> $OUTPUT"
gcc -framework Foundation "$SOURCE" -o "$OUTPUT"

echo "Success: $OUTPUT created"
echo "Run with: ./$OUTPUT"
