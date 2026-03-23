---
name: cgroup-security-analyzer
description: Analyze Linux cgroups for security assessment, privilege escalation opportunities, and resource limit analysis. Use this skill whenever the user mentions cgroups, control groups, container resource limits, Linux process isolation, systemd slices, or wants to audit container security configurations. Also trigger when investigating potential privilege escalation paths through cgroup manipulation, analyzing /proc/self/cgroup output, or examining /sys/fs/cgroup settings.
---

# CGroup Security Analyzer

A skill for analyzing Linux Control Groups (cgroups) to identify security configurations, resource limits, and potential privilege escalation vectors.

## What This Skill Does

This skill helps you:
- Parse and interpret cgroup configurations from `/proc/self/cgroup` and `/sys/fs/cgroup`
- Identify resource limits (memory, CPU, PIDs, devices) that may be exploitable
- Detect cgroup v1 vs v2 configurations and their security implications
- Find potential privilege escalation paths through cgroup manipulation
- Analyze container isolation effectiveness

## When to Use This Skill

Use this skill when:
- You need to understand what cgroups a process belongs to
- You're auditing container security or resource limits
- You're investigating privilege escalation opportunities
- You need to parse `/proc/self/cgroup` or `/sys/fs/cgroup` output
- You're analyzing systemd slice configurations
- You want to check if cgroup limits can be bypassed or exploited

## Quick Start

### View Current Process Cgroups

```bash
# See which cgroups your current shell belongs to
cat /proc/self/cgroup

# For a specific process
cat /proc/<PID>/cgroup
```

### Analyze Cgroup Configuration

Use the bundled scripts to automate analysis:

```bash
# Full cgroup security analysis
./scripts/analyze-cgroups.sh

# Check specific cgroup limits
./scripts/check-cgroup-limits.sh <cgroup-path>

# Parse cgroup output and explain it
./scripts/parse-cgroup-output.sh
```

## Understanding Cgroup Output

### Cgroup v1 Format

Each line in `/proc/self/cgroup` follows this pattern:
```
<controller-number>:<controller-names>:<hierarchy-path>
```

**Example:**
```
12:rdma:/
11:net_cls,net_prio:/
10:perf_event:/
9:cpuset:/
8:cpu,cpuacct:/user.slice
7:blkio:/user.slice
6:memory:/user.slice
5:pids:/user.slice/user-1000.slice/session-2.scope
4:devices:/user.slice
3:freezer:/
2:hugetlb:/testcgroup
1:name=systemd:/user.slice/user-1000.slice/session-2.scope
0::/user.slice/user-1000.slice/session-2.scope
```

**Key observations:**
- **Lines 2-12**: cgroups v1 controllers (each number = different controller)
- **Line 1**: cgroups v1 management (systemd, no controller)
- **Line 0**: cgroups v2 (unified hierarchy, no controllers listed)
- **Paths like `/user.slice`**: systemd-managed user sessions
- **Paths like `/system.slice`**: system services

### Cgroup v2 Format

On cgroups v2-only systems, you'll see only line 0:
```
0::/user.slice/user-1000.slice/session-2.scope
```

The unified hierarchy is at `/sys/fs/cgroup/unified` or `/sys/fs/cgroup`.

## Security-Relevant Cgroup Controllers

### Memory Controller

**Files to check:**
- `memory.current` - Current memory usage
- `memory.max` - Memory limit ("max" means unlimited)
- `memory.high` - Memory threshold for throttling

**Security implications:**
- Unlimited memory (`max`) can lead to DoS
- Memory limits can be exploited for resource exhaustion attacks
- Check if limits are inherited from parent cgroups

### PID Controller

**Files to check:**
- `pids.current` - Current process count
- `pids.max` - Maximum processes allowed

**Security implications:**
- Low PID limits can cause fork bombs to fail
- Unlimited PIDs allow process flooding
- Can be used to detect container escape attempts

### CPU Controller

**Files to check:**
- `cpu.stat` - CPU usage statistics
- `cpu.max` - CPU time limits
- `cpu.weight` - CPU scheduling priority

**Security implications:**
- CPU limits can be bypassed in some configurations
- Weight settings affect process priority
- Can detect resource-intensive malicious processes

