#!/bin/bash
# Extract shellcode bytes from a Mach-O object file
# Usage: ./extract-shellcode.sh <object-file>

if [ -z "$1" ]; then
    echo "Usage: $0 <object-file>"
    echo "Example: $0 shell.o"
    exit 1
fi

OBJ_FILE="$1"

if [ ! -f "$OBJ_FILE" ]; then
    echo "Error: File '$OBJ_FILE' not found"
    exit 1
fi

echo "Extracting shellcode from $OBJ_FILE..."
echo ""
echo "// Method 1: Using objdump"
echo "char shellcode[] = \""
for c in $(objdump -d "$OBJ_FILE" | grep -E '[0-9a-f]+:' | cut -f 1 | cut -d : -f 2) ; do
    echo -n '\x'$c
done
echo "\";"
echo ""
echo "// Method 2: Using otool"
echo "char shellcode[] = \""
otool -t "$OBJ_FILE" | grep 00 | cut -f2 -d$'\t' | sed 's/ /\\x/g' | sed 's/^/\\x/g' | sed 's/\\x$//g'
echo "\";"
