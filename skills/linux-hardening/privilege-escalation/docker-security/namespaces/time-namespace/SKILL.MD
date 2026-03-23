---
name: linux-time-namespace
description: Linux Time Namespace operations for security analysis, container hardening, and privilege escalation research. Use this skill whenever the user needs to create, inspect, or manipulate Linux time namespaces, check namespace membership, adjust CLOCK_MONOTONIC or CLOCK_BOOTTIME offsets, understand time namespace security implications, or harden container runtimes against time-based attacks. Trigger on mentions of time namespaces, timens, namespace isolation, container time manipulation, or Linux clock virtualization.
---

# Linux Time Namespace Operations

A skill for working with Linux time namespaces in security analysis, container hardening, and privilege escalation research.

## What Time Namespaces Do

Time namespaces allow per-namespace offsets to the system monotonic and boot-time clocks. They're used to:
- Change date/time within containers
- Adjust clocks after checkpoint/snapshot restoration
- Isolate time-based operations between processes

**Important**: `CLOCK_REALTIME` (wall clock) is **not** namespaced. Only `CLOCK_MONOTONIC` and `CLOCK_BOOTTIME` can be virtualized per namespace.

## Creating Time Namespaces

### Using unshare (CLI)

```bash
# Basic time namespace creation
sudo unshare -T --mount-proc /bin/bash

# With fork to avoid PID allocation issues
sudo unshare -Tf --mount-proc /bin/bash

# With time offset helpers (util-linux >= 2.38)
sudo unshare -T \
            --monotonic="+24h" \
            --boottime="+7d" \
            --mount-proc \
            bash
```

**Why `--mount-proc` matters**: Mounting a new `/proc` instance ensures the namespace has an accurate, isolated view of process information specific to that namespace.

**Why `-f` matters**: Without `-f`, the unshare process doesn't enter the new namespace—only its children do. This can cause "Cannot allocate memory" errors when PID 1 exits prematurely. The `-f` flag forks a new process, making unshare itself PID 1 in the new namespace.

### Using Docker

```bash
docker run -ti --name ubuntu1 -v /usr:/ubuntu1 ubuntu bash
```

### Using runc (OCI Runtime)

For runc >= 1.2.0, create a `config.json` with time namespace support:

```json
{
  "linux": {
    "namespaces": [
      {"type": "time"}
    ],
    "timeOffsets": {
      "monotonic": 86400,
      "boottime": 600
    }
  }
}
```

Then run: `runc run <container-id>`

**Security note**: runc 1.2.6 (Feb 2025) fixed an "exec into container with private timens" bug that could cause hangs and DoS. Use >= 1.2.6 in production.

## Inspecting Time Namespaces

### Check your current namespace

```bash
ls -l /proc/self/ns/time
# Output: time:[4026531834]
```

### Find all time namespaces on the system

```bash
sudo find /proc -maxdepth 3 -type l -name time -exec readlink {} \; 2>/dev/null | sort -u
```

### Find processes in a specific namespace

```bash
# Replace <ns-number> with the namespace ID from above
sudo find /proc -maxdepth 3 -type l -name time -exec ls -l {} \; 2>/dev/null | grep <ns-number>
```

### Enter an existing time namespace

```bash
nsenter -T TARGET_PID --pid /bin/bash
```

## Manipulating Time Offsets

Starting with Linux 5.6, time namespace offsets are exposed via `/proc/<PID>/timens_offsets`.

### View current offsets

```bash
sudo unshare -Tr --mount-proc bash
cat /proc/$$/timens_offsets
# Output:
# monotonic 0
# boottime  0
```

### Modify offsets (requires CAP_SYS_TIME in the namespace)

```bash
# Advance CLOCK_MONOTONIC by two days (172,800 seconds = 172,800,000,000,000 nanoseconds)
echo "monotonic 172800000000000" > /proc/$$/timens_offsets

# Verify the change
cat /proc/$$/uptime
# First column uses CLOCK_MONOTONIC
```

**Format**: The file contains two lines with offsets in **nanoseconds**:
- Line 1: `monotonic <nanoseconds>`
- Line 2: `boottime <nanoseconds>`

### Using unshare helpers (util-linux >= 2.38)

Instead of manually editing `timens_offsets`, use the long options:

```bash
sudo unshare -T \
            --monotonic="+24h" \
            --boottime="+7d" \
            --mount-proc \
            bash
```

This automatically writes the deltas after namespace creation.

## Security Considerations

### Required Capabilities

A process needs **CAP_SYS_TIME** inside its user/time namespace to change offsets. Dropping this capability in containers (default in Docker & Kubernetes) prevents tampering.

### What Cannot Be Spoofed

Because `CLOCK_REALTIME` is shared with the host, attackers **cannot** spoof:
- Certificate lifetimes
- JWT expiry times
- Wall-clock-based authentication tokens

### Attack Vectors to Watch

1. **Log/detection evasion**: Software relying on `CLOCK_MONOTONIC` (e.g., rate limiters based on uptime) can be confused by namespace offset adjustments.

2. **Kernel attack surface**: Even with `CAP_SYS_TIME` removed, kernel code remains accessible. Linux 5.6 → 5.12 received multiple timens bug-fixes (NULL-deref, signedness issues).

3. **runc vulnerabilities**: Versions before 1.2.6 had an exec-into-container bug causing hangs and potential DoS.

### Hardening Checklist

Apply these measures when securing containerized environments:

- [ ] Drop `CAP_SYS_TIME` in container runtime default profiles
- [ ] Keep runtimes updated (runc >= 1.2.6, crun >= 1.12)
- [ ] Pin util-linux >= 2.38 if using `--monotonic/--boottime` helpers
- [ ] Audit in-container software that reads **uptime** or **CLOCK_MONOTONIC** for security-critical logic
- [ ] Prefer `CLOCK_REALTIME` for security-relevant timestamps
- [ ] Keep the host kernel patched

## Common Use Cases

### Container Time Isolation

Use time namespaces to:
- Run containers with independent clock views
- Test time-sensitive applications without affecting the host
- Restore containers from checkpoints with adjusted clocks

### Security Research

Time namespaces are useful for:
- Understanding container isolation boundaries
- Testing time-based security controls
- Researching privilege escalation paths involving time manipulation

### Debugging Time-Related Issues

When applications behave unexpectedly due to time:
- Check which namespace the process is in
- Inspect `timens_offsets` for unexpected values
- Verify if the application uses `CLOCK_MONOTONIC` vs `CLOCK_REALTIME`

## References

- [man7.org – Time namespaces manual page](https://man7.org/linux/man-pages/man7/time_namespaces.7.html)
- [OCI blog – "OCI v1.1: new time and RDT namespaces" (Nov 15 2023)](https://opencontainers.org/blog/2023/11/15/oci-spec-v1.1)
- [Linux kernel documentation – Time namespaces](https://www.kernel.org/doc/html/latest/admin-guide/LSM/time_namespace.html)
