#!/bin/bash
# Audit container config.json for PID namespace security issues

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <config.json>"
    echo "  config.json: Path to the container's OCI config.json file"
    echo ""
    echo "Example: $0 /path/to/container/config.json"
    exit 1
fi

CONFIG_FILE=$1

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: File $CONFIG_FILE not found"
    exit 1
fi

echo "=== Container PID Namespace Security Audit ==="
echo "Config file: $CONFIG_FILE"
echo ""

# Check for maskedPaths
if command -v jq &> /dev/null; then
    echo "=== Masked Paths ==="
    MASKED_PATHS=$(jq -r '.linux.maskedPaths // empty' "$CONFIG_FILE" 2>/dev/null || echo "")
    
    if [ -z "$MASKED_PATHS" ]; then
        echo "WARNING: No maskedPaths found in config"
        echo "This may indicate the container has access to sensitive host procfs entries"
    else
        echo "$MASKED_PATHS" | jq -r '.[]' 2>/dev/null || echo "$MASKED_PATHS" | tr -d '"'
    fi
    
    echo ""
    echo "=== Checking for Critical Masked Paths ==="
    
    # Check for core_pattern masking
    if echo "$MASKED_PATHS" | grep -q "core_pattern"; then
        echo "✓ core_pattern is masked"
    else
        echo "⚠ core_pattern may not be masked (CVE-2025-31133 risk)"
    fi
    
    # Check for sysrq-trigger masking
    if echo "$MASKED_PATHS" | grep -q "sysrq-trigger"; then
        echo "✓ sysrq-trigger is masked"
    else
        echo "⚠ sysrq-trigger may not be masked"
    fi
    
    # Check for kmsg masking
    if echo "$MASKED_PATHS" | grep -q "kmsg"; then
        echo "✓ kmsg is masked"
    else
        echo "⚠ kmsg may not be masked"
    fi
else
    echo "Note: Install jq for detailed JSON parsing"
    echo "Raw maskedPaths:"
    grep -A 20 '"maskedPaths"' "$CONFIG_FILE" || echo "No maskedPaths found"
fi

echo ""
echo "=== Recommendations ==="
echo "1. Ensure runc is updated to version 1.2.8 or later"
echo "2. Verify all sensitive procfs paths are in maskedPaths"
echo "3. Use insject with -S flag for strict namespace validation"
echo "4. Never attach tools with writable host file descriptors without joining mount namespace"
