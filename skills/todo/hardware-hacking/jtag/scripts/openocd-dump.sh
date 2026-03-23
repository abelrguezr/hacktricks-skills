#!/bin/bash
# OpenOCD memory dump helper
# Usage: ./openocd-dump.sh [adapter] [target] [output_file] [address] [size]
# Examples:
#   ./openocd-dump.sh jlink stm32f1x flash.bin 0x08000000 0x100000
#   ./openocd-dump.sh ft232h riscv sram.bin 0x80000000 0x20000

set -e

ADAPTER=${1:-jlink}
TARGET=${2:-}
OUTPUT=${3:-dump.bin}
ADDRESS=${4:-0x08000000}
SIZE=${5:-0x100000}
SPEED=${6:-1000}

echo "=== Memory Dump ==="
echo "Adapter: $ADAPTER"
echo "Target: $TARGET"
echo "Output: $OUTPUT"
echo "Address: $ADDRESS"
echo "Size: $SIZE"
echo "Speed: ${SPEED}kHz"

# Build interface config
INTERFACE_CONFIG=""
case "$ADAPTER" in
  jlink)
    INTERFACE_CONFIG="interface/jlink.cfg"
    ;;
  ft232h|ft2232h)
    INTERFACE_CONFIG="interface/ftdi/ft232h.cfg"
    ;;
  stlink)
    INTERFACE_CONFIG="interface/stlink.cfg"
    ;;
  cmsis-dap)
    INTERFACE_CONFIG="interface/cmsis-dap.cfg"
    ;;
  *)
    echo "Unknown adapter: $ADAPTER"
    echo "Supported: jlink, ft232h, ft2232h, stlink, cmsis-dap"
    exit 1
    ;;
esac

# Build target config
TARGET_CONFIG=""
if [ -n "$TARGET" ]; then
  TARGET_CONFIG="-f target/${TARGET}.cfg"
fi

# Run dump
echo ""
echo "Dumping memory..."
echo "========================"

openocd -f "$INTERFACE_CONFIG" $TARGET_CONFIG \
  -c "transport select jtag; adapter speed $SPEED" \
  -c "init; reset halt; dump_image $OUTPUT $ADDRESS $SIZE; shutdown" 2>&1

echo ""
echo "========================"
echo "Dump complete: $OUTPUT"
if [ -f "$OUTPUT" ]; then
  ls -lh "$OUTPUT"
fi
