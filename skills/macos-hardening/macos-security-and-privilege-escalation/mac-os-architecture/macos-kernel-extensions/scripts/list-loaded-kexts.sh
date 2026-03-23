#!/bin/bash
# List and analyze loaded kernel extensions
# Usage: ./list-loaded-kexts.sh [--third-party] [--check-unsigned]

set -e

THIRD_PARTY_ONLY=false
CHECK_UNSIGNED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --third-party)
            THIRD_PARTY_ONLY=true
            shift
            ;;
        --check-unsigned)
            CHECK_UNSIGNED=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== Loaded Kernel Extensions ==="
echo ""

if [ "$THIRD_PARTY_ONLY" = true ]; then
    echo "Third-party kexts only:"
    sudo kmutil showloaded --collection aux
else
    echo "All loaded kexts:"
    sudo kmutil showloaded --sort
fi

echo ""
echo "=== Kext Statistics ==="
TOTAL_KEXTS=$(sudo kmutil showloaded --sort | wc -l)
THIRD_PARTY=$(sudo kmutil showloaded --collection aux 2>/dev/null | wc -l)
echo "Total kexts: $TOTAL_KEXTS"
echo "Third-party kexts: $THIRD_PARTY"

if [ "$CHECK_UNSIGNED" = true ]; then
    echo ""
    echo "=== Checking for Unsigned Kexts ==="
    sudo kmutil showloaded --collection aux | while read -r line; do
        BUNDLE_ID=$(echo "$line" | awk '{print $NF}')
        if [ -n "$BUNDLE_ID" ]; then
            # Try to find the kext path
            KEXT_PATH=$(kextstat | grep "$BUNDLE_ID" | awk '{print $NF}')
            if [ -n "$KEXT_PATH" ] && [ -f "$KEXT_PATH" ]; then
                SIGNATURE=$(codesign -dv "$KEXT_PATH" 2>&1 | grep -i "not ad-hoc" || echo "signed")
                if echo "$SIGNATURE" | grep -qi "not ad-hoc"; then
                    echo "WARNING: Potentially unsigned: $BUNDLE_ID"
                fi
            fi
        fi
    done
fi

echo ""
echo "=== Recent Kext Load Events ==="
# Check for recent kmutil load invocations if audit logs available
if command -v log &> /dev/null; then
    log show --predicate 'eventMessage contains "kmutil"' --last 1h 2>/dev/null | head -20 || echo "No recent kmutil events found"
fi
