#!/bin/bash
# Build macOS x64 shellcode from assembly
# Usage: ./build-shellcode.sh <assembly-file>

if [ -z "$1" ]; then
    echo "Usage: $0 <assembly-file>"
    echo "Example: $0 shell.asm"
    exit 1
fi

ASM_FILE="$1"
BASE_NAME=$(basename "$ASM_FILE" .asm)
OBJ_FILE="${BASE_NAME}.o"
EXE_FILE="${BASE_NAME}"

if [ ! -f "$ASM_FILE" ]; then
    echo "Error: File '$ASM_FILE' not found"
    exit 1
fi

echo "Building $ASM_FILE..."
echo ""

# Assemble to object file
echo "[1/3] Assembling to $OBJ_FILE..."
nasm -f macho64 "$ASM_FILE" -o "$OBJ_FILE"
if [ $? -ne 0 ]; then
    echo "Error: Assembly failed"
    exit 1
fi
echo "[+] Assembly successful"

# Link to executable
echo "[2/3] Linking to $EXE_FILE..."
ld -o "$EXE_FILE" "$OBJ_FILE" -macosx_version_min 13.0 -lSystem -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib
if [ $? -ne 0 ]; then
    echo "Error: Linking failed"
    exit 1
fi
echo "[+] Linking successful"

# Extract shellcode
echo "[3/3] Extracting shellcode bytes..."
echo ""
echo "// Shellcode for $BASE_NAME"
echo "char shellcode[] = \""
for c in $(objdump -d "$OBJ_FILE" | grep -E '[0-9a-f]+:' | cut -f 1 | cut -d : -f 2) ; do
    echo -n '\x'$c
done
echo "\";"
echo ""
echo "[+] Build complete!"
echo "    Executable: $EXE_FILE"
echo "    Object file: $OBJ_FILE"
echo "    Shellcode: see above"
