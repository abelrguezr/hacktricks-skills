#!/bin/bash
# macOS SIP Status Checker
# This script checks System Integrity Protection status and related security settings

set -e

echo "=== macOS SIP Status Check ==="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "ERROR: This script requires macOS"
    exit 1
fi

echo "1. SIP Status"
echo "-------------"
if csrutil status 2>/dev/null; then
    echo "✓ SIP status retrieved"
else
    echo "✗ Could not retrieve SIP status (may require recovery mode)"
fi
echo ""

echo "2. Authenticated Root Status"
echo "-----------------------------"
if csrutil authenticated-root status 2>/dev/null; then
    echo "✓ Authenticated root status retrieved"
else
    echo "✗ Could not retrieve authenticated root status"
fi
echo ""

echo "3. Mount Status (Sealed/Read-Only)"
echo "-----------------------------------"
mount | grep -E "(sealed|read-only)" || echo "No sealed/read-only mounts found"
echo ""

echo "4. Protected Directory Flags"
echo "----------------------------"
for dir in "/usr" "/bin" "/sbin" "/System"; do
    if [[ -d "$dir" ]]; then
        flags=$(ls -lOd "$dir" 2>/dev/null | awk '{print $1}' | grep -E "(restricted|sunlnk)" || echo "none")
        echo "$dir: $flags"
    else
        echo "$dir: not found"
    fi
done
echo ""

echo "5. Zshenv Files (Potential Bypass Vectors)"
echo "-------------------------------------------"
if [[ -f "/etc/zshenv" ]]; then
    echo "⚠ /etc/zshenv exists: $(wc -l < /etc/zshenv) lines"
else
    echo "✓ /etc/zshenv does not exist"
fi

if [[ -f "~/.zshenv" ]]; then
    echo "⚠ ~/.zshenv exists: $(wc -l < ~/.zshenv) lines"
else
    echo "✓ ~/.zshenv does not exist"
fi
echo ""

echo "6. APFS Snapshot Information"
echo "----------------------------"
if command -v diskutil &> /dev/null; then
    diskutil apfs list 2>/dev/null | grep -E "(Snapshot|Sealed|Role)" | head -20 || echo "Could not retrieve APFS info"
else
    echo "diskutil not available"
fi
echo ""

echo "7. NVRAM SIP Configuration"
echo "--------------------------"
if command -v nvram &> /dev/null; then
    nvram csr-active-config 2>/dev/null || echo "Could not read csr-active-config"
else
    echo "nvram not available"
fi
echo ""

echo "=== Check Complete ==="
echo ""
echo "Note: Some checks may require elevated privileges or recovery mode"
