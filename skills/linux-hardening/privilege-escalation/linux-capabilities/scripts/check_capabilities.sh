#!/bin/bash
# Linux Capabilities Checker
# Usage: ./check_capabilities.sh [options]
# Options:
#   --process <PID>    Check specific process
#   --binary <path>    Check specific binary
#   --scan <dir>       Scan directory for binaries with capabilities
#   --decode <hex>     Decode capability hex value
#   --audit            Full system audit
#   --help             Show this help

set -e

show_help() {
    echo "Linux Capabilities Checker"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --process <PID>    Check specific process capabilities"
    echo "  --binary <path>    Check specific binary capabilities"
    echo "  --scan <dir>       Scan directory for binaries with capabilities"
    echo "  --decode <hex>     Decode capability hex value"
    echo "  --audit            Full system audit"
    echo "  --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --process 1234"
    echo "  $0 --binary /usr/bin/ping"
    echo "  $0 --scan /usr/bin"
    echo "  $0 --decode 0000003fffffffff"
    echo "  $0 --audit"
}

check_process() {
    local pid=$1
    echo "=== Process Capabilities for PID $pid ==="
    
    if [ ! -d "/proc/$pid" ]; then
        echo "Error: Process $pid not found"
        exit 1
    fi
    
    echo ""
    echo "Raw capability sets:"
    cat /proc/$pid/status | grep Cap
    
    echo ""
    echo "Decoded capabilities:"
    while IFS=': ' read -r name value; do
        if [[ $name =~ ^Cap ]]; then
            decoded=$(capsh --decode=$value 2>/dev/null || echo "Unable to decode")
            echo "$name: $decoded"
        fi
    done < <(cat /proc/$pid/status | grep Cap)
    
    echo ""
    echo "Process info:"
    ps -p $pid -o pid,comm,user,args 2>/dev/null || echo "Unable to get process info"
}

check_binary() {
    local binary=$1
    echo "=== Binary Capabilities for $binary ==="
    
    if [ ! -f "$binary" ]; then
        echo "Error: Binary not found: $binary"
        exit 1
    fi
    
    echo ""
    echo "Capabilities:"
    getcap "$binary" 2>/dev/null || echo "No capabilities set"
    
    echo ""
    echo "File info:"
    ls -la "$binary"
    
    echo ""
    echo "Owner/Group:"
    stat -c "Owner: %U, Group: %G" "$binary" 2>/dev/null || stat -f "Owner: %Su, Group: %Sg" "$binary" 2>/dev/null
}

scan_directory() {
    local dir=$1
    echo "=== Scanning $dir for binaries with capabilities ==="
    echo ""
    
    if [ ! -d "$dir" ]; then
        echo "Error: Directory not found: $dir"
        exit 1
    fi
    
    echo "Binaries with capabilities:"
    getcap -r "$dir" 2>/dev/null || echo "No binaries with capabilities found"
    
    echo ""
    echo "Summary:"
    count=$(getcap -r "$dir" 2>/dev/null | wc -l)
    echo "Total binaries with capabilities: $count"
}

decode_capability() {
    local hex=$1
    echo "=== Decoding Capability Hex: $hex ==="
    echo ""
    capsh --decode=$hex 2>/dev/null || echo "Unable to decode"
}

full_audit() {
    echo "=== Full System Capability Audit ==="
    echo "Started: $(date)"
    echo ""
    
    # Create temporary directory for results
    TEMP_DIR=$(mktemp -d)
    
    echo "1. Scanning critical directories..."
    for dir in /usr/bin /usr/sbin /bin /sbin; do
        echo "   Scanning $dir..."
        getcap -r "$dir" 2>/dev/null >> "$TEMP_DIR/capabilities.txt" || true
    done
    
    echo ""
    echo "2. Checking running processes..."
    echo "   Processes with non-zero effective capabilities:"
    for pid in /proc/[0-9]*/status; do
        if ! grep -q "CapEff: 0000000000000000" "$pid" 2>/dev/null; then
            pid_num=$(basename $(dirname "$pid"))
            echo "   PID $pid_num:"
            cat "$pid" | grep Cap
            echo ""
        fi
    done
    
    echo ""
    echo "3. Analyzing dangerous capabilities..."
    echo "   Checking for high-risk capabilities:"
    
    for cap in "sys_admin" "sys_ptrace" "sys_module" "dac_override" "dac_read_search" "setuid" "setgid"; do
        matches=$(grep -i "$cap" "$TEMP_DIR/capabilities.txt" 2>/dev/null || true)
        if [ -n "$matches" ]; then
            echo "   WARNING: Found binaries with CAP_$cap:"
            echo "$matches" | head -5
            echo ""
        fi
    done
    
    echo ""
    echo "4. Summary Statistics"
    total=$(wc -l < "$TEMP_DIR/capabilities.txt" 2>/dev/null || echo "0")
    echo "   Total binaries with capabilities: $total"
    
    echo ""
    echo "5. Results saved to:"
    echo "   $TEMP_DIR/capabilities.txt"
    
    echo ""
    echo "Audit completed: $(date)"
    
    # Keep temp files for review
    echo ""
    echo "To view full results: cat $TEMP_DIR/capabilities.txt"
}

# Main script logic
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --process)
            check_process "$2"
            shift 2
            ;;
        --binary)
            check_binary "$2"
            shift 2
            ;;
        --scan)
            scan_directory "$2"
            shift 2
            ;;
        --decode)
            decode_capability "$2"
            shift 2
            ;;
        --audit)
            full_audit
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done
