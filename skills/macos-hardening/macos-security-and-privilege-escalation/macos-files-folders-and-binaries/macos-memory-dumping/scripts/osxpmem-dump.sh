#!/bin/bash
# macOS Memory Dump Script
# Downloads osxpmem, loads the kext, and dumps memory
# Requires: sudo access, Intel Mac, internet connection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}macOS Memory Dump Tool${NC}"
echo "================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script requires root privileges${NC}"
    echo "Please run with sudo: sudo $0"
    exit 1
fi

# Check architecture
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo -e "${YELLOW}Warning: Detected architecture: $ARCH${NC}"
    echo "osxpmem is designed for Intel (x86_64) Macs."
    echo "This may not work on Apple Silicon (arm64)."
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Set working directory
WORK_DIR="/tmp"
OSXPMEM_URL="https://github.com/google/rekall/releases/download/v1.5.1/osxpmem-2.1.post4.zip"
OSXPMEM_ZIP="$WORK_DIR/osxpmem-2.1.post4.zip"
OSXPMEM_APP="$WORK_DIR/osxpmem.app"
OUTPUT_FILE="$WORK_DIR/dump_mem"

echo -e "${GREEN}[1/5]${NC} Downloading osxpmem..."
if [ ! -f "$OSXPMEM_ZIP" ]; then
    cd "$WORK_DIR"
    wget "$OSXPMEM_URL" -O "$OSXPMEM_ZIP" || curl -L "$OSXPMEM_URL" -o "$OSXPMEM_ZIP"
else
    echo "osxpmem already downloaded, skipping download."
fi

echo -e "${GREEN}[2/5]${NC} Extracting osxpmem..."
if [ ! -d "$OSXPMEM_APP" ]; then
    unzip -o "$OSXPMEM_ZIP" -d "$WORK_DIR"
else
    echo "osxpmem already extracted, skipping extraction."
fi

echo -e "${GREEN}[3/5]${NC} Setting kext permissions..."
KEXT_PATH="$OSXPMEM_APP/MacPmem.kext"
if [ -d "$KEXT_PATH" ]; then
    chown -R root:wheel "$KEXT_PATH"
    chmod 755 "$KEXT_PATH"
else
    echo -e "${RED}Error: Kext not found at $KEXT_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}[4/5]${NC} Loading kernel extension..."
# Copy kext to /tmp for loading
KEXT_TMP="$WORK_DIR/MacPmem.kext"
if [ ! -d "$KEXT_TMP" ]; then
    cp -r "$KEXT_PATH" "$KEXT_TMP"
fi

# Try to load the kext
if ! kextload "$KEXT_TMP" 2>/dev/null; then
    echo -e "${YELLOW}Warning: kextload failed, trying kextutil...${NC}"
    if ! kextutil "$KEXT_TMP" 2>/dev/null; then
        echo -e "${RED}Error: Failed to load kernel extension${NC}"
        echo ""
        echo "Please manually allow the kext:"
        echo "1. Go to System Settings → Privacy & Security → General"
        echo "2. Look for a message about a blocked kernel extension"
        echo "3. Click 'Allow' to permit it"
        echo "4. Run this script again"
        exit 1
    fi
fi

echo -e "${GREEN}[5/5]${NC} Dumping memory..."
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

# Dump memory in raw format
if "$OSXPMEM_APP/osxpmem" --format raw -o "$OUTPUT_FILE"; then
    echo ""
    echo -e "${GREEN}✓ Memory dump completed successfully!${NC}"
    echo ""
    echo "Output file: $OUTPUT_FILE"
    echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
    echo ""
    echo "Next steps:"
    echo "- Analyze with Volatility: volatility -f $OUTPUT_FILE imageinfo"
    echo "- Search for artifacts: volatility -f $OUTPUT_FILE --profile=MacOS64_10_15 pslist"
else
    echo -e "${RED}Error: Memory dump failed${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Check if kext is allowed in System Settings → Privacy & Security"
    echo "2. Check system logs: log show --predicate 'process == \"osxpmem\"'"
    echo "3. Ensure you're on an Intel Mac (not Apple Silicon)"
    exit 1
fi
