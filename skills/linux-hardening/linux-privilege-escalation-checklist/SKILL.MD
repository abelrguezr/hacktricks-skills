---
name: linux-privilege-escalation-checklist
description: Use this skill whenever you need to enumerate Linux privilege escalation vectors, check for local privilege escalation opportunities, or systematically assess a Linux system for privilege escalation paths. Trigger this when you have shell access to a Linux system and want to find ways to escalate from a low-privilege user to root. Also use this when analyzing a Linux system for security assessments, penetration testing, or when you've gained initial access and need to find privilege escalation vectors.
---

# Linux Privilege Escalation Checklist

A systematic approach to finding privilege escalation vectors on Linux systems.

## Quick Start

1. **Run LinPEAS first** - The best automated tool for Linux privilege escalation enumeration:
   ```bash
   curl -L https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/raw/master/linPEAS/linPEAS.sh | sh
   ```

2. **Follow this checklist** to manually verify findings and catch what automated tools might miss.

---

## System Information

Start here to understand the target system.

### OS and Environment
- Get OS information: `uname -a`, `cat /etc/os-release`
- Check PATH for writable folders: `echo $PATH | tr ':' '\n' | while read dir; do ls -ld "$dir" 2>/dev/null | grep -q 'w' && echo "WRITABLE: $dir"; done`
- Check environment variables for sensitive data: `env | grep -iE '(pass|key|secret|token|api|auth)'
- Check kernel version for known exploits (DirtyCow, etc.)
- Check sudo version for vulnerabilities: `sudo -V`
- Check dmesg for signature verification failures: `dmesg | grep -i 'signature\|verify'`

### System Defenses
- Check SELinux/AppArmor status
- Check for running security tools (ESET, ClamAV, etc.)
- Check auditd status

---

## Drives and Mounts

- List mounted drives: `mount`, `df -h`
- Check for unmounted drives: `lsblk`
- Check fstab for credentials: `cat /etc/fstab`
- Look for NFS mounts with insecure options

---

## Installed Software

- Check for useful software: `which python python3 perl ruby gcc make wget curl`
- Check for vulnerable software versions:
  ```bash
  dpkg -l | grep -iE '(apache|nginx|mysql|postgresql|php)'  # Debian
  rpm -qa | grep -iE '(apache|nginx|mysql|postgresql|php)'  # RHEL
  ```

---

## Processes

- List all processes: `ps aux`, `ps -ef`
- Check for unknown software running
- Identify processes running with elevated privileges
- Check if you can modify any running process binary
- Monitor for frequently running processes: `watch -n 1 'ps aux'`
- Check process memory for credentials: `cat /proc/<PID>/environ`

---

## Scheduled Jobs (Cron)

- Check user cron: `crontab -l`
- Check system cron: `ls -la /etc/cron*`, `cat /etc/crontab`
- Look for:
  - PATH modifications in cron jobs
  - Wildcard usage in scripts (wildcard injection)
  - Modifiable scripts being executed
  - Scripts in writable folders
  - Frequently running jobs (every 1-5 minutes)

---

## Services (Systemd)

- List services: `systemctl list-units --type=service --all`
- Check for writable .service files: `find /etc/systemd -name '*.service' -perm -002`
- Check for writable binaries executed by services
- Check systemd PATH for writable folders
- Check for writable drop-in configs: `find /etc/systemd/system -name '*.d' -type d`

---

## Timers and Sockets

- List timers: `systemctl list-timers`
- Check for writable timers
- List sockets: `systemctl list-units --type=socket`
- Check for writable .socket files
- Try to communicate with open sockets

---

## Network

- Enumerate network: `ip addr`, `ip route`, `netstat -tulpn`
- Check for open ports you couldn't access before
- Try to sniff traffic: `tcpdump -i any` (may require privileges)
- Check for listening services on localhost

---

## Users and Groups

- List users: `cat /etc/passwd`, `id`
- List groups: `cat /etc/group`
- Check for high UID values (potential vulnerabilities)
- Check group memberships for privilege escalation:
  - `sudo`, `wheel`, `docker`, `lxd`, `libvirt`, `vmware`
- Check clipboard data: `xclip -o`, `xsel -o`
- Check password policy: `cat /etc/login.defs`
- Try known passwords against all users

---

## SUDO and SUID Commands

### Sudo Enumeration
- Check sudo permissions: `sudo -l`
- If `sudoedit` is allowed, check for CVE-2023-22809:
  ```bash
  SUDO_EDITOR="vim -- /etc/sudoers" sudoedit /etc/hosts
  ```
- Check sudo version: `sudo -V` (vulnerable if < 1.9.12p2)
- Check for sudo tokens: `ls -la /var/run/sudo/`
- Check sudoers files: `cat /etc/sudoers`, `ls -la /etc/sudoers.d/`

### SUID Enumeration
- Find SUID binaries: `find / -perm -4000 -type f 2>/dev/null`
- Check GTFOBins for exploitable SUID binaries
- Check for SUID binaries without full paths
- Check for LD_PRELOAD vulnerabilities
- Check for missing .so libraries in writable folders

### DOAS (OpenBSD)
- Check for doas: `which doas`, `doas -l`

---

## Capabilities and ACLs

- Check for unexpected capabilities: `getcap -r / 2>/dev/null`
- Check for unexpected ACLs: `getfacl -R / 2>/dev/null | grep -E '^(user:|group:)'`

---

## Open Shell Sessions

- Check for screen sessions: `screen -ls`
- Check for tmux sessions: `tmux list-sessions`
- Try to attach to unowned sessions

---

## SSH

- Check SSH config: `cat ~/.ssh/config`, `cat /etc/ssh/sshd_config`
- Check for Debian OpenSSL PRNG vulnerability (CVE-2008-0166)
- Look for SSH keys: `find / -name 'id_rsa*' -o -name 'id_dsa*' 2>/dev/null`
- Check authorized_keys: `cat ~/.ssh/authorized_keys`

---

## Interesting Files

### Profile and System Files
- Check profile files: `cat ~/.bashrc`, `cat ~/.profile`, `cat /etc/profile`
- Check passwd/shadow: `cat /etc/passwd`, `cat /etc/shadow`
- Check for recently modified files: `find / -mtime -1 -type f 2>/dev/null`

### Sensitive Locations
- Check common folders: `/var/www`, `/opt`, `/home`, `/tmp`
- Check for hidden files: `find / -name '.*' -type f 2>/dev/null`
- Check for SQLite databases: `find / -name '*.sqlite*' -o -name '*.db' 2>/dev/null`
- Check for backup files: `find / -name '*~' -o -name '*.bak' -o -name '*.old' 2>/dev/null`
- Check for web files with passwords: `grep -r 'password' /var/www 2>/dev/null`

### Credential Tools
- Run LinPEAS for comprehensive credential search
- Run LaZagne: `lazagne all`

---

## Writable Files

### Critical Files
- Check for writable Python libraries: `find /usr/lib/python* -perm -002 2>/dev/null`
- Check for writable log files (Logtotten exploit)
- Check /etc/sysconfig/network-scripts/ (CentOS/RHEL)
- Check init files: `/etc/init.d/`, `/etc/rc.d/`, `/etc/init/`

### Configuration Files
- Check for writable .ini, .conf files in PATH
- Check /etc/ld.so.conf.d/ for library injection

---

## Other Tricks

### NFS
- Check for NFS mounts: `mount | grep nfs`
- Check /etc/exports on NFS server
- Try to escalate via NFS with no_root_squash

### Restricted Shell Escape
- Try shell escapes: `vim`, `less`, `more`, `man`, `find`, `perl`, `python`, `ruby`
- Check shell type: `echo $SHELL`, `ps -p $$`

---

## Quick Reference Commands

```bash
# One-liner for common checks
whoami; id; sudo -l; find / -perm -4000 -type f 2>/dev/null; getcap -r / 2>/dev/null

# Check for common misconfigurations
ls -la /etc/sudoers.d/; cat /etc/crontab; crontab -l; systemctl list-units --type=service

# Find credentials
grep -r 'password' /home 2>/dev/null; find / -name '*.pem' 2>/dev/null; find / -name 'id_rsa' 2>/dev/null
```

---

## When to Use This Skill

Use this skill when:
- You have shell access to a Linux system and want to escalate privileges
- You're conducting a security assessment or penetration test
- You've gained initial access and need to find privilege escalation vectors
- You need to systematically enumerate a Linux system for security issues
- You want to verify findings from automated tools like LinPEAS
- You're analyzing a compromised system for privilege escalation paths

---

## References

- [LinPEAS](https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/tree/master/linPEAS)
- [GTFOBins](https://gtfobins.github.io)
- [Sudo advisory: sudoedit arbitrary file edit](https://www.sudo.ws/security/advisories/sudoedit_any/)
- [Oracle Linux docs: systemd drop-in configuration](https://docs.oracle.com/en/operating-systems/oracle-linux/8/systemd/ModifyingsystemdConfigurationFiles.html)
- [HackTricks Linux Privilege Escalation](https://book.hacktricks.xyz/linux-hardening/privilege-escalation)
