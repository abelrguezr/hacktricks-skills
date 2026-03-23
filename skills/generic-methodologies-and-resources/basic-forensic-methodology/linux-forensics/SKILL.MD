---
name: linux-forensics
description: Perform Linux digital forensics investigations. Use this skill whenever the user needs to investigate a Linux system for security incidents, malware, unauthorized access, or suspicious activity. This includes gathering system information, analyzing logs, checking for persistence mechanisms, examining file systems, recovering deleted files, and documenting findings. Trigger on requests involving Linux forensics, incident response, malware investigation, system compromise analysis, or security auditing of Linux systems.
---

# Linux Forensics Investigation

A systematic approach to investigating Linux systems for security incidents, malware, and unauthorized access.

## Investigation Workflow

Follow this sequence to ensure comprehensive coverage:

1. **Preserve evidence** - Set up clean environment, avoid modifying the target
2. **Gather initial information** - System state, processes, network connections
3. **Capture memory** (if live) - Use LiME before shutdown
4. **Create disk image** - Forensic copy with hash verification
5. **Analyze artifacts** - Logs, autostart locations, user accounts, file system
6. **Document findings** - Timeline, suspicious indicators, evidence chain

---

## 1. Initial Information Gathering

### Set Up Clean Environment

Before touching the target system, prepare a trusted environment:

```bash
# Mount USB with known-good binaries
export PATH=/mnt/usb/bin:/mnt/usb/sbin
export LD_LIBRARY_PATH=/mnt/usb/lib:/mnt/usb/lib64
```

### Collect System State

Run these commands to capture the current system state:

```bash
# Time and OS information
date
uname -a

# Network state
ifconfig -a || ip a
netstat -anp
netstat -rn; route

# Running processes
ps -ef
lsof -V

# System resources
df; mount
free

# User activity
w
last -Faiwx

# Kernel modules
lsmod

# User accounts
cat /etc/passwd
cat /etc/shadow

# Recently modified files
find / -type f -mtime -1 -print 2>/dev/null
```

### Red Flags to Watch For

- **Root processes with high PIDs** - Normal root processes have low PIDs
- **Users without shells in /etc/passwd** - Check for password hashes in /etc/shadow
- **Unexpected network connections** - Especially outbound to unknown IPs
- **Modified system binaries** - Compare against known-good versions

---

## 2. Memory Acquisition (Live Systems)

### Using LiME

LiME (Linux Memory Extractor) captures volatile memory:

```bash
# Install (if identical kernel available)
apt-get install lime-forensics-dkms

# Or compile from source with matching kernel headers
make -C /lib/modules/$(uname -r)/build M=$PWD
sudo insmod lime.ko "path=/path/to/mem_dump.bin format=lime"
```

**Important:** Do not install anything on the victim machine if possible. Use a USB with pre-compiled LiME matching the kernel version.

### LiME Formats

- **raw** - Concatenated segments
- **padded** - Raw with zero-padding
- **lime** - Recommended, includes metadata

### Network Transfer

```bash
# Send dump over network instead of local storage
sudo insmod lime.ko "path=tcp:4444 format=lime"
```

---

## 3. Disk Imaging

### Shutdown Strategy

- **Normal shutdown** - Allows filesystem sync but malware may destroy evidence
- **Pull the plug** - Risk of data loss but prevents malware cleanup

**If malware suspected:** Run `sync` then power off immediately.

### Create Forensic Image

```bash
# Basic raw copy
dd if=/dev/sdX of=/path/to/image.img bs=512

# With hash verification (recommended)
dcfldd if=/dev/sdX of=/path/to/image.img bs=512 hash=sha256 hashwindow=1M hashlog=/path/to/hashes.log
```

**Always mount images as read-only** to prevent modification.

---

## 4. Disk Image Analysis

### Identify Image Type

```bash
# Check file type
file disk.img

# Check image format
img_stat -t evidence.img
img_stat -i list  # List supported formats
```

### Filesystem Information

