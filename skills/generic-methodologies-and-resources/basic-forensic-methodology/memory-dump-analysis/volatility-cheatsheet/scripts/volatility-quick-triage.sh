#!/bin/bash
# Volatility Quick Triage Script
# Runs essential plugins for initial memory dump analysis

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <memory_dump_file> <output_directory> [volatility_version]"
    echo "  volatility_version: '2' or '3' (default: 3)"
    exit 1
fi

DUMP_FILE="$1"
OUTPUT_DIR="$2"
VOL_VERSION="${3:-3}"
PROFILE="${4:-}"

if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: File not found: $DUMP_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$OUTPUT_DIR/triage_$TIMESTAMP.log"

echo "=== Volatility Quick Triage ==="
echo "Memory dump: $DUMP_FILE"
echo "Output directory: $OUTPUT_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if [ "$VOL_VERSION" = "3" ]; then
    log "Running Volatility3 triage..."
    
    # Process list
    log "1. Process list (pslist)..."
    vol.py -f "$DUMP_FILE" windows.pslist.PsList > "$OUTPUT_DIR/pslist.txt" 2>&1 || true
    
    # Process scan (hidden processes)
    log "2. Process scan (psscan)..."
    vol.py -f "$DUMP_FILE" windows.psscan.PsScan > "$OUTPUT_DIR/psscan.txt" 2>&1 || true
    
    # Process tree
    log "3. Process tree..."
    vol.py -f "$DUMP_FILE" windows.pstree.PsTree > "$OUTPUT_DIR/pstree.txt" 2>&1 || true
    
    # Network connections
    log "4. Network scan..."
    vol.py -f "$DUMP_FILE" windows.netscan.NetScan > "$OUTPUT_DIR/netscan.txt" 2>&1 || true
    
    # Malware detection
    log "5. Malware detection (malfind)..."
    vol.py -f "$DUMP_FILE" windows.malfind.Malfind > "$OUTPUT_DIR/malfind.txt" 2>&1 || true
    
    # Command lines
    log "6. Command lines..."
    vol.py -f "$DUMP_FILE" windows.cmdline.CmdLine > "$OUTPUT_DIR/cmdline.txt" 2>&1 || true
    
    # Hashes
    log "7. Hash dump..."
    vol.py -f "$DUMP_FILE" windows.hashdump.Hashdump > "$OUTPUT_DIR/hashdump.txt" 2>&1 || true
    
    # Services
    log "8. Service scan..."
    vol.py -f "$DUMP_FILE" windows.svcscan.SvcScan > "$OUTPUT_DIR/svcscan.txt" 2>&1 || true
    
else
    log "Running Volatility2 triage..."
    
    if [ -z "$PROFILE" ]; then
        log "ERROR: Profile required for Volatility2. Run profile detection first."
        exit 1
    fi
    
    # Process list
    log "1. Process list (pslist)..."
    volatility --profile="$PROFILE" pslist -f "$DUMP_FILE" > "$OUTPUT_DIR/pslist.txt" 2>&1 || true
    
    # Process scan (hidden processes)
    log "2. Process scan (psscan)..."
    volatility --profile="$PROFILE" psscan -f "$DUMP_FILE" > "$OUTPUT_DIR/psscan.txt" 2>&1 || true
    
    # Process tree
    log "3. Process tree..."
    volatility --profile="$PROFILE" pstree -f "$DUMP_FILE" > "$OUTPUT_DIR/pstree.txt" 2>&1 || true
    
    # Network connections
    log "4. Network scan..."
    volatility --profile="$PROFILE" netscan -f "$DUMP_FILE" > "$OUTPUT_DIR/netscan.txt" 2>&1 || true
    
    # Malware detection
    log "5. Malware detection (malfind)..."
    volatility --profile="$PROFILE" malfind -f "$DUMP_FILE" > "$OUTPUT_DIR/malfind.txt" 2>&1 || true
    
    # Command lines
    log "6. Command lines..."
    volatility --profile="$PROFILE" cmdline -f "$DUMP_FILE" > "$OUTPUT_DIR/cmdline.txt" 2>&1 || true
    
    # Hashes
    log "7. Hash dump..."
    volatility --profile="$PROFILE" hashdump -f "$DUMP_FILE" > "$OUTPUT_DIR/hashdump.txt" 2>&1 || true
    
    # Services
    log "8. Service scan..."
    volatility --profile="$PROFILE" svcscan -f "$DUMP_FILE" > "$OUTPUT_DIR/svcscan.txt" 2>&1 || true
fi

log ""
log "=== Triage Complete ==="
log "Output files saved to: $OUTPUT_DIR"
log ""
log "Key files to review:"
log "  - pslist.txt vs psscan.txt (compare for hidden processes)"
log "  - malfind.txt (suspicious injected code)"
log "  - netscan.txt (network connections)"
log "  - cmdline.txt (executed commands)"
log "  - hashdump.txt (extracted credentials)"
