#!/bin/bash
# CGroup Security Analyzer
# Performs comprehensive cgroup security analysis

set -e

echo "=== CGroup Security Analysis ==="
echo ""

# Check cgroup version
echo "--- CGroup Version Detection ---"
if [ -d "/sys/fs/cgroup/unified" ]; then
    echo "CGroup v2 unified hierarchy detected at /sys/fs/cgroup/unified"
elif [ -f "/sys/fs/cgroup/cgroup.controllers" ]; then
    echo "CGroup v2 detected at /sys/fs/cgroup"
else
    echo "CGroup v1 detected (or hybrid v1/v2)"
fi
echo ""

# Parse /proc/self/cgroup
echo "--- Current Process CGroups ---"
if [ -f "/proc/self/cgroup" ]; then
    cat /proc/self/cgroup
else
    echo "Cannot read /proc/self/cgroup (permission denied or not available)"
fi
echo ""

# Extract unique cgroup paths
echo "--- Unique CGroup Paths ---"
if [ -f "/proc/self/cgroup" ]; then
    cat /proc/self/cgroup | cut -d: -f3 | sort -u | while read path; do
        echo "  $path"
    done
fi
echo ""

# Check resource limits
echo "--- Resource Limits ---"

# Memory
if [ -f "/sys/fs/cgroup/memory.max" ]; then
    mem_max=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "unknown")
    echo "Memory limit: $mem_max"
    if [ "$mem_max" = "max" ]; then
        echo "  WARNING: Memory is unlimited!"
    fi
elif [ -f "/sys/fs/cgroup/memory/memory.limit_in_bytes" ]; then
    mem_limit=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null || echo "unknown")
    echo "Memory limit (v1): $mem_limit bytes"
else
    echo "Memory limit: Not found"
fi

# PIDs
if [ -f "/sys/fs/cgroup/pids.max" ]; then
    pids_max=$(cat /sys/fs/cgroup/pids.max 2>/dev/null || echo "unknown")
    echo "PID limit: $pids_max"
    if [ "$pids_max" = "max" ]; then
        echo "  WARNING: PID limit is unlimited!"
    fi
elif [ -f "/sys/fs/cgroup/pids/pids.max" ]; then
    pids_max=$(cat /sys/fs/cgroup/pids/pids.max 2>/dev/null || echo "unknown")
    echo "PID limit (v1): $pids_max"
else
    echo "PID limit: Not found"
fi

# CPU
if [ -f "/sys/fs/cgroup/cpu.max" ]; then
    cpu_max=$(cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo "unknown")
    echo "CPU limit: $cpu_max"
else
    echo "CPU limit: Not found (may be unlimited)"
fi
echo ""

# Check device access
echo "--- Device Access ---"
if [ -f "/sys/fs/cgroup/devices.list" ]; then
    echo "Device list:"
    cat /sys/fs/cgroup/devices.list 2>/dev/null | head -20
    if grep -q "a r" /sys/fs/cgroup/devices.list 2>/dev/null; then
        echo "  WARNING: All devices readable!"
    fi
    if grep -q "a rw" /sys/fs/cgroup/devices.list 2>/dev/null; then
        echo "  WARNING: All devices readable and writable!"
    fi
elif [ -f "/sys/fs/cgroup/devices/devices.list" ]; then
    echo "Device list (v1):"
    cat /sys/fs/cgroup/devices/devices.list 2>/dev/null | head -20
else
    echo "Device list: Not found"
fi
echo ""

# Check for writable cgroup.procs
echo "--- Writable CGroup Files ---"
for cgroup_path in $(cat /proc/self/cgroup 2>/dev/null | cut -d: -f3 | sort -u); do
    cgroup_dir="/sys/fs/cgroup/$cgroup_path"
    if [ -d "$cgroup_dir" ]; then
        if [ -w "$cgroup_dir/cgroup.procs" ]; then
            echo "  WARNING: $cgroup_dir/cgroup.procs is writable!"
        fi
        if [ -w "$cgroup_dir/cgroup.subtree_control" ]; then
            echo "  WARNING: $cgroup_dir/cgroup.subtree_control is writable!"
        fi
    fi
done
echo ""

# Check current resource usage
echo "--- Current Resource Usage ---"
if [ -f "/sys/fs/cgroup/memory.current" ]; then
    echo "Memory current: $(cat /sys/fs/cgroup/memory.current 2>/dev/null || echo "unknown")"
fi
if [ -f "/sys/fs/cgroup/pids.current" ]; then
    echo "PIDs current: $(cat /sys/fs/cgroup/pids.current 2>/dev/null || echo "unknown")"
fi
if [ -f "/sys/fs/cgroup/cpu.stat" ]; then
    echo "CPU stat (first 5 lines):"
    head -5 /sys/fs/cgroup/cpu.stat 2>/dev/null
fi
echo ""

echo "=== Analysis Complete ==="
echo ""
echo "Security Recommendations:"
echo "1. Check if 'max' values indicate unlimited resources (potential DoS vector)"
echo "2. Verify device access is restricted (container escape prevention)"
echo "3. Ensure cgroup.procs is not writable (prevents process manipulation)"
echo "4. Review parent cgroup limits (limits may be inherited)"