```bash
# Get filesystem metadata
fsstat -i raw -f ext4 disk.img

# List directory contents
fls -i raw -f ext4 disk.img
fls -i raw -f ext4 disk.img <inode_number>

# Extract file content
icat -i raw -f ext4 disk.img <inode_number>
```

---

## 5. Malware Detection

### System File Integrity

```bash
# RedHat-based systems
rpm -Va

# Debian-based systems
dpkg --verify
apt-get install debsums
debsums | grep -v "OK$"
```

### Search Installed Programs

```bash
# Debian package database
cat /var/lib/dpkg/status | grep -E "Package:|Status:"
cat /var/log/dpkg.log | grep installed

# RedHat RPM database
rpm -qa --root=/mntpath/var/lib/rpm

# Find executables not in package databases
find /sbin/ -exec dpkg -S {} \; | grep "no path found"
find /sbin/ -exec rpm -qf {} \; | grep "is not"

# Find all executable files
find / -type f -executable 2>/dev/null | grep <pattern>
```

### Check Common Installation Directories

```bash
ls /usr/local /opt /usr/sbin /usr/bin /bin /sbin
```

---

## 6. Recover Deleted Binaries

If a process was executed from a deleted file:

```bash
# Navigate to process directory
cd /proc/<PID>/

# Get memory address from maps
head -1 maps

# Extract from memory
dd if=mem bs=1 skip=<address> count=<size> of=/path/to/recovered
```

---

## 7. Autostart and Persistence Locations

### Scheduled Tasks

```bash
# Cron and anacron
cat /var/spool/cron/crontabs/*
cat /var/spool/cron/atjobs
cat /var/spool/anacron
cat /etc/cron*
cat /etc/at*
cat /etc/anacrontab
cat /etc/incron.d/*
cat /var/spool/incron/*

# Check 0anacron stubs for modifications
for d in /etc/cron.*; do [ -f "$d/0anacron" ] && stat -c '%n %y %s' "$d/0anacron"; done

# Search for suspicious commands in cron
find /etc/cron.* -type f -exec grep -l -E 'curl|wget|/bin/sh|python|bash -c' {} \;
```

### SSH and Account Backdoors

```bash
# Check for root login enabled
grep -E '^\s*PermitRootLogin' /etc/ssh/sshd_config

# System accounts with interactive shells
awk -F: '($7 ~ /bin\/(sh|bash|zsh)/ && $1 ~ /^(games|lp|sync|shutdown|halt|mail|operator)$/) {print}' /etc/passwd

# Check authorized keys
cat ~/.ssh/authorized_keys
cat ~/.ssh/known_hosts
```

### Cloud C2 Indicators

```bash
# Cloudflare tunnel processes
ps aux | grep -E '[c]loudflared|trycloudflare'
systemctl list-units | grep -i cloudflared
```

### Service Autostart Locations

Check these directories for malicious services:

- `/etc/inittab`
- `/etc/rc.d/` and `/etc/rc.boot/`
- `/etc/init.d/`
- `/etc/inetd.conf` and `/etc/xinetd/`
- `/etc/systemd/system/`
- `/etc/systemd/system/multi-user.target.wants/`
- `/usr/local/etc/rc.d/`
- `~/.config/autostart/`
- `/lib/systemd/system/`

### Kernel Modules

```bash
# Loaded modules
lsmod

# Module directories
ls /lib/modules/$(uname -r)
cat /etc/modprobe.d/*
cat /etc/modprobe*
cat /etc/modprobe.conf
```

### User Login Scripts

```bash
# System-wide
ls /etc/profile.d/
cat /etc/profile
cat /etc/bash.bashrc
cat /etc/rc.local

# User-specific
cat ~/.bashrc
cat ~/.bash_profile
cat ~/.profile
ls ~/.config/autostart/
```

---

## 8. Log Analysis

### System Logs

```bash
# Main system logs (Debian)
cat /var/log/syslog
cat /var/log/auth.log

# Main system logs (RedHat)
cat /var/log/messages
cat /var/log/secure

# Authentication events
grep -iE "session opened for|accepted password|new session|not in sudoers" /var/log/auth.log

# Boot, kernel, and service logs
cat /var/log/boot.log
cat /var/log/kern.log
cat /var/log/dmesg
cat /var/log/daemon.log
cat /var/log/cron

# Failed logins
cat /var/log/faillog
cat /var/log/btmp

# Web and database logs
cat /var/log/httpd/*
cat /var/log/mysqld.log
cat /var/log/xferlog
```

