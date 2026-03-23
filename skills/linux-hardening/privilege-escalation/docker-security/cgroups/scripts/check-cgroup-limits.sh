#!/bin/bash
# Check specific cgroup limits
# Usage: ./check-cgroup-limits.sh <cgroup-path>

if [ -z "$1" ]; then
    echo "Usage: $0 <cgroup-path>"
    echo "Example: $0 /user.slice/user-1000.slice/session-2.scope"
    echo ""
    echo "To find your cgroup path:"
    echo "  cat /proc/self/cgroup | cut -d: -f3 | sort -u"
    exit 1
fi

CGROUP_PATH="$1"
CGROUP_DIR="/sys/fs/cgroup/$CGROUP_PATH"

echo "=== CGroup Limits for: $CGROUP_PATH ==="
echo ""

if [ ! -d "$CGROUP_DIR" ]; then
    echo "ERROR: CGroup directory not found: $CGROUP_DIR"
    echo ""
    echo "Available cgroup directories:"
    ls -1 /sys/fs/cgroup/ 2>/dev/null | head -20
    exit 1
fi

echo "--- Memory Limits ---"
if [ -f "$CGROUP_DIR/memory.max" ]; then
    echo "memory.max: $(cat $CGROUP_DIR/memory.max)"
    echo "memory.current: $(cat $CGROUP_DIR/memory.current 2>/dev/null || echo 'N/A')"
    echo "memory.high: $(cat $CGROUP_DIR/memory.high 2>/dev/null || echo 'N/A')"
elif [ -f "$CGROUP_DIR/memory.limit_in_bytes" ]; then
    echo "memory.limit_in_bytes: $(cat $CGROUP_DIR/memory.limit_in_bytes)"
    echo "memory.usage_in_bytes: $(cat $CGROUP_DIR/memory.usage_in_bytes 2>/dev/null || echo 'N/A')"
else
    echo "No memory controller found"
fi
echo ""

echo "--- PID Limits ---"
if [ -f "$CGROUP_DIR/pids.max" ]; then
    echo "pids.max: $(cat $CGROUP_DIR/pids.max)"
    echo "pids.current: $(cat $CGROUP_DIR/pids.current 2>/dev/null || echo 'N/A')"
else
    echo "No PID controller found"
fi
echo ""

echo "--- CPU Limits ---"
if [ -f "$CGROUP_DIR/cpu.max" ]; then
    echo "cpu.max: $(cat $CGROUP_DIR/cpu.max)"
    echo "cpu.weight: $(cat $CGROUP_DIR/cpu.weight 2>/dev/null || echo 'N/A')"
    if [ -f "$CGROUP_DIR/cpu.stat" ]; then
        echo "cpu.stat (first 10 lines):"
        head -10 "$CGROUP_DIR/cpu.stat"
    fi
else
    echo "No CPU controller found"
fi
echo ""

echo "--- Device Access ---"
if [ -f "$CGROUP_DIR/devices.list" ]; then
    echo "devices.list:"
    cat "$CGROUP_DIR/devices.list"
else
    echo "No device controller found"
fi
echo ""

echo "--- Subtree Control ---"
if [ -f "$CGROUP_DIR/cgroup.subtree_control" ]; then
    echo "cgroup.subtree_control: $(cat $CGROUP_DIR/cgroup.subtree_control)"
else
    echo "No subtree control (leaf cgroup or v1)"
fi
echo ""

echo "--- Processes in CGroup ---"
if [ -f "$CGROUP_DIR/cgroup.procs" ]; then
    echo "Processes:"
    cat "$CGROUP_DIR/cgroup.procs" 2>/dev/null | head -20
    proc_count=$(cat "$CGROUP_DIR/cgroup.procs" 2>/dev/null | wc -l)
    echo "Total: $proc_count processes"
else
    echo "Cannot read cgroup.procs"
fi
echo ""

echo "--- Security Assessment ---"
# Check for unlimited resources
if [ -f "$CGROUP_DIR/memory.max" ] && [ "$(cat $CGROUP_DIR/memory.max)" = "max" ]; then
    echo "⚠ WARNING: Memory is unlimited"
fi
if [ -f "$CGROUP_DIR/pids.max" ] && [ "$(cat $CGROUP_DIR/pids.max)" = "max" ]; then
    echo "⚠ WARNING: PID limit is unlimited"
fi
if [ -f "$CGROUP_DIR/devices.list" ]; then
    if grep -q "a rw" "$CGROUP_DIR/devices.list" 2>/dev/null; then
        echo "⚠ WARNING: All devices are readable and writable"
    fi
    if grep -q "/dev/mem" "$CGROUP_DIR/devices.list" 2>/dev/null; then
        echo "⚠ WARNING: /dev/mem is accessible (potential kernel memory access)"
    fi
    if grep -q "/dev/kmem" "$CGROUP_DIR/devices.list" 2>/dev/null; then
        echo "⚠ WARNING: /dev/kmem is accessible (potential kernel memory access)"
    fi
fi
if [ -w "$CGROUP_DIR/cgroup.procs" ]; then
    echo "⚠ WARNING: cgroup.procs is writable (can add/remove processes)"
fi

echo ""
echo "=== End of Report ==="
