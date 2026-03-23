---
name: macos-kernel-vulnerability-assessment
description: Assess macOS kernel security posture, check for known vulnerabilities (CVE-2022-46722, CVE-2024-23225, CVE-2024-23296, CVE-2023-41075, CVE-2024-44243), enumerate kernel extensions, verify SIP/Gatekeeper status, and recommend mitigations. Use this skill whenever the user mentions macOS security auditing, kernel vulnerability assessment, privilege escalation research, checking for unpatched CVEs, or needs to enumerate the kernel security state on macOS systems.
---

# macOS Kernel Vulnerability Assessment

A skill for security researchers and auditors to assess macOS kernel security posture, identify known vulnerabilities, and recommend mitigations.

## When to Use This Skill

Use this skill when:
- Auditing macOS systems for kernel-level vulnerabilities
- Checking if a system is vulnerable to known CVEs (2022-2025)
- Enumerating loaded kernel extensions and security features
- Researching privilege escalation paths on macOS
- Verifying SIP, Gatekeeper, and KASLR status
- Preparing for macOS penetration testing or red teaming

## Quick Assessment Workflow

### 1. Run the Enumeration Script

Start by running the built-in enumeration script to gather baseline security data:

```bash
./scripts/macos-kernel-enumerate.sh
```

This script collects:
- Kernel version and build information
- Loaded kernel extensions (kexts)
- SIP and Gatekeeper status
- KASLR configuration
- Patch level detection

### 2. Check for Known Vulnerabilities

Based on the kernel version, check against known CVEs:

| CVE | Affected Versions | Patched In | Impact |
|-----|------------------|------------|--------|
| CVE-2024-23225 | macOS < 14.4 / < 13.6.5 / < 12.7.4 | 14.4+ | Kernel R/W via XPC overflow |
| CVE-2024-23296 | macOS < 14.4 / < 13.6.5 / < 12.7.4 | 14.4+ | RTKit memory corruption |
| CVE-2023-41075 | Sonoma 14.0-14.1, Ventura 13.5-13.6 | 14.2+ | MIG type confusion, OOB write |
| CVE-2024-44243 | macOS < 15.2 | 15.2+ | SIP bypass via storagekitd |
| CVE-2022-46722 | Various | OTA update | Kernel compromise via updater |

### 3. Verify Patch Level

```bash
# Check macOS version
sw_vers

# Check kernel version (for Sonoma, 23E214+ is patched for CVE-2024-23225/23296)
sudo sysctl kern.osversion
```

### 4. Check Security Features

```bash
# System Integrity Protection (requires Recovery mode)
csrutil status

# Gatekeeper status
spctl --status

# KASLR status (should be 1)
sysctl kern.kaslr_enable
```

### 5. Enumerate Kernel Extensions

```bash
# Modern method (macOS 11+)
kmutil showloaded

# Legacy method (pre-Catalina)
kextstat | grep -v com.apple

# List non-Apple kexts (potential attack surface)
kmutil showloaded | grep -v com.apple
```

## Vulnerability-Specific Checks

### CVE-2024-23225 & CVE-2024-23296 (2024 0-days)

These vulnerabilities were actively exploited in the wild in March 2024.

**Detection:**
```bash
# Check if patched
sw_vers | grep ProductVersion  # Should be 14.4 or later

# Check kernel version
sudo sysctl kern.osversion  # Should be 23E214 or later for Sonoma
```

**Mitigation (if upgrade not possible):**
```bash
# Disable vulnerable services
launchctl disable system/com.apple.analyticsd
launchctl disable system/com.apple.rtcreportingd
```

### CVE-2023-41075 (MIG Type Confusion)

Affects Sonoma 14.0-14.1 and Ventura 13.5-13.6.

**Detection:**
```bash
# Check version
sw_vers
# Vulnerable if: Sonoma 14.0-14.1 OR Ventura 13.5-13.6
```

**Exploitation primitive:**
- Heap spray via `IOSurfaceFastSetValue`
- Malformed MIG message triggers type confusion
- Controlled OOB write into kernel heap

### CVE-2024-44243 (Sigma - SIP Bypass)

Allows loading unsigned kernel extensions via `storagekitd`.

**Detection:**
```bash
# Check for non-Apple kexts
kmutil showloaded | grep -v com.apple

# Monitor storagekitd activity
log stream --style syslog --predicate 'senderImagePath contains "storagekitd"'
```

**Remediation:**
- Update to macOS Sequoia 15.2 or later
- Monitor for suspicious kext loading

## Research Tools

### Fuzzing

- **Luftrauser** - Mach message fuzzer for MIG subsystems
  - Repository: `github.com/preshing/luftrauser`
  - Targets: `mach_msg()` handlers, IOKit user clients

- **oob-executor** - IPC out-of-bounds primitive generator
  - Used in CVE-2024-23225 research

### Static Analysis

```bash
# Inspect kext before loading (macOS 11+)
kmutil inspect -b io.kext.bundleID
```

## Common Attack Patterns

### 1. Kernel Heap Spraying

```c
// Example spray pattern
uint8_t spray[0x4000] = {0x41};
io_service_open_extended(...);  // Via IOSurfaceFastSetValue
```

### 2. MIG Message Manipulation

```c
// Malformed MIG message triggers type confusion
mach_msg(&msg.header, MACH_SEND_MSG|MACH_RCV_MSG, ...);
```

### 3. PAC Bypass

- CVE-2024-23296 disables Pointer Authentication Code (PAC)
- Combined with CVE-2024-23225 for full kernel R/W

## Remediation Priority

1. **Critical**: Update to latest macOS version
2. **High**: Disable vulnerable services if upgrade delayed
3. **Medium**: Monitor for suspicious kext loading
4. **Low**: Regular security audits and patch management

## Output Format

When presenting assessment results, use this structure:

```
# macOS Kernel Security Assessment

## System Information
- macOS Version: [version]
- Kernel Version: [version]
- Build: [build]

## Security Features
- SIP: [enabled/disabled]
- Gatekeeper: [enabled/disabled]
- KASLR: [enabled/disabled]

## Vulnerability Status
| CVE | Status | Risk |
|-----|--------|------|
| CVE-2024-23225 | [Patched/Vulnerable] | [Critical/None] |
| CVE-2024-23296 | [Patched/Vulnerable] | [Critical/None] |
| CVE-2023-41075 | [Patched/Vulnerable] | [High/None] |
| CVE-2024-44243 | [Patched/Vulnerable] | [High/None] |

## Loaded Kernel Extensions
[Non-Apple kexts list]

## Recommendations
1. [Action item]
2. [Action item]
```

## References

- Apple Security Updates: https://support.apple.com/en-us/120895
- Microsoft Security Blog (CVE-2024-44243): https://www.microsoft.com/en-us/security/blog/2025/01/13/analyzing-cve-2024-44243/
- Pwning OTA Research: https://jhftss.github.io/The-Nightmare-of-Apple-OTA-Update/
- CVE-2022-46722 PoC: https://github.com/jhftss/POC/tree/main/CVE-2022-46722
