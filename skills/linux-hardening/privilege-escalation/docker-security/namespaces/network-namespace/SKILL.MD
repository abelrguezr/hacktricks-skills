---
name: linux-network-namespaces
description: How to work with Linux network namespaces for security testing, containerization, and system administration. Use this skill whenever the user mentions network namespaces, network isolation, container networking, nsenter, unshare, veth pairs, or needs to inspect/create/enter network namespaces. Also trigger when users want to understand network stack isolation, troubleshoot container networking, or perform privilege escalation research involving network namespaces.
---

# Linux Network Namespaces

A skill for working with Linux network namespaces to understand, create, inspect, and manipulate network isolation on Linux systems.

## What are Network Namespaces?

Network namespaces are a Linux kernel feature that provides isolation of the network stack. Each namespace has its own:
- Network interfaces
- IP addresses
- Routing tables
- Firewall rules (iptables/nftables)
- Port bindings

This is essential for containerization, security testing, and understanding Linux network isolation.

## When to Use This Skill

Use this skill when you need to:
- Create isolated network environments for testing
- Inspect or enumerate network namespaces on a system
- Enter or interact with existing network namespaces
- Understand container networking (Docker, Kubernetes, etc.)
- Perform security research on network isolation
- Troubleshoot network connectivity in containerized environments

## Quick Reference

### Create a New Network Namespace

```bash
# Basic namespace with bash
sudo unshare -n /bin/bash

# With isolated /proc view (recommended)
sudo unshare -n --mount-proc /bin/bash

# With fork (prevents PID allocation errors)
sudo unshare -nf /bin/bash
```

### Inspect Current Namespace

```bash
# Check which namespace your process is in
ls -l /proc/self/ns/net
# Output: net:[4026531840]

# View network interfaces in current namespace
ip -a
# or
ifconfig
```

### List All Network Namespaces

```bash
# Find all unique network namespaces
sudo find /proc -maxdepth 3 -type l -name net -exec readlink {} \; 2>/dev/null | sort -u | grep "net:"

# Find processes in a specific namespace (replace NS_NUMBER)
sudo find /proc -maxdepth 3 -type l -name net -exec ls -l {} \; 2>/dev/null | grep <NS_NUMBER>
```

### Enter an Existing Namespace

```bash
# Enter namespace of a target process
sudo nsenter -t TARGET_PID -n /bin/bash

# Alternative syntax
sudo nsenter -n TARGET_PID --pid /bin/bash
```

**Important:** You need root privileges to enter another process's namespace, and you need a descriptor pointing to it (like `/proc/self/ns/net`).

### Docker Network Namespaces

```bash
# Run container with isolated network namespace
docker run -ti --name ubuntu1 ubuntu bash

# Inside container, check namespace
ip -a
```

## Common Tasks

### Task 1: Create an Isolated Network Environment

```bash
# Create namespace and get a shell
sudo unshare -n --mount-proc /bin/bash

# Verify isolation - should only see loopback
ip -a
# Expected: only 'lo' interface visible

# Test connectivity (should fail - no external network)
ping -c 1 8.8.8.8
# Expected: Network unreachable
```

### Task 2: Connect Two Namespaces with Veth Pair

```bash
# In host namespace
# Create veth pair
sudo ip link add veth0 type veth peer name veth1

# Move one end to new namespace
sudo ip link set veth1 netns <PID_OR_NS_NAME>

# Configure in host namespace
sudo ip addr add 10.0.0.1/24 dev veth0
sudo ip link set veth0 up

# In the new namespace (via nsenter)
sudo ip addr add 10.0.0.2/24 dev veth1
sudo ip link set veth1 up
sudo ip link set lo up

# Test connectivity
ping 10.0.0.1
```

### Task 3: Enumerate Namespaces for Security Research

```bash
# List all namespaces with their PIDs
for ns in $(sudo find /proc -maxdepth 3 -type l -name net -exec readlink {} \; 2>/dev/null | sort -u | grep "net:"); do
  echo "=== $ns ==="
  sudo find /proc -maxdepth 3 -type l -name net -exec ls -l {} \; 2>/dev/null | grep "$ns" | awk '{print $9}' | xargs -I {} basename {}
done

# Get processes in each namespace
sudo ls -l /proc/*/ns/net 2>/dev/null | sort -u
```

### Task 4: Inspect Namespace Network Configuration

```bash
# Enter namespace and inspect
sudo nsenter -t <PID> -n -- bash -c '
  echo "=== Interfaces ==="
  ip -a
  echo "=== Routes ==="
  ip route
  echo "=== ARP ==="
  ip neigh
  echo "=== Firewall ==="
  iptables -L -n 2>/dev/null || echo "No iptables access"
'
```

## Troubleshooting

### Error: "bash: fork: Cannot allocate memory"

**Cause:** When `unshare` creates a new PID namespace without the `-f` flag, the process doesn't enter the namespace itself - only child processes do. If PID 1 exits, the namespace disables PID allocation.

**Solution:** Use the `-f` (fork) flag:
```bash
# Wrong - may cause memory allocation error
sudo unshare -n /bin/bash

# Correct - forks before entering namespace
sudo unshare -nf /bin/bash
```

### Cannot Enter Namespace

**Cause:** You need root privileges and a valid namespace descriptor.

**Solution:**
```bash
# Ensure you're root
sudo -i

# Verify namespace exists
ls -l /proc/<PID>/ns/net

# Use nsenter with correct syntax
sudo nsenter -t <PID> -n /bin/bash
```

### No Network Connectivity in New Namespace

**Expected behavior:** New namespaces start with only the loopback interface. To add connectivity:
1. Create veth pairs
2. Move one end to the namespace
3. Configure IP addresses on both ends
4. Optionally add routing or bridge to host

## Security Considerations

- **Privilege escalation:** Network namespaces can be used to bypass network-based security controls
- **Container escape:** Understanding namespaces helps identify container escape vectors
- **Network isolation testing:** Verify containers are properly isolated from host and each other
- **Firewall rules:** Each namespace has independent iptables/nftables rules

## References

- [Linux Namespaces Documentation](https://man7.org/linux/man-pages/man7/namespaces.7.html)
- [Network Namespaces Deep Dive](https://lwn.net/Articles/531114/)
- [Docker Networking](https://docs.docker.com/network/)

## Scripts

For common namespace operations, use the bundled scripts:
- `scripts/list-namespaces.sh` - List all network namespaces and their processes
- `scripts/enter-namespace.sh` - Enter a namespace by PID or name
- `scripts/create-namespace.sh` - Create and optionally connect a new namespace
- `scripts/inspect-namespace.sh` - Inspect network configuration of a namespace
