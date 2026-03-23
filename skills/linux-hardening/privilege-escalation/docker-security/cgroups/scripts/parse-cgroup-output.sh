#!/bin/bash
# Parse and explain /proc/self/cgroup output
# Usage: ./parse-cgroup-output.sh [cgroup-file]
# If no file specified, uses /proc/self/cgroup

CGROUP_FILE="${1:-/proc/self/cgroup}"

echo "=== CGroup Output Parser ==="
echo "Source: $CGROUP_FILE"
echo ""

if [ ! -f "$CGROUP_FILE" ]; then
    echo "ERROR: Cannot read $CGROUP_FILE"
    exit 1
fi

echo "--- Raw Output ---"
cat "$CGROUP_FILE"
echo ""

echo "--- Parsed Analysis ---"
echo ""

# Count cgroup versions
V1_COUNT=$(grep -E '^[0-9]+:' "$CGROUP_FILE" | grep -v '^0::' | wc -l)
V2_COUNT=$(grep -c '^0::' "$CGROUP_FILE" || echo 0)

echo "CGroup Version Summary:"
echo "  v1 controllers: $V1_COUNT"
echo "  v2 unified: $V2_COUNT"
if [ "$V2_COUNT" -gt 0 ] && [ "$V1_COUNT" -gt 0 ]; then
    echo "  Status: Hybrid (v1 and v2 running concurrently)"
elif [ "$V2_COUNT" -gt 0 ]; then
    echo "  Status: CGroup v2 only"
else
    echo "  Status: CGroup v1 only"
fi
echo ""

echo "--- Controller Breakdown ---"
echo ""

# Parse each line
while IFS=: read -r number controllers path; do
    echo "Line: $number:$controllers:$path"
    
    if [ "$number" = "0" ] && [ -z "$controllers" ]; then
        echo "  Type: CGroup v2 unified hierarchy"
        echo "  Controllers: All controllers in unified hierarchy"
    elif [ "$number" = "1" ] && [ "$controllers" = "name=systemd" ]; then
        echo "  Type: CGroup v1 systemd management"
        echo "  Controllers: None (management only)"
    else
        echo "  Type: CGroup v1"
        echo "  Controllers: $controllers"
        
        # Explain each controller
        IFS=',' read -ra CTRL_ARRAY <<< "$controllers"
        for ctrl in "${CTRL_ARRAY[@]}"; do
            case "$ctrl" in
                memory)
                    echo "    - memory: Controls memory usage limits"
                    ;;
                cpu|cpuacct)
                    echo "    - cpu/cpuacct: Controls CPU time and accounting"
                    ;;
                pids)
                    echo "    - pids: Controls process count limits"
                    ;;
                devices)
                    echo "    - devices: Controls device access"
                    ;;
                blkio)
                    echo "    - blkio: Controls block I/O"
                    ;;
                cpuset)
                    echo "    - cpuset: Controls CPU and memory node allocation"
                    ;;
                net_cls|net_prio)
                    echo "    - net_cls/net_prio: Network classification and priority"
                    ;;
                freezer)
                    echo "    - freezer: Can freeze/thaw processes"
                    ;;
                hugetlb)
                    echo "    - hugetlb: Huge page memory management"
                    ;;
                perf_event)
                    echo "    - perf_event: Performance event monitoring"
                    ;;
                rdma)
                    echo "    - rdma: Remote Direct Memory Access"
                    ;;
                *)
                    echo "    - $ctrl: Unknown or custom controller"
                    ;;
            esac
        done
    fi
    
    # Explain the path
    echo "  Path: $path"
    if [[ "$path" == "/user.slice"* ]]; then
        echo "    Context: User session managed by systemd"
    elif [[ "$path" == "/system.slice"* ]]; then
        echo "    Context: System service managed by systemd"
    elif [[ "$path" == "/" ]]; then
        echo "    Context: Root cgroup (no restrictions)"
    elif [[ "$path" == "/docker"* ]] || [[ "$path" == "/kubepods"* ]]; then
        echo "    Context: Container runtime (Docker/Kubernetes)"
    else
        echo "    Context: Custom or application-specific cgroup"
    fi
    echo ""
done < "$CGROUP_FILE"

echo "--- Security Implications ---"
echo ""

# Check for root cgroup access
if grep -q ':/user.slice' "$CGROUP_FILE"; then
    echo "✓ Process is in a user slice (systemd-managed)"
    echo "  This provides some isolation from system processes"
fi

if grep -q ':/system.slice' "$CGROUP_FILE"; then
    echo "✓ Process is in a system slice"
    echo "  This is typical for system services"
fi

if grep -q ':/$' "$CGROUP_FILE"; then
    echo "⚠ Process has access to root cgroup"
    echo "  This may allow bypassing some restrictions"
fi

if grep -q ':/docker' "$CGROUP_FILE" || grep -q ':/kubepods' "$CGROUP_FILE"; then
    echo "✓ Process appears to be in a container"
    echo "  Check device access and resource limits for security"
fi

echo ""
echo "--- Recommendations ---"
echo ""
echo "1. Check resource limits in /sys/fs/cgroup/<path>/"
echo "2. Verify device access is restricted (devices.list)"
echo "3. Look for 'max' values indicating unlimited resources"
echo "4. Check if cgroup.procs is writable (privilege escalation risk)"
echo "5. Review parent cgroup limits (limits may be inherited)"

echo ""
echo "=== End of Analysis ==="
