#!/bin/bash
# Emulation Helper Script
# Assists with firmware binary emulation using QEMU

set -e

usage() {
    echo "Usage: $0 <binary> [options]"
    echo ""
    echo "Emulates firmware binaries using QEMU"
    echo ""
    echo "Options:"
    echo "  -a <arch>      Architecture: auto, mips, mipsel, arm, armhf, x86"
    echo "  -c <cmd>       Command to run after emulation starts"
    echo "  -i             Interactive mode (drops to shell)"
    echo "  -h             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/busybox -a mipsel"
    echo "  $0 /path/to/binary -a auto -i"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

BINARY="$1"
ARCH="auto"
COMMAND=""
INTERACTIVE=false

while getopts "a:cih" opt; do
    case $opt in
        a) ARCH="$OPTARG" ;;
        c) COMMAND="$OPTARG" ;;
        i) INTERACTIVE=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [ ! -f "$BINARY" ]; then
    echo "Error: File not found: $BINARY"
    exit 1
fi

echo "=== Emulation Helper ==="
echo "Binary: $BINARY"
echo ""

# Detect architecture
echo "[1/3] Detecting architecture..."
FILE_INFO=$(file -b "$BINARY")
echo "File info: $FILE_INFO"

if [ "$ARCH" = "auto" ]; then
    if echo "$FILE_INFO" | grep -qi "mips.*big-endian"; then
        ARCH="mips"
        QEMU_CMD="qemu-mips"
    elif echo "$FILE_INFO" | grep -qi "mips.*little-endian"; then
        ARCH="mipsel"
        QEMU_CMD="qemu-mipsel"
    elif echo "$FILE_INFO" | grep -qi "arm.*little-endian"; then
        ARCH="arm"
        QEMU_CMD="qemu-arm"
    elif echo "$FILE_INFO" | grep -qi "arm.*big-endian"; then
        ARCH="armbe"
        QEMU_CMD="qemu-arm"
    elif echo "$FILE_INFO" | grep -qi "x86-64"; then
        ARCH="x86_64"
        QEMU_CMD="qemu-x86_64"
    elif echo "$FILE_INFO" | grep -qi "Intel 80386"; then
        ARCH="i386"
        QEMU_CMD="qemu-i386"
    else
        echo "Error: Could not auto-detect architecture"
        echo "Please specify architecture with -a option"
        exit 1
    fi
else
    case $ARCH in
        mips) QEMU_CMD="qemu-mips" ;;
        mipsel) QEMU_CMD="qemu-mipsel" ;;
        arm) QEMU_CMD="qemu-arm" ;;
        armhf) QEMU_CMD="qemu-arm" ;;
        x86) QEMU_CMD="qemu-i386" ;;
        x86_64) QEMU_CMD="qemu-x86_64" ;;
        *) echo "Error: Unknown architecture: $ARCH"; exit 1 ;;
    esac
fi

echo "Detected/Selected architecture: $ARCH"
echo "QEMU command: $QEMU_CMD"
echo ""

# Check QEMU availability
echo "[2/3] Checking QEMU availability..."
if ! command -v $QEMU_CMD &> /dev/null; then
    echo "Error: $QEMU_CMD not found"
    echo ""
    echo "Install QEMU with:"
    echo "  sudo apt-get install qemu-user qemu-user-static"
    echo "  sudo apt-get install qemu-system-mips qemu-system-arm"
    exit 1
fi
echo "$QEMU_CMD is available"
echo ""

# Run emulation
echo "[3/3] Starting emulation..."

if [ -n "$COMMAND" ]; then
    echo "Running: $QEMU_CMD $BINARY $COMMAND"
    $QEMU_CMD "$BINARY" $COMMAND
elif [ "$INTERACTIVE" = true ]; then
    echo "Starting interactive session..."
    echo "Type 'exit' or press Ctrl+D to quit"
    echo ""
    $QEMU_CMD "$BINARY"
else
    echo "Running binary..."
    $QEMU_CMD "$BINARY"
fi

echo ""
echo "=== Emulation Complete ==="
