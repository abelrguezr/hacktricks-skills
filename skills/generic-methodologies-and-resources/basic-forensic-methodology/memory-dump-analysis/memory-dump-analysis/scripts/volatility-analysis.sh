#!/bin/bash
# Memory Dump Analysis Script
# Automates common Volatility commands for forensic investigation

set -e

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <dump_file> <profile> [options]"
    echo "Options:"
    echo "  --quick     Run quick analysis (pslist, netscan, malfind)"
    echo "  --full      Run comprehensive analysis (all commands)"
    echo "  --extract   Extract artifacts to ./extracted/"
    echo "  --output    Specify output directory (default: ./results/)"
    exit 1
fi

DUMP_FILE="$1"
PROFILE="$2"
OUTPUT_DIR="./results/"
EXTRACT_MODE=false
QUICK_MODE=false

# Parse options
shift 2
while [[ $# -gt 0 ]]; do
    case $1 in
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --full)
            QUICK_MODE=false
            shift
            ;;
        --extract)
            EXTRACT_MODE=true
            shift
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create output directory
mkdir -p "$OUTPUT_DIR"
if [ "$EXTRACT_MODE" = true ]; then
    mkdir -p "$OUTPUT_DIR/extracted"
fi

# Volatility command base
VOL="volatility"
if ! command -v $VOL &> /dev/null; then
    echo "Error: Volatility not found. Please install Volatility 2.x or 3.x"
    exit 1
fi

echo "=== Memory Dump Analysis ==="
echo "File: $DUMP_FILE"
echo "Profile: $PROFILE"
echo "Output: $OUTPUT_DIR"
echo ""

# Function to run volatility command
run_vol() {
    local cmd="$1"
    local output_file="$2"
    echo "Running: $cmd"
    $VOL -f "$DUMP_FILE" --profile="$PROFILE" $cmd > "$OUTPUT_DIR/$output_file" 2>&1
    echo "Results saved to: $OUTPUT_DIR/$output_file"
    echo ""
}

# Quick analysis mode
if [ "$QUICK_MODE" = true ]; then
    echo "=== Quick Analysis ==="
    
    # Process list
    run_vol "pslist" "pslist.txt"
    
    # Network connections
    run_vol "netscan" "netscan.txt"
    
    # Malware detection
    run_vol "malfind" "malfind.txt"
    
    # Command lines
    run_vol "cmdline" "cmdline.txt"
    
else
    echo "=== Full Analysis ==="
    
    # Process enumeration
    run_vol "pslist" "pslist.txt"
    run_vol "psscan" "psscan.txt"
    
    # Network analysis
    run_vol "netscan" "netscan.txt"
    run_vol "connscan" "connscan.txt"
    
    # Malware detection
    run_vol "malfind" "malfind.txt"
    run_vol "apihooks" "apihooks.txt"
    
    # Credentials
    run_vol "hashdump" "hashdump.txt"
    run_vol "lsa_secrets" "lsa_secrets.txt"
    
    # Command lines
    run_vol "cmdline" "cmdline.txt"
    
    # File analysis
    run_vol "filescan" "filescan.txt"
    
    # Modules
    run_vol "modules" "modules.txt"
fi

# Extract artifacts if requested
if [ "$EXTRACT_MODE" = true ]; then
    echo "=== Extracting Artifacts ==="
    
    # Extract DLLs from all processes
    for pid in $($VOL -f "$DUMP_FILE" --profile="$PROFILE" pslist 2>/dev/null | awk 'NR>2 {print $1}'); do
        echo "Extracting DLLs from PID $pid"
        $VOL -f "$DUMP_FILE" --profile="$PROFILE" dlldump -p $pid -D "$OUTPUT_DIR/extracted/" 2>/dev/null || true
    done
    
    echo "Artifacts extracted to: $OUTPUT_DIR/extracted/"
fi

# Generate summary
echo "=== Analysis Complete ==="
echo "Results saved to: $OUTPUT_DIR/"
echo ""
echo "Key files to review:"
echo "  - pslist.txt: Process list"
echo "  - netscan.txt: Network connections"
echo "  - malfind.txt: Malware indicators"
echo "  - hashdump.txt: Extracted hashes"
echo ""
echo "Compare pslist.txt and psscan.txt to find hidden processes."
