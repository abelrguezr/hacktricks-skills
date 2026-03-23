---
name: windows-registry-privilege-escalation-checker
description: Check for writable Windows service registry keys that could enable privilege escalation via AppendData/AddSubdirectory permissions. Use this skill whenever the user needs to audit Windows registry permissions for services, investigate potential privilege escalation paths, or assess RpcEptMapper/Dnscache service vulnerabilities. Trigger on requests about Windows privilege escalation, registry permission auditing, service security assessment, or post-exploitation enumeration.
---

# Windows Registry Privilege Escalation Checker

A skill for identifying writable service registry keys that could enable privilege escalation through AppendData/AddSubdirectory (Create Subkey) permissions.

## Overview

This skill helps security professionals and penetration testers identify Windows registry permissions that could allow privilege escalation. The primary focus is on service registry keys where low-privileged users have `AppendData/AddSubdirectory` permissions, which can be exploited to load malicious DLLs through the Performance subkey mechanism.

## When to Use This Skill

Use this skill when:
- You need to audit Windows registry permissions for services
- You're investigating potential privilege escalation paths on a Windows system
- You want to assess RpcEptMapper or Dnscache service vulnerabilities
- You're performing post-exploitation enumeration
- You need to document registry-based security findings
- You're conducting authorized penetration testing or security assessments

## Prerequisites

- Local access to the Windows system being audited
- Appropriate authorization for security testing
- PowerShell 5.0 or later
- Administrative privileges for full registry access (though the skill can run with limited privileges to check what a low-privileged user can access)

## Core Concepts

### AppendData/AddSubdirectory Permission

This permission (also called `Create Subkey`) allows a user to create new subkeys under a registry key, even if they cannot modify existing values. This is the critical permission that enables the vulnerability.

### The Performance Subkey Attack Vector

Windows services can have a `Performance` subkey that enables performance monitoring. When this subkey exists with specific values, the service will load a DLL to collect performance data. If a low-privileged user can create this subkey, they can:

1. Create the `Performance` subkey under the service's registry path
2. Add values pointing to a malicious DLL
3. Trigger the service to load the DLL (e.g., via WMI queries)
4. Execute code as the service's context (often LOCAL SYSTEM)

### Target Services

The most commonly affected services are:

- **RpcEptMapper**: `HKLM\SYSTEM\CurrentControlSet\Services\RpcEptMapper`
- **Dnscache**: `HKLM\SYSTEM\CurrentControlSet\Services\Dnscache`

## Workflow

### Step 1: Check Registry Permissions

Run the permission checker script to identify writable service registry keys:

```powershell
.\check-service-registry-permissions.ps1
```

This script will:
- Enumerate service registry keys
- Check for AppendData/AddSubdirectory permissions
- Identify which users/groups have these permissions
- Report findings in a structured format

### Step 2: Analyze Findings

Review the output to identify:
- Services with writable registry keys
- The specific permissions granted
- Which users/groups are affected
- Whether the Performance subkey already exists

### Step 3: Validate Vulnerability (Authorized Testing Only)

If you have authorization to test:

1. Verify the service can be triggered to load performance data
2. Check if the Performance subkey can be created
3. Document the attack path
4. **Do not deploy malicious payloads in production environments**

### Step 4: Document and Remediate

Document findings and recommend remediation:
- Remove unnecessary permissions from service registry keys
- Apply principle of least privilege
- Monitor for unauthorized registry changes
- Keep systems updated (this vulnerability affects older Windows versions)

## Scripts

### check-service-registry-permissions.ps1

Located in `scripts/check-service-registry-permissions.ps1`, this script:

- Checks permissions on common vulnerable service registry keys
- Reports users/groups with AppendData/AddSubdirectory permissions
- Outputs findings in a readable format
- Can be run with or without administrative privileges

Usage:
```powershell
# Run with current user context
.\check-service-registry-permissions.ps1

# Run with specific service name
.\check-service-registry-permissions.ps1 -ServiceName "RpcEptMapper"

# Output to file
.\check-service-registry-permissions.ps1 -OutputFile "registry-audit-report.txt"
```

## Output Format

The skill produces structured output including:

```
=== Registry Permission Audit ===
Service: RpcEptMapper
Path: HKLM\SYSTEM\CurrentControlSet\Services\RpcEptMapper
Status: VULNERABLE

Permissions Found:
- User: CONTOSO\lowprivuser
  - AppendData/AddSubdirectory: YES
  - Create Subkey: YES
  - Full Control: NO

Recommendation: Remove AppendData/AddSubdirectory permission from low-privileged users
```

## Limitations

- Requires local access to the target system
- Some registry keys may require administrative privileges to enumerate
- This vulnerability primarily affects Windows 7 and Server 2008 R2
- Modern Windows versions have additional protections
- The skill identifies potential vulnerabilities but does not exploit them

## Security Considerations

**IMPORTANT**: This skill is for authorized security testing and assessment only.

- Only use on systems you own or have explicit authorization to test
- Do not deploy malicious payloads in production environments
- Document all findings and share with system administrators
- Follow responsible disclosure practices
- Consider the legal and ethical implications of privilege escalation testing

## References

- [Original Research: Windows Registry RPCEptMapper EOP](https://itm4n.github.io/windows-registry-rpceptmapper-eop/)
- Microsoft Registry Permissions Documentation
- Windows Service Security Best Practices

## Related Skills

- Windows privilege escalation enumeration
- Service configuration auditing
- Registry security assessment
- Post-exploitation documentation

## Troubleshooting

### "Access Denied" Errors

If you encounter access denied errors:
- Run PowerShell as Administrator
- Check if the registry key is protected by UAC
- Verify you have appropriate permissions

### Script Not Found

Ensure the script is in the current directory or provide the full path:
```powershell
.\scripts\check-service-registry-permissions.ps1
```

### Execution Policy

If PowerShell blocks script execution:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Or run with bypass:
```powershell
powershell -ExecutionPolicy Bypass -File .\check-service-registry-permissions.ps1
```
