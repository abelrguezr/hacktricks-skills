#!/bin/bash
# Compile a function interpose dylib
# Usage: ./compile_interpose.sh <source.c> [output.dylib]

set -e

SOURCE="${1:-interpose.c}"
OUTPUT="${2:-interpose.dylib}"

if [ ! -f "$SOURCE" ]; then
    echo "Error: Source file '$SOURCE' not found"
    exit 1
fi

echo "Compiling interpose dylib: $SOURCE -> $OUTPUT"
gcc -dynamiclib "$SOURCE" -o "$OUTPUT"

echo "Success: $OUTPUT created"
echo "Test with: DYLD_INSERT_LIBRARIES=./$OUTPUT ./your_program"
