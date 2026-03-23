#!/bin/bash
# OpenOCD scan helper - quickly scan JTAG chain with common adapters
# Usage: ./openocd-scan.sh [adapter] [target]
# Examples:
#   ./openocd-scan.sh jlink stm32f1x
#   ./openocd-scan.sh ft232h riscv
#   ./openocd-scan.sh esp32s3

set -e

ADAPTER=${1:-jlink}
TARGET=${2:-}
SPEED=${3:-1000}

echo "=== JTAG Chain Scan ==="
echo "Adapter: $ADAPTER"
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
  esp32s3)
    echo "Using ESP32-S3 built-in USB-JTAG"
    openocd -f board/esp32s3-builtin.cfg -c "init; scan_chain; shutdown"
    exit 0
    ;;
  cmsis-dap)
    INTERFACE_CONFIG="interface/cmsis-dap.cfg"
    ;;
  *)
    echo "Unknown adapter: $ADAPTER"
    echo "Supported: jlink, ft232h, ft2232h, stlink, esp32s3, cmsis-dap"
    exit 1
    ;;
esac

# Build target config if provided
TARGET_CONFIG=""
if [ -n "$TARGET" ]; then
  TARGET_CONFIG="-f target/${TARGET}.cfg"
fi

# Run scan
echo ""
echo "Scanning JTAG chain..."
echo "========================"

openocd -f "$INTERFACE_CONFIG" $TARGET_CONFIG \
  -c "transport select jtag; adapter speed $SPEED" \
  -c "init; scan_chain; shutdown" 2>&1

echo ""
echo "========================"
echo "Scan complete"
