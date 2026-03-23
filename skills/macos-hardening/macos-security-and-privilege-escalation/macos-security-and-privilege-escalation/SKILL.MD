---
name: macos-security-hardening
description: Guide for macOS security assessment, privilege escalation, and hardening. Use this skill whenever the user mentions macOS security, privilege escalation, TCC, SIP, file permissions, security auditing, or any macOS security-related task. This skill covers security architecture, attack surface analysis, TCC/SIP bypasses, and traditional privilege escalation techniques.
---

# macOS Security & Privilege Escalation

A comprehensive guide for assessing and understanding macOS security mechanisms, privilege escalation vectors, and hardening techniques.

## Quick Start

When assessing a macOS system, follow this workflow:

1. **Gather system information** - Version, architecture, users
2. **Check security protections** - SIP, TCC status
3. **Enumerate attack surface** - File permissions, services, installed apps
4. **Identify privilege escalation vectors** - SUID binaries, writable files, TCC abuse
5. **Document findings** - Create a structured report

## macOS Security Architecture

### Core Concepts

macOS security relies on several layered protections:

- **SIP (System Integrity Protection)**: Protects system files and processes from modification, even by root
- **TCC (Transparency, Consent, and Control)**: Controls app access to sensitive data (microphone, camera, files, etc.)
- **Code Signing**: Apps must be signed to run; unsigned apps are blocked or require user approval
- **Gatekeeper**: Verifies app signatures and quarantine status
- **AMFI (Apple Mobile File Integrity)**: Enforces code signing at the kernel level

### Check SIP Status

```bash
# Check if SIP is enabled
csrutil status

# From within macOS (requires reboot to change)
# If disabled, you can modify system files
```

### Check TCC Database

```bash
# List TCC database entries
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access;"

# Check specific app permissions
sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT * FROM access WHERE client LIKE '%app_name%';"
```

## Attack Surface Enumeration

### File Permission Vulnerabilities

Root-owned processes writing to user-controllable files create privilege escalation opportunities:

```bash
# Find world-writable files in system directories
find /usr /System /Library -perm -0002 -type f 2>/dev/null

# Find files owned by root but writable by group
find /usr /System /Library -user root -group wheel -perm -0020 -type f 2>/dev/null

# Find SUID/SGID binaries
find / -perm -4000 -type f 2>/dev/null  # SUID
find / -perm -2000 -type f 2>/dev/null  # SGID

# Check for writable directories in system paths
find /usr /System /Library -perm -0002 -type d 2>/dev/null
```

### Check for Vulnerable Installers

```bash
# List installed packages
pkgutil --pkgs

# Check package receipts for vulnerabilities
pkgutil --pkg-info <package_id>

# Look for .pkg files that might be reinstalled
find / -name "*.pkg" -type f 2>/dev/null
```

### File Extension & URL Scheme Handlers

```bash
# Check registered file type handlers
defaults read com.apple.LaunchServices/com.apple.launchservices.secure

# Check URL scheme handlers
mdls -name kMDItemCFBundleIdentifier -name kMDItemContentType /Applications/*.app

# List all registered apps
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump
```

## TCC Privilege Escalation

### Understanding TCC

TCC controls access to:
- Microphone, camera, screen recording
- Accessibility features
- File system areas (Documents, Downloads, etc.)
- Contacts, calendar, reminders
- System preferences

### TCC Bypass Techniques

1. **Inherit from privileged parent**: Child processes inherit TCC permissions from parent
2. **Abuse signed apps**: Use entitlements from signed applications
3. **Database manipulation**: Modify TCC.db directly (requires SIP disabled)
4. **Accessibility API abuse**: Use accessibility permissions to control other apps

### Check TCC Permissions

```bash
# List all TCC permissions
tccutil list

# Check specific permission categories
tccutil reset All <app_bundle_id>
```

## SIP Bypass Considerations

### When SIP is Disabled

If SIP is disabled, you can:
- Modify system binaries
- Load unsigned kernel extensions
- Access protected system files
- Modify TCC database directly

### Common SIP Bypass Vectors

