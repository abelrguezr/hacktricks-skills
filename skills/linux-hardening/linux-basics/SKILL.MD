---
name: linux-basics
description: How to work with Linux fundamentals including file permissions, user management, process control, and system navigation. Use this skill whenever the user needs help with Linux commands, file operations, permissions, users/groups, processes, or basic system administration tasks. Trigger for any Linux-related questions about navigating directories, managing files, understanding permissions, running commands, or troubleshooting basic system issues.
---

# Linux Basics

This skill covers fundamental Linux operations that every user should know. Use it for file management, permissions, user administration, process control, and system navigation.

## When to Use This Skill

Use this skill when the user:
- Needs help with Linux commands and their syntax
- Wants to understand file permissions and how to modify them
- Is working with users, groups, or sudo privileges
- Needs to manage processes (start, stop, monitor)
- Is navigating the filesystem or working with directories
- Wants to understand basic system administration concepts
- Is troubleshooting common Linux issues

## File System Navigation

### Basic Commands

```bash
pwd              # Print working directory - shows your current location
ls               # List directory contents
ls -la           # List all files including hidden, with details
ls -lh           # Human-readable file sizes
cd /path         # Change directory
cd ..            # Go up one directory
cd ~             # Go to home directory
cd -             # Go to previous directory
```

### Understanding Paths

- **Absolute path**: Starts from root `/` (e.g., `/home/user/documents`)
- **Relative path**: From current directory (e.g., `./documents` or `../other`)
- **Special paths**:
  - `.` = current directory
  - `..` = parent directory
  - `~` = home directory
  - `~/` = home directory with trailing slash

### File Operations

```bash
mkdir directory_name      # Create a directory
mkdir -p a/b/c           # Create nested directories
touch filename           # Create an empty file or update timestamp
rm filename              # Remove a file
rm -r directory          # Remove directory and contents
rm -rf directory         # Force remove without confirmation (DANGEROUS)
cp source dest           # Copy a file
cp -r source dest        # Copy a directory recursively
mv source dest           # Move or rename a file
ln -s target link        # Create a symbolic link
```

## File Permissions

### Understanding Permissions

Permissions are shown as 10 characters: `-rwxr-xr--`

```
Position: 0123456789
          │││││││││└─ Other (world) permissions
          │││││││└─── Group permissions
          │││││└───── User (owner) permissions
          │││└─────── Type (d=directory, -=file, l=link)
          │└───────── Setuid bit
          └────────── Setgid bit
```

Permission values:
- `r` = read (4)
- `w` = write (2)
- `x` = execute (1)
- `-` = no permission (0)

### Modifying Permissions

```bash
chmod u+x file          # Add execute for owner
chmod 755 file          # Owner: rwx, Group: rx, Other: rx
chmod 644 file          # Owner: rw, Group: r, Other: r
chmod g-w file          # Remove write from group
chmod a+r file          # Add read for all
chmod -R 755 dir/       # Apply recursively
```

### Ownership

```bash
chown user file         # Change owner
chown user:group file   # Change owner and group
chown -R user:group dir # Apply recursively
```

### Checking Permissions

```bash
ls -l filename          # Show detailed permissions
stat filename           # Show detailed file information
namei -l filename       # Show path with permissions
```

## User and Group Management

### Viewing Users and Groups

```bash
whoami                  # Current user
id                      # Current user and groups
who                     # Who is logged in
w                       # Who is logged in and what they're doing
last                    # Login history
cat /etc/passwd         # All users
cat /etc/group          # All groups
groups username         # Groups for a user
id username             # User and group info
```

### User Administration (requires sudo)

```bash
sudo useradd username           # Create a user
sudo usermod -aG group username # Add user to group
sudo usermod -L username        # Lock user account
sudo usermod -U username        # Unlock user account
sudo passwd username            # Set/change password
sudo userdel username           # Delete user
sudo userdel -r username        # Delete user and home directory
```

### Group Administration (requires sudo)

```bash
sudo groupadd groupname         # Create a group
sudo groupmod -n newname old    # Rename group
sudo groupdel groupname         # Delete group
```

