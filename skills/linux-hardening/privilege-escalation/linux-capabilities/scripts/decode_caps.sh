#!/bin/bash
# Capability Hex Decoder
# Usage: ./decode_caps.sh <hex_value>
# Example: ./decode_caps.sh 0000003fffffffff

if [ $# -eq 0 ]; then
    echo "Usage: $0 <hex_value>"
    echo "Example: $0 0000003fffffffff"
    echo ""
    echo "Common hex values:"
    echo "  0000003fffffffff - All capabilities (root)"
    echo "  0000000000003000 - CAP_NET_ADMIN, CAP_NET_RAW"
    echo "  0000000000000000 - No capabilities"
    exit 1
fi

HEX_VALUE=$1

echo "=== Capability Decoder ==="
echo ""
echo "Input: $HEX_VALUE"
echo ""

# Try capsh first
if command -v capsh &> /dev/null; then
    echo "Decoded capabilities:"
    capsh --decode=$HEX_VALUE 2>/dev/null
else
    echo "Error: capsh not found. Install libcap2-bin package."
    echo "  apt install libcap2-bin  # Debian/Ubuntu"
    echo "  yum install libcap       # RHEL/CentOS"
    exit 1
fi

echo ""
echo "Capability breakdown:"

# Parse the output and show individual capabilities
if command -v capsh &> /dev/null; then
    decoded=$(capsh --decode=$HEX_VALUE 2>/dev/null | grep -oP 'cap_\w+' | sort -u)
    if [ -n "$decoded" ]; then
        echo "$decoded" | while read cap; do
            echo "  - $cap"
        done
    else
        echo "  No capabilities set"
    fi
fi

echo ""
echo "Risk assessment:"

# Check for dangerous capabilities
dangerous_caps=("cap_sys_admin" "cap_sys_ptrace" "cap_sys_module" "cap_dac_override" "cap_dac_read_search" "cap_setuid" "cap_setgid")

for cap in "${dangerous_caps[@]}"; do
    if echo "$decoded" | grep -q "$cap" 2>/dev/null; then
        echo "  ⚠️  WARNING: $cap detected (HIGH RISK)"
    fi
done

if [ -z "$decoded" ] || [ "$HEX_VALUE" = "0000000000000000" ]; then
    echo "  ✓ No dangerous capabilities detected"
fi
