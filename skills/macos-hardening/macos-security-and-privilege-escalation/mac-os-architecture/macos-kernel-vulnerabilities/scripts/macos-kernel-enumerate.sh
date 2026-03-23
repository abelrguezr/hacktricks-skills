#!/bin/bash
# macOS Kernel Security Enumeration Script
# Collects baseline security data for vulnerability assessment

set -e

echo "=== macOS Kernel Security Enumeration ==="
echo "Timestamp: $(date)"
echo ""

# System Information
echo "--- System Information ---"
if command -v sw_vers &> /dev/null; then
    echo "macOS Version:"
    sw_vers
else
    echo "sw_vers not available"
fi
echo ""

# Kernel Information
echo "--- Kernel Information ---"
if command -v uname &> /dev/null; then
    echo "Kernel Build:"
    uname -a
else
    echo "uname not available"
fi
echo ""

# Kernel Version (requires sudo)
echo "--- Kernel Version ---"
if command -v sysctl &> /dev/null; then
    if sudo -n sysctl kern.osversion &> /dev/null; then
        echo "Kernel OS Version:"
        sudo sysctl kern.osversion
    else
        echo "(sudo required for kern.osversion)"
    fi
else
    echo "sysctl not available"
fi
echo ""

# KASLR Status
echo "--- KASLR Status ---"
if command -v sysctl &> /dev/null; then
    KASLR=$(sysctl -n kern.kaslr_enable 2>/dev/null || echo "unknown")
    echo "KASLR Enabled: $KASLR"
    if [ "$KASLR" = "1" ]; then
        echo "Status: ✓ KASLR is enabled (good)"
    else
        echo "Status: ✗ KASLR is disabled (security risk)"
    fi
else
    echo "sysctl not available"
fi
echo ""

# SIP Status (requires Recovery mode for full check)
echo "--- SIP Status ---"
if command -v csrutil &> /dev/null; then
    echo "Note: Full SIP status requires Recovery mode"
    echo "Run 'csrutil status' in Recovery mode for complete check"
else
    echo "csrutil not available"
fi
echo ""

# Gatekeeper Status
echo "--- Gatekeeper Status ---"
if command -v spctl &> /dev/null; then
    spctl --status 2>/dev/null || echo "(spctl requires admin privileges)"
else
    echo "spctl not available"
fi
echo ""

# Loaded Kernel Extensions
echo "--- Loaded Kernel Extensions ---"
if command -v kmutil &> /dev/null; then
    echo "Total loaded kexts:"
    kmutil showloaded 2>/dev/null | wc -l
    echo ""
    echo "Non-Apple kexts (potential attack surface):"
    NON_APPLE=$(kmutil showloaded 2>/dev/null | grep -v com.apple | wc -l)
    if [ "$NON_APPLE" -gt 0 ]; then
        kmutil showloaded 2>/dev/null | grep -v com.apple
        echo ""
        echo "Warning: $NON_APPLE non-Apple kext(s) loaded"
    else
        echo "No non-Apple kexts loaded"
    fi
else
    echo "kmutil not available (macOS 11+)"
    # Fallback to kextstat
    if command -v kextstat &> /dev/null; then
        echo "Legacy kext list (non-Apple only):"
        kextstat 2>/dev/null | grep -v com.apple | head -20
    fi
fi
echo ""

# Patch Level Detection
echo "--- Patch Level Detection ---"
if command -v sw_vers &> /dev/null; then
    VERSION=$(sw_vers -productVersion 2>/dev/null | cut -d. -f1,2)
    echo "Detected macOS version: $VERSION"
    
    # Check for known vulnerable versions
    MAJOR=$(echo $VERSION | cut -d. -f1)
    MINOR=$(echo $VERSION | cut -d. -f2)
    
    echo ""
    echo "CVE-2024-23225/23296 Status:"
    if [ "$MAJOR" -lt 12 ] || ([ "$MAJOR" -eq 12 ] && [ "$MINOR" -lt 7 ]) || \
       ([ "$MAJOR" -eq 13 ] && [ "$MINOR" -lt 6 ]) || \
       ([ "$MAJOR" -eq 14 ] && [ "$MINOR" -lt 4 ]); then
        echo "⚠ VULNERABLE - Update to macOS 14.4+ recommended"
    else
        echo "✓ Appears patched (version 14.4+)"
    fi
    
    echo ""
    echo "CVE-2024-44243 (Sigma) Status:"
    if [ "$MAJOR" -lt 15 ] || ([ "$MAJOR" -eq 15 ] && [ "$MINOR" -lt 2 ]); then
        echo "⚠ VULNERABLE - Update to macOS 15.2+ recommended"
    else
        echo "✓ Appears patched (version 15.2+)"
    fi
else
    echo "sw_vers not available"
fi
echo ""

# Storagekitd Monitoring
echo "--- Storagekitd Activity ---"
if command -v log &> /dev/null; then
    echo "Recent storagekitd activity (last 100 entries):"
    log show --predicate 'senderImagePath contains "storagekitd"' --last 1h 2>/dev/null | tail -20 || echo "(log command requires macOS 10.12+)"
else
    echo "log command not available"
fi
echo ""

echo "=== Enumeration Complete ==="
echo ""
echo "Next steps:"
echo "1. Review vulnerability status above"
echo "2. Check for non-Apple kernel extensions"
echo "3. Update macOS if vulnerable versions detected"
echo "4. Run 'csrutil status' in Recovery mode for full SIP check"