### Devices Controller

**Files to check:**
- `devices.list` - Allowed device access

**Security implications:**
- Critical for container security
- Overly permissive device access enables escapes
- Check for `/dev/mem`, `/dev/kmem` access

## Common Privilege Escalation Vectors

### 1. Cgroup Root Access

The root cgroup allows direct process placement, bypassing systemd:
```bash
# Check if you can write to root cgroup
echo $$ > /sys/fs/cgroup/cgroup.procs
```

**Risk:** If writable, you can remove processes from systemd management.

### 2. Subtree Control Manipulation

Child cgroups can enable controllers not present in parents:
```bash
# Check subtree control
cat cgroup.subtree_control

# Enable controllers (requires root)
echo "+cpu +pids" > cgroup.subtree_control
```

**Risk:** Misconfigured subtree control can allow privilege escalation.

### 3. Resource Limit Bypass

Limits may be inherited from parent cgroups:
```bash
# Check parent limits
cat /sys/fs/cgroup/memory.max
cat /sys/fs/cgroup/user.slice/memory.max
```

**Risk:** Parent limits may be more restrictive than child limits.

### 4. Device Access

Check device permissions:
```bash
cat /sys/fs/cgroup/devices.list
```

**Risk:** Access to `/dev/mem`, `/dev/kmem`, or `/dev/sda` can enable escapes.

## Analysis Workflow

### Step 1: Identify Cgroup Version

```bash
# Check for v2 unified hierarchy
ls -la /sys/fs/cgroup/

# If you see 'unified' or only line 0 in /proc/self/cgroup, it's v2
# If you see multiple numbered lines, it's v1 or hybrid
```

### Step 2: Map Current Cgroups

```bash
# Get your cgroup paths
cat /proc/self/cgroup | grep -v '^0::' | cut -d: -f3 | sort -u

# For each path, check the cgroup directory
for path in $(cat /proc/self/cgroup | cut -d: -f3 | sort -u); do
  echo "=== $path ==="
  ls -la /sys/fs/cgroup/$path/ 2>/dev/null
done
```

### Step 3: Check Resource Limits

```bash
# Memory
cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "No memory limit"

# PIDs
cat /sys/fs/cgroup/pids.max 2>/dev/null || echo "No PID limit"

# CPU
cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo "No CPU limit"
```

### Step 4: Identify Security Issues

Look for:
- `max` values (unlimited resources)
- Writable cgroup.procs files
- Permissive device lists
- Missing controllers in expected cgroups
- Inherited limits from parent cgroups

## Scripts Reference

### analyze-cgroups.sh

Performs a comprehensive cgroup security analysis:
- Identifies cgroup version
- Lists all cgroups for current process
- Checks resource limits
- Identifies potential security issues

### check-cgroup-limits.sh <cgroup-path>

Checks specific limits for a cgroup path:
- Memory limits
- PID limits
- CPU limits
- Device access

### parse-cgroup-output.sh

Parses `/proc/self/cgroup` output and explains:
- Each controller
- Hierarchy structure
- Security implications

## Best Practices

1. **Always check parent cgroups** - Limits may be inherited
2. **Verify cgroup version** - v1 and v2 have different security models
3. **Check device access** - Critical for container escapes
4. **Look for writable files** - cgroup.procs, subtree_control
5. **Understand systemd integration** - Many cgroups are managed by systemd

## References

- `/proc/self/cgroup` - Current process cgroup membership
- `/sys/fs/cgroup/` - Cgroup filesystem interface
- `cgroup.procs` - Process list for a cgroup
- `cgroup.threads` - Thread list for a cgroup
- `cgroup.subtree_control` - Controller enablement for child cgroups

## Troubleshooting

### "Permission denied" when accessing cgroup files

You need root privileges to modify cgroups. Reading is usually allowed.

### Cgroup path doesn't exist

The cgroup may have been removed or the process moved. Check `/proc/<pid>/cgroup` for the current state.

### "max" value in limit files

This means unlimited. Check parent cgroups for inherited limits.

### Multiple cgroup versions

Systems can run v1 and v2 concurrently. Check both `/sys/fs/cgroup/` and `/sys/fs/cgroup/unified/`.
