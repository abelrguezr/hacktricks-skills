#!/bin/bash
# Comprehensive Linux Capability Security Audit
# Usage: ./capability_audit.sh [options]
# Options:
#   --output <file>  Save report to file
#   --quick          Quick audit (no process analysis)
#   --verbose        Verbose output
#   --help           Show this help

set -e

OUTPUT_FILE=""
QUICK_MODE=false
VERBOSE=false

show_help() {
    echo "Linux Capability Security Audit"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --output <file>  Save report to file"
    echo "  --quick          Quick audit (no process analysis)"
    echo "  --verbose        Verbose output"
    echo "  --help           Show this help"
    echo ""
    echo "This script performs a comprehensive security audit of Linux capabilities"
    echo "on the system, identifying potential privilege escalation vectors."
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
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

# Create report
REPORT=$(mktemp)

log() {
    echo "$1" | tee -a "$REPORT"
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log "$1"
    fi
}

log "========================================"
log "Linux Capability Security Audit Report"
log "========================================"
log "Date: $(date)"
log "Hostname: $(hostname)"
log "Kernel: $(uname -r)"
log ""

# Section 1: System Information
log "=== 1. System Information ==="
log ""
log "User: $(whoami)"
log "UID: $(id -u)"
log "Groups: $(id -Gn)"
log ""

# Section 2: Critical Directories Scan
log "=== 2. Binaries with Capabilities ==="
log ""

CRITICAL_DIRS=("/usr/bin" "/usr/sbin" "/bin" "/sbin" "/usr/local/bin" "/usr/local/sbin")

for dir in "${CRITICAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log "Scanning $dir..."
        results=$(getcap -r "$dir" 2>/dev/null || true)
        if [ -n "$results" ]; then
            log "$results"
            log ""
        else
            log_verbose "  No capabilities found in $dir"
        fi
    fi
done

# Section 3: Dangerous Capabilities Analysis
log "=== 3. Dangerous Capabilities Analysis ==="
log ""

DANGEROUS_CAPS=(
    "sys_admin:CRITICAL:Allows mount operations and kernel manipulation"
    "sys_ptrace:CRITICAL:Allows process debugging and memory injection"
    "sys_module:CRITICAL:Allows kernel module loading"
    "dac_override:HIGH:Allows bypassing file write permissions"
    "dac_read_search:HIGH:Allows bypassing file read permissions"
    "setuid:HIGH:Allows setting effective UID"
    "setgid:HIGH:Allows setting effective GID"
    "setfcap:HIGH:Allows setting capabilities on files"
)

for entry in "${DANGEROUS_CAPS[@]}"; do
    IFS=':' read -r cap level desc <<< "$entry"
    
    matches=$(getcap -r / 2>/dev/null | grep -i "$cap" || true)
    
    if [ -n "$matches" ]; then
        log "⚠️  $level RISK: CAP_${cap^^}"
        log "   Description: $desc"
        log "   Affected binaries:"
        echo "$matches" | while read line; do
            log "   - $line"
        done
        log ""
    else
        log_verbose "✓ CAP_${cap^^}: Not found"
    fi
done

# Section 4: Running Processes Analysis (skip in quick mode)
if [ "$QUICK_MODE" = false ]; then
    log "=== 4. Running Processes with Capabilities ==="
    log ""
    
    process_count=0
    for pid in /proc/[0-9]*/status; do
        if [ -f "$pid" ]; then
            cap_eff=$(grep "CapEff:" "$pid" 2>/dev/null | awk '{print $2}' || true)
            if [ "$cap_eff" != "0000000000000000" ] && [ -n "$cap_eff" ]; then
                pid_num=$(basename $(dirname "$pid"))
                proc_name=$(ps -p "$pid_num" -o comm= 2>/dev/null || echo "unknown")
                
                log "Process: $proc_name (PID: $pid_num)"
                log "  CapEff: $cap_eff"
                
                # Decode if possible
                if command -v capsh &> /dev/null; then
                    decoded=$(capsh --decode=$cap_eff 2>/dev/null | cut -d'=' -f2 || echo "unable to decode")
                    log "  Decoded: $decoded"
                fi
                log ""
                
                ((process_count++))
            fi
        fi
    done
    
    if [ $process_count -eq 0 ]; then
        log "No running processes with effective capabilities found."
    else
        log "Total processes with capabilities: $process_count"
    fi
    log ""
fi

# Section 5: Docker Container Check
log "=== 5. Docker Container Check ==="
log ""

if command -v docker &> /dev/null; then
    log "Docker is installed."
    
    # Check if running in container
    if [ -f /.dockerenv ]; then
        log "⚠️  Running inside Docker container"
        
        if command -v capsh &> /dev/null; then
            log ""
            log "Current container capabilities:"
            capsh --print 2>/dev/null | grep -A 2 "Current:" || echo "Unable to retrieve"
        fi
    else
        log "Not running in Docker container"
        
        # Check for running containers
        containers=$(docker ps 2>/dev/null | wc -l || echo "0")
        log "Running containers: $((containers - 1))"
    fi
else
    log "Docker not installed"
fi
log ""

# Section 6: Security Recommendations
log "=== 6. Security Recommendations ==="
log ""

log "Based on the audit, consider the following:"
log ""
log "1. PRINCIPLE OF LEAST PRIVILEGE"
log "   - Remove unnecessary capabilities from binaries"
log "   - Use setcap -r to remove capabilities when not needed"
log ""
log "2. CONTAINER HARDENING"
log "   - Drop dangerous capabilities in containers"
log "   - Use --cap-drop=ALL and add only required capabilities"
log ""
log "3. REGULAR AUDITS"
log "   - Run this audit regularly"
log "   - Monitor for new binaries with capabilities"
log ""
log "4. FILE INTEGRITY"
log "   - Monitor changes to capability settings"
log "   - Use file integrity monitoring tools"
log ""
log "5. DOCUMENTATION"
log "   - Document why each capability is needed"
log "   - Review and update documentation regularly"
log ""

# Section 7: Summary
log "=== 7. Audit Summary ==="
log ""

# Count dangerous capabilities
dangerous_count=$(getcap -r / 2>/dev/null | grep -iE "(sys_admin|sys_ptrace|sys_module)" | wc -l || echo "0")
total_count=$(getcap -r / 2>/dev/null | wc -l || echo "0")

log "Total binaries with capabilities: $total_count"
log "Binaries with critical capabilities: $dangerous_count"
log ""

if [ "$dangerous_count" -gt 0 ]; then
    log "⚠️  SECURITY ALERT: Found binaries with critical capabilities!"
    log "   Review and remediate immediately."
else
    log "✓ No critical capabilities detected in binaries."
fi
log ""
log "Audit completed: $(date)"
log "========================================"

# Output report
if [ -n "$OUTPUT_FILE" ]; then
    cp "$REPORT" "$OUTPUT_FILE"
    echo "Report saved to: $OUTPUT_FILE"
else
    cat "$REPORT"
fi

# Cleanup
rm -f "$REPORT"
