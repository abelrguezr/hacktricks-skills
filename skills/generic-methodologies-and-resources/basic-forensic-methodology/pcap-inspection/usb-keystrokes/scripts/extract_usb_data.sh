#!/bin/bash
#
# Extract USB HID data from PCAP files
#
# Usage:
#   ./extract_usb_data.sh capture.pcap [output_prefix]
#
# Outputs:
#   - <prefix>_keystrokes.txt: Colon-separated hex for decoder
#   - <prefix>_raw.txt: Raw hex bytes
#   - <prefix>_csv.csv: CSV with frame numbers and data
#

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <pcap_file> [output_prefix]"
    echo ""
    echo "Extracts USB HID keyboard data from PCAP files."
    echo ""
    echo "Examples:"
    echo "  $0 capture.pcap"
    echo "  $0 usb_traffic.pcapng usb_data"
    exit 1
fi

PCAP_FILE="$1"
PREFIX="${2:-usb_data}"

if [ ! -f "$PCAP_FILE" ]; then
    echo "Error: File not found: $PCAP_FILE" >&2
    exit 1
fi

echo "Extracting USB HID data from: $PCAP_FILE"
echo "Output prefix: $PREFIX"
echo ""

# Check if tshark is available
if ! command -v tshark &> /dev/null; then
    echo "Error: tshark not found. Please install Wireshark." >&2
    exit 1
fi

# Extract colon-separated hex (for usb_decoder.py)
echo "Extracting keystroke data..."
tshark -r "$PCAP_FILE" \
    -Y 'usb.capdata && usb.data_len == 8' \
    -T fields -e usb.capdata 2>/dev/null | \
    sed 's/../:&/g' | \
    sed 's/^://' > "${PREFIX}_keystrokes.txt"

# Extract raw hex bytes
echo "Extracting raw hex data..."
tshark -r "$PCAP_FILE" \
    -Y 'usb.capdata && usb.data_len == 8' \
    -T fields -e usb.capdata 2>/dev/null | \
    sed 's/://g' > "${PREFIX}_raw.txt"

# Extract CSV with frame numbers
echo "Extracting CSV with frame numbers..."
tshark -r "$PCAP_FILE" \
    -Y 'usb.capdata && usb.data_len == 8' \
    -T fields -E header=y -E separator=, \
    -e frame.number -e usb.src -e usb.capdata 2>/dev/null > "${PREFIX}_csv.csv"

# Count results
KESTROKE_COUNT=$(wc -l < "${PREFIX}_keystrokes.txt")
echo ""
echo "Extraction complete!"
echo "  - ${PREFIX}_keystrokes.txt: $KESTROKE_COUNT keystroke reports"
echo "  - ${PREFIX}_raw.txt: Raw hex data"
echo "  - ${PREFIX}_csv.csv: CSV with frame numbers"
echo ""
echo "To decode keystrokes:"
echo "  python3 usb_decoder.py ${PREFIX}_keystrokes.txt"
echo ""
echo "Or pipe directly:"
echo "  tshark -r $PCAP_FILE -Y 'usb.capdata && usb.data_len == 8' -T fields -e usb.capdata | \\\n    sed 's/../:&/g' | python3 usb_decoder.py"
