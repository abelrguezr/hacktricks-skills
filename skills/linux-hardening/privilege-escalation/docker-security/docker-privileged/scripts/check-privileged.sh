#!/bin/bash
# Docker Privileged Container Check Script
# Run this inside a container to check if it's running with --privileged

echo "=== Docker Privilege Check ==="
echo ""

# Check device count
DEV_COUNT=$(ls /dev 2>/dev/null | wc -l)
echo "[1] Device count: $DEV_COUNT"
if [ "$DEV_COUNT" -gt 50 ]; then
    echo "    ⚠️  High device count suggests privileged mode"
else
    echo "    ✓ Normal device count"
fi
echo ""

# Check Seccomp
if [ -f /proc/1/status ]; then
    SECCOMP=$(grep Seccomp /proc/1/status 2>/dev/null | awk '{print $2}')
    echo "[2] Seccomp: $SECCOMP"
    if [ "$SECCOMP" = "0" ]; then
        echo "    ⚠️  Seccomp disabled (privileged)"
    else
        echo "    ✓ Seccomp enabled"
    fi
else
    echo "[2] Seccomp: Unable to check (no /proc/1/status)"
fi
echo ""

# Check for read-only sysfs
SYSFS_MOUNT=$(mount 2>/dev/null | grep 'sysfs on /sys')
if echo "$SYSFS_MOUNT" | grep -q 'ro'; then
    echo "[3] Sysfs: Read-only"
    echo "    ✓ Standard container"
else
    echo "[3] Sysfs: Read-write or not mounted"
    echo "    ⚠️  Suggests privileged mode"
fi
echo ""

# Check proc tmpfs overlays
PROC_TMPFS=$(mount 2>/dev/null | grep '/proc.*tmpfs' | wc -l)
echo "[4] Proc tmpfs overlays: $PROC_TMPFS"
if [ "$PROC_TMPFS" -eq 0 ]; then
    echo "    ⚠️  No overlays (privileged)"
else
    echo "    ✓ Overlays present (standard)"
fi
echo ""

# Check capabilities if available
if command -v capsh &>/dev/null; then
    CAP_OUTPUT=$(capsh --print 2>/dev/null)
    CAP_COUNT=$(echo "$CAP_OUTPUT" | grep 'Bounding set' | tr ',' '\n' | wc -l)
    echo "[5] Capability count: $CAP_COUNT"
    if [ "$CAP_COUNT" -gt 30 ]; then
        echo "    ⚠️  High capability count (privileged)"
    else
        echo "    ✓ Limited capabilities"
    fi
else
    echo "[5] Capabilities: capsh not available"
fi
echo ""

# Check for host devices
HOST_DEVICES=$(ls /dev 2>/dev/null | grep -E 'sd[a-z]|nvme|loop' | wc -l)
echo "[6] Host block devices visible: $HOST_DEVICES"
if [ "$HOST_DEVICES" -gt 0 ]; then
    echo "    ⚠️  Host devices accessible"
    ls /dev | grep -E 'sd[a-z]|nvme|loop'
else
    echo "    ✓ No host devices visible"
fi
echo ""

# Final assessment
echo "=== Assessment ==="
PRIVILEGED_INDICATORS=0

[ "$DEV_COUNT" -gt 50 ] && ((PRIVILEGED_INDICATORS++))
[ "$SECCOMP" = "0" ] && ((PRIVILEGED_INDICATORS++))
! echo "$SYSFS_MOUNT" | grep -q 'ro' && ((PRIVILEGED_INDICATORS++))
[ "$PROC_TMPFS" -eq 0 ] && ((PRIVILEGED_INDICATORS++))
[ "$CAP_COUNT" -gt 30 ] && ((PRIVILEGED_INDICATORS++))
[ "$HOST_DEVICES" -gt 0 ] && ((PRIVILEGED_INDICATORS++))

echo "Privileged indicators: $PRIVILEGED_INDICATORS/6"

if [ "$PRIVILEGED_INDICATORS" -ge 4 ]; then
    echo ""
    echo "⚠️⚠️⚠️  LIKELY PRIVILEGED CONTAINER ⚠️⚠️⚠️"
    echo "This container has most indicators of --privileged mode."
    echo "Potential escape vectors available."
elif [ "$PRIVILEGED_INDICATORS" -ge 2 ]; then
    echo ""
    echo "⚠️  PARTIALLY PRIVILEGED"
    echo "Some security features may be disabled."
else
    echo ""
    echo "✓ Standard container with normal security restrictions"
fi