### Sudo Privileges

```bash
sudo command              # Run command as root
sudo -i                   # Start root shell
sudo -u user command      # Run as specific user
sudo -l                   # List your sudo privileges
```

## Process Management

### Viewing Processes

```bash
ps aux                    # All running processes
ps -ef                    # All processes in full format
ps -u username            # Processes for a user
pgrep -l pattern          # Find processes by name
pidof program             # Get PID of a program
top                       # Interactive process viewer
htop                      # Better interactive viewer (if installed)
```

### Process Control

```bash
kill PID                  # Send SIGTERM to process
kill -9 PID               # Force kill (SIGKILL)
killall program           # Kill all processes by name
pkill pattern             # Kill by pattern
fg                        # Bring background job to foreground
bg                        # Resume job in background
jobs                      # List background jobs
Ctrl+Z                   # Suspend current process
Ctrl+C                   # Terminate current process
```

### Background Execution

```bash
command &                 # Run in background
nohup command &           # Run in background, ignore hangups
screen -S name            # Create named screen session
screen -r name            # Resume screen session
```

## System Information

### Hardware and System

```bash
uname -a                  # System information
hostname                  # System hostname
uptime                    # System uptime and load
free -h                   # Memory usage (human readable)
df -h                     # Disk space (human readable)
du -sh directory          # Directory size
lscpu                     # CPU information
lsblk                     # Block devices
```

### Network

```bash
ip addr                   # IP addresses (modern)
ifconfig                  # IP addresses (legacy)
netstat -tulpn            # Listening ports
ss -tulpn                 # Listening ports (modern)
ping hostname             # Test connectivity
traceroute hostname       # Trace network path
nslookup domain           # DNS lookup
dig domain                # DNS query (if installed)
```

### Logs

```bash
journalctl -xe            # System logs (systemd)
tail -f /var/log/syslog   # Follow system log
dmesg                     # Kernel messages
last                      # Login history
```

## Common Patterns

### Finding Files

```bash
find /path -name "*.txt"           # Find files by name
find /path -type f -size +100M     # Find large files
find /path -mtime -7               # Files modified in last 7 days
find /path -user username          # Files owned by user
locate filename                    # Fast file search (requires updatedb)
```

### Text Processing

```bash
cat file                    # Display file contents
head -n 20 file             # First 20 lines
tail -n 20 file             # Last 20 lines
tail -f file                # Follow file (like a log viewer)
grep "pattern" file         # Search for pattern
grep -r "pattern" dir/      # Recursive search
grep -i "pattern" file      # Case-insensitive search
wc -l file                  # Count lines
```

### Compression

```bash
tar -czf archive.tar.gz dir/     # Create gzip archive
tar -xzf archive.tar.gz          # Extract gzip archive
tar -cjf archive.tar.bz2 dir/    # Create bzip2 archive
tar -xjf archive.tar.bz2         # Extract bzip2 archive
zip -r archive.zip dir/          # Create zip archive
unzip archive.zip                # Extract zip archive
```

## Safety Tips

1. **Always check before deleting**: Use `ls` before `rm -rf`
2. **Test commands**: Run without `-r` or `-f` flags first
3. **Use `sudo` carefully**: Understand what you're running as root
4. **Backup important data**: Before making system changes
5. **Check permissions**: Ensure you have the right to modify files
6. **Read man pages**: `man command` for detailed documentation

## Quick Reference

| Task | Command |
|------|--------|
| List files | `ls -la` |
| Change directory | `cd path` |
| Copy file | `cp source dest` |
| Move file | `mv source dest` |
| Delete file | `rm file` |
| Create directory | `mkdir dir` |
| View file | `cat file` or `less file` |
| Edit file | `nano file` or `vim file` |
| Search text | `grep "pattern" file` |
| Find file | `find /path -name "*"` |
| Check permissions | `ls -l` |
| Change permissions | `chmod 755 file` |
| Change owner | `chown user:group file` |
| View processes | `ps aux` |
| Kill process | `kill PID` |
| Check disk space | `df -h` |
| Check memory | `free -h` |
| View logs | `journalctl -xe` |