### User History Files

```bash
# Shell history
cat ~/.bash_history
cat ~/.zsh_history
ls ~/.zsh_sessions/

# Application history
cat ~/.python_history
cat ~/.mysql_history
cat ~/.viminfo
cat ~/.lesshst
cat ~/.ftp_history
cat ~/.sftp_history

# Browser history
ls ~/.mozilla/firefox/
ls ~/.config/google-chrome/

# Git history
cat ~/.gitconfig
ls .git/logs/
```

### USB Device History

```bash
# Install usbrip
pip3 install usbrip
usbrip ids download

# Get USB history
usbrip events history

# Search by vendor/product ID
usbrip events history --pid 0002 --vid 0e0f
usbrip ids search --pid 0002 --vid 0e0f
```

### Privilege Escalation Indicators

```bash
# Sudo configuration
cat /etc/sudoers
ls /etc/sudoers.d/

# Group memberships
cat /etc/groups
cat /etc/passwd

# Look for accounts without passwords or weak hashes
cat /etc/shadow | grep -E '^([^:]+):$|^[^:]+:!!|^([^:]+):!'
```

---

## 9. File System Analysis

### Timeline and Anti-Forensics Detection

```bash
# Find setuid root files
find / -user root -perm -04000 -print 2>/dev/null

# Recent files in system directories
ls -laR --sort=time /bin
ls -laR --sort=time /sbin

# Sort by inode (timestamps can be faked, inodes cannot)
ls -lai /bin | sort -n

# Find hidden files with unusual names
find / -name ".. *" -o -name "..^G" 2>/dev/null

# Check /dev for unusual files
ls -la /dev/

# Deleted files still open
lsof +L1
lsof | grep '(deleted)'

# Inode pressure check
df -i
```

### Inode Analysis

```bash
# Find all names pointing to one inode
find / -xdev -inum <inode_number> 2>/dev/null

# Inspect inode metadata (EXT filesystem)
sudo debugfs -R "stat <inode_number>" /dev/sdX
```

**Key inode fields:**
- **Links**: 0 means no directory entry references this inode
- **dtime**: Deletion timestamp
- **ctime/mtime**: Metadata and content modification times

### Filesystem Version Comparison

```bash
# Find new files
git diff --no-index --diff-filter=A path/to/old/ path/to/new/

# Find modified files
git diff --no-index --diff-filter=M path/to/old/ path/to/new/ | grep -E '^\+' | grep -v "Installed-Time"

# Find deleted files
git diff --no-index --diff-filter=D path/to/old/ path/to/new/
```

---

## 10. Documentation and Reporting

### Evidence Chain

Document:
1. **Case information** - Date, time, investigator, case number
2. **System information** - Hostname, IP, OS version, kernel
3. **Acquisition details** - Tools used, hash values, timestamps
4. **Findings** - Suspicious files, processes, network connections
5. **Timeline** - Chronological sequence of events
6. **Recommendations** - Remediation steps

### Hash Verification

Always verify evidence integrity:

```bash
# Calculate hashes
sha256sum /path/to/evidence
md5sum /path/to/evidence

# Verify against known values
sha256sum -c hashes.txt
```

---

## Quick Reference Scripts

Use the bundled scripts for common tasks:

- `scripts/gather_system_info.sh` - Collect initial system state
- `scripts/check_autostart.sh` - Scan all persistence locations
- `scripts/analyze_logs.sh` - Extract key log entries
- `scripts/find_suspicious.sh` - Identify potential malware indicators

---

## Safety Reminders

- **Never modify the target system** - Work from forensic images
- **Verify tool integrity** - Use known-good binaries from USB
- **Document everything** - Maintain chain of custody
- **Preserve timestamps** - Note when each action was performed
- **Verify hashes** - Ensure evidence integrity throughout investigation
