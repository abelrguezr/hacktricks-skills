---
name: docker-seccomp-hardening
description: Docker container security hardening using Seccomp syscall filtering. Use this skill whenever you need to restrict system calls in Docker containers, create custom seccomp profiles, profile applications with strace to determine required syscalls, or harden container security posture. Trigger this skill for any Docker security task involving syscall filtering, container isolation, or seccomp profile creation and validation.
---

# Docker Seccomp Hardening

A skill for securing Docker containers using Seccomp (Secure Computing Mode) syscall filtering.

## What is Seccomp?

Seccomp is a Linux kernel security feature that filters system calls. It restricts processes to a limited set of syscalls, terminating them if they attempt unauthorized calls. This reduces the attack surface of containers.

### Key Concepts

- **Strict Mode**: Only allows `exit()`, `sigreturn()`, `read()`, and `write()` to already-open file descriptors
- **Seccomp-bpf**: Uses Berkeley Packet Filter rules for customizable syscall filtering (recommended for Docker)
- **Default Docker Profile**: Docker ships with a default seccomp profile that blocks dangerous syscalls

## When to Use This Skill

Use this skill when:
- You need to restrict syscalls in Docker containers
- You want to create custom seccomp profiles for specific applications
- You need to profile an application to determine which syscalls it requires
- You're hardening container security posture
- You want to prevent privilege escalation through syscall abuse
- You need to validate or debug seccomp configurations

## Creating Custom Seccomp Profiles

### Step 1: Profile the Application with Strace

First, identify which syscalls your application needs:

```bash
# Run the application with strace to capture syscalls
docker run -it --rm --security-opt seccomp=default.json <image> strace <command>

# Example: profile uname
docker run -it --rm --security-opt seccomp=default.json busybox strace uname
```

### Step 2: Generate a Whitelist Profile

Use the `generate-seccomp-profile.sh` script to create a whitelist from strace output:

```bash
# Generate a whitelist profile from strace output
cd scripts
./generate-seccomp-profile.sh < strace_output.txt > custom-profile.json
```

### Step 3: Validate the Profile

Check that your profile is valid JSON and properly formatted:

```bash
./validate-seccomp-profile.sh custom-profile.json
```

### Step 4: Apply the Profile

Run your container with the custom seccomp profile:

```bash
docker run --rm -it \
  --security-opt seccomp=/path/to/custom-profile.json \
  <image>
```

## Profile Structure

Seccomp profiles are JSON files with this structure:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "name": "chmod",
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

### Available Actions

- `SCMP_ACT_ALLOW`: Allow the syscall
- `SCMP_ACT_KILL`: Kill the process (SIGSYS)
- `SCMP_ACT_TRAP`: Trap the syscall (raise SIGSYS)
- `SCMP_ACT_ERRNO`: Return an error code
- `SCMP_ACT_LOG`: Log the syscall but allow it

### Default Action Strategies

**Blacklist approach** (less secure, easier to start):
```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {"name": "chmod", "action": "SCMP_ACT_ERRNO"},
    {"name": "mount", "action": "SCMP_ACT_KILL"}
  ]
}
```

**Whitelist approach** (more secure, requires profiling):
```json
{
  "defaultAction": "SCMP_ACT_KILL",
  "syscalls": [
    {"name": "read", "action": "SCMP_ACT_ALLOW"},
    {"name": "write", "action": "SCMP_ACT_ALLOW"},
    {"name": "exit", "action": "SCMP_ACT_ALLOW"}
  ]
}
```

## Common Use Cases

### Block Specific Syscalls

To block a specific syscall like `chmod`:

```json
{
  "defaultAction": "SCMP_ACT_ALLOW",
  "syscalls": [
    {
      "name": "chmod",
      "action": "SCMP_ACT_ERRNO"
    }
  ]
}
```

### Prevent Binary Execution

To prevent a specific binary from working, profile it with strace and block all its syscalls:

```bash
# Profile the binary
docker run -it --rm --security-opt seccomp=default.json <image> strace <binary>

# Block the discovered syscalls in your profile
```

### Minimal Profile for Simple Applications

For applications that only need basic I/O:

```json
{
  "defaultAction": "SCMP_ACT_KILL",
  "syscalls": [
    {"name": "read", "action": "SCMP_ACT_ALLOW"},
    {"name": "write", "action": "SCMP_ACT_ALLOW"},
    {"name": "exit", "action": "SCMP_ACT_ALLOW"},
    {"name": "exit_group", "action": "SCMP_ACT_ALLOW"},
    {"name": "sigreturn", "action": "SCMP_ACT_ALLOW"},
    {"name": "brk", "action": "SCMP_ACT_ALLOW"}
  ]
}
```

## Testing Your Profile

### Quick Test

```bash
# Test if chmod is blocked
docker run --rm -it \
  --security-opt seccomp=/path/to/profile.json \
  busybox chmod 400 /etc/hosts

# Expected: "chmod: /etc/hosts: Operation not permitted"
```

### Verify Profile is Applied

```bash
# Check the active seccomp profile
docker inspect <container> | grep -A 5 SecurityOpt
```

## Troubleshooting

### Container Won't Start

If your container fails to start with a seccomp profile:

1. Check for syntax errors in the JSON
2. Verify the profile allows essential syscalls (`brk`, `exit_group`, `mmap`, etc.)
3. Use `strace` to see which syscall is being blocked
4. Temporarily switch to `SCMP_ACT_LOG` to see what's being blocked

### Application Crashes

If an application crashes immediately:

1. The profile may be too restrictive
2. Add the missing syscalls to your whitelist
3. Use `dmesg` to see kernel messages about blocked syscalls

### Profile Not Being Applied

1. Verify the path is correct and accessible to Docker
2. Check Docker daemon has seccomp support enabled
3. Ensure the profile is valid JSON

## Best Practices

1. **Start with the default profile**: Docker's default seccomp profile is a good starting point
2. **Use whitelist for production**: Whitelist profiles are more secure than blacklist
3. **Profile in staging first**: Test your profile in a staging environment before production
4. **Keep profiles minimal**: Only allow syscalls that are absolutely necessary
5. **Document your profiles**: Keep track of why each syscall is allowed
6. **Review regularly**: Re-profile applications after updates to catch new syscall requirements

## References

- [Docker Seccomp Documentation](https://docs.docker.com/engine/security/seccomp/)
- [Default Seccomp Profile](https://github.com/moby/moby/blob/master/profiles/seccomp/default.json)
- [Seccomp-bpf Technical Discussion](https://sysdig.com/blog/selinux-seccomp-falco-technical-discussion/)
