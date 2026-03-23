#!/bin/bash
# Container Capabilities Check Script
# Analyzes container capabilities for escape potential

echo "=== Container Capabilities Analysis ==="
echo ""

echo "[1] Current Capabilities"
if command -v capsh &> /dev/null; then
    capsh --print
else
    echo "capsh not available, using /proc/self/status"
    cat /proc/self/status | grep -E "Cap|NoNewPrivs"
fi
echo ""

echo "[2] Dangerous Capabilities Check"
DANGEROUS_CAPS=(
    "CAP_SYS_ADMIN"
    "CAP_SYS_PTRACE"
    "CAP_SYS_MODULE"
    "CAP_DAC_READ_SEARCH"
    "CAP_DAC_OVERRIDE"
    "CAP_SYS_RAWIO"
    "CAP_SYSLOG"
    "CAP_NET_RAW"
    "CAP_NET_ADMIN"
    "CAP_SYS_CHROOT"
    "CAP_MKNOD"
)

for cap in "${DANGEROUS_CAPS[@]}"; do
    if capsh --print 2>/dev/null | grep -q "$cap"; then
        echo "[!] DANGEROUS: $cap is present"
    fi
done
echo ""

echo "[3] Capability-Based Escape Vectors"
echo ""

# Check for CAP_SYS_ADMIN
if capsh --print 2>/dev/null | grep -q "CAP_SYS_ADMIN"; then
    echo "[CAP_SYS_ADMIN] Possible escapes:"
    echo "  - Mount host filesystem"
    echo "  - Load kernel modules"
    echo "  - Use nsenter to enter host namespaces"
    echo "  - Exploit cgroup release_agent (CVE-2022-0492)"
    echo "  - Pivot root"
    echo ""
fi

# Check for CAP_SYS_PTRACE
if capsh --print 2>/dev/null | grep -q "CAP_SYS_PTRACE"; then
    echo "[CAP_SYS_PTRACE] Possible escapes:"
    echo "  - Trace host processes"
    echo "  - Read process memory"
    echo "  - Inject code into processes"
    echo ""
fi

# Check for CAP_SYS_MODULE
if capsh --print 2>/dev/null | grep -q "CAP_SYS_MODULE"; then
    echo "[CAP_SYS_MODULE] Possible escapes:"
    echo "  - Load malicious kernel modules"
    echo "  - Kernel-level privilege escalation"
    echo ""
fi

# Check for DAC capabilities
if capsh --print 2>/dev/null | grep -qE "CAP_DAC_OVERRIDE|CAP_DAC_READ_SEARCH"; then
    echo "[DAC_CAPS] Possible escapes:"
    echo "  - Read any file on container"
    echo "  - Bypass file permission checks"
    echo "  - Access sensitive configuration files"
    echo ""
fi

# Check for CAP_NET_RAW
if capsh --print 2>/dev/null | grep -q "CAP_NET_RAW"; then
    echo "[CAP_NET_RAW] Possible escapes:"
    echo "  - Send raw packets"
    echo "  - Network sniffing"
    echo "  - ARP spoofing"
    echo ""
fi

# Check for CAP_NET_ADMIN
if capsh --print 2>/dev/null | grep -q "CAP_NET_ADMIN"; then
    echo "[CAP_NET_ADMIN] Possible escapes:"
    echo "  - Modify network configuration"
    echo "  - Add/remove network interfaces"
    echo "  - IP spoofing"
    echo ""
fi

# Check for CAP_MKNOD
if capsh --print 2>/dev/null | grep -q "CAP_MKNOD"; then
    echo "[CAP_MKNOD] Possible escapes:"
    echo "  - Create device files"
    echo "  - Access host block devices via /proc/PID/root"
    echo "  - Mount filesystems"
    echo ""
fi

echo "[4] Syscall Analysis"
echo "Checking for available syscalls..."

# Create a simple syscall checker
cat > /tmp/syscall_check.c << 'EOF'
#include <sys/syscall.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

int main() {
    int dangerous_syscalls[] = {
        SYS_pivot_root, SYS_mount, SYS_umount2,
        SYS_init_module, SYS_delete_module,
        SYS_reboot, SYS_kexec_load,
        SYS_unshare, SYS_clone
    };
    int count = sizeof(dangerous_syscalls) / sizeof(int);
    
    printf("Checking dangerous syscalls:\n");
    for (int i = 0; i < count; i++) {
        errno = 0;
        long result = syscall(dangerous_syscalls[i]);
        if (errno == EPERM) {
            printf("  [BLOCKED] syscall 0x%x\n", dangerous_syscalls[i]);
        } else {
            printf("  [AVAILABLE] syscall 0x%x (result: %ld)\n", dangerous_syscalls[i], result);
        }
    }
    return 0;
}
EOF

if command -v gcc &> /dev/null; then
    echo "Compiling syscall checker..."
    if gcc -o /tmp/syscall_check /tmp/syscall_check.c 2>/dev/null; then
        echo "Running syscall check:"
        /tmp/syscall_check
    else
        echo "Could not compile syscall checker"
    fi
else
    echo "gcc not available, skipping syscall analysis"
fi
echo ""

echo "[5] Recommendations"
echo "Based on the capabilities found:"
echo ""

if capsh --print 2>/dev/null | grep -q "CAP_SYS_ADMIN"; then
    echo "1. Try cgroup release_agent exploit (CVE-2022-0492)"
    echo "2. Attempt to mount host filesystem"
    echo "3. Use nsenter to enter host namespaces"
else
    echo "1. Check for other capability combinations"
    echo "2. Look for exposed docker socket"
    echo "3. Check for sensitive mounts"
fi
echo ""

echo "=== Analysis Complete ==="