Historical bypasses have exploited:
- Kernel vulnerabilities
- Code signing bypasses
- System call injection
- Memory corruption in system processes

**Note**: Modern macOS versions have significantly hardened against these attacks. Always check for the latest CVEs and patches.

## Traditional Privilege Escalation

### SUID/SGID Binary Abuse

```bash
# Find SUID binaries and check for known exploits
find / -perm -4000 -type f 2>/dev/null | while read bin; do
    echo "=== $bin ==="
    which $bin 2>/dev/null || echo "Not in PATH"
done
```

### Cron Jobs & LaunchDaemons

```bash
# Check user cron jobs
cat /etc/crontab
cat /etc/cron.d/*
ls -la /etc/cron.*

# Check LaunchDaemons (system services)
ls -la /Library/LaunchDaemons/
ls -la /System/Library/LaunchDaemons/

# Check LaunchAgents (user services)
ls -la ~/Library/LaunchAgents/
ls -la /Library/LaunchAgents/
```

### Writable System Files

```bash
# Find files writable by current user in system directories
find /usr /System /Library -writable -type f 2>/dev/null

# Check for PATH injection opportunities
find /usr/local/bin /usr/bin /bin -writable -type d 2>/dev/null
```

## Security Hardening Recommendations

### Disable Unnecessary Services

```bash
# List all running services
launchctl list

# Disable a service
launchctl bootout system/<service_label>
```

### Enable Full Disk Encryption

```bash
# Check FileVault status
fdesetup status

# Enable FileVault
sudo fdesetup enable
```

### Configure Firewall

```bash
# Check firewall status
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

### Audit User Accounts

```bash
# List all users
df -H

# Check for accounts with sudo privileges
grep -i sudo /etc/sudoers
grep -i sudo /etc/sudoers.d/*

# Check last login times
last
```

## Compliance & Standards

### NIST macOS Security Baseline

Reference: https://github.com/usnistgov/macos_security

Key controls:
- Password policies
- Account management
- Audit logging
- File integrity monitoring
- Network security

### CIS Benchmarks

Follow CIS macOS Benchmark for comprehensive hardening guidance.

## Practical Assessment Workflow

### Step 1: Initial Reconnaissance

```bash
# System information
sw_vers
uname -a

# Current user and groups
whoami
groups
id

# Check if root
sudo -l
```

### Step 2: Security Status Check

```bash
# SIP status (requires reboot to check properly)
csrutil status

# TCC permissions
tccutil list

# FileVault
fdesetup status

# Firewall
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
```

### Step 3: Attack Surface Scan

```bash
# Run the enumeration commands from above
# Document all findings
```

### Step 4: Exploitation Testing

```bash
# Test each identified vector
# Document success/failure
# Note any limitations
```

## Reporting Template

```markdown
# macOS Security Assessment Report

## System Information
- macOS Version: 
- Architecture: 
- Current User: 

## Security Protections
- SIP: [Enabled/Disabled]
- TCC: [Status]
- FileVault: [Enabled/Disabled]
- Firewall: [Enabled/Disabled]

## Findings

### Critical
- [List critical vulnerabilities]

### High
- [List high-severity issues]

### Medium
- [List medium-severity issues]

### Low
- [List low-severity issues]

## Recommendations
- [Prioritized remediation steps]
```

## References

- [NIST macOS Security](https://github.com/usnistgov/macos_security)
- [Apple Open Source](https://opensource.apple.com/)
- [OS X Incident Response](https://www.amazon.com/OS-Incident-Response-Scripting-Analysis-ebook/dp/B01FHOHHVS)
- [TAOMM macOS Analysis](https://taomm.org/vol1/analysis.html)

## Important Notes

1. **Legal Authorization**: Only perform security assessments on systems you own or have explicit authorization to test.

2. **Backup First**: Always backup systems before making security changes.

3. **Test in Isolation**: Test privilege escalation techniques in isolated environments first.

4. **Stay Updated**: macOS security evolves rapidly. Check for the latest CVEs and patches.

5. **Documentation**: Document all findings and changes for audit purposes.
