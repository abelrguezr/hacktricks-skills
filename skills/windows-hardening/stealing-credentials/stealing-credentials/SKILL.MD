---
name: windows-credential-security
description: Analyze Windows credential security, understand attack vectors for authorized penetration testing, and recommend defensive hardening measures. Use this skill whenever the user asks about Windows credential theft techniques, LSASS security, SAM/NTDS.dit protection, Mimikatz detection, or needs to assess credential exposure risks in authorized security assessments. Make sure to use this skill for any Windows security analysis, red team planning, or defensive hardening discussions.
---

# Windows Credential Security Analysis

## ⚠️ Authorization Required

**This skill is for authorized security testing and defensive analysis only.**

- Only use these techniques on systems you own or have explicit written authorization to test
- Unauthorized credential access is illegal and violates computer crime laws
- Always document authorization before any security assessment
- Use findings to improve security posture, not to exploit vulnerabilities

## Purpose

This skill helps security professionals:
- Understand Windows credential storage mechanisms
- Identify attack vectors for authorized penetration testing
- Recommend defensive hardening measures
- Document security findings for authorized assessments
- Analyze indicators of compromise (IoCs)

## Credential Storage Overview

### LSASS (Local Security Authority Subsystem Service)

**What it is:** The process that handles Windows authentication and stores credentials in memory

**Attack Surface:**
- Credentials from interactive logons
- Cached domain credentials
- Kerberos tickets
- NTLM hashes

**Defensive Measures:**
- Enable Credential Guard (virtualization-based security)
- Enable LSA Protection (RunAsPPL)
- Monitor for LSASS injection attempts
- Use EDR solutions with memory scanning

### SAM (Security Account Manager)

**What it is:** Registry hive storing local account password hashes

**Location:** `C:\Windows\System32\config\SAM`

**Attack Surface:**
- Local user password hashes (NTLM)
- Requires SYSTEM access
- Protected by file permissions

**Defensive Measures:**
- Use strong local passwords
- Enable LSA protection
- Monitor registry access to SAM hive
- Consider disabling local accounts where possible

### NTDS.dit (Active Directory Database)

**What it is:** The Active Directory database containing domain credentials

**Location:** `%SystemRoot%\NTDS\ntds.dit`

**Attack Surface:**
- All domain user hashes
- Group memberships
- Trust relationships
- Requires SYSTEM + SYSTEM hive for decryption

**Defensive Measures:**
- Enable AD Credential Guard
- Monitor for NTDS.dit access attempts
- Implement privileged access workstations (PAW)
- Regular security audits of domain controllers

## Common Attack Techniques (For Defensive Understanding)

### Memory Dumping

**Technique:** Extracting LSASS memory to obtain credentials

**Tools Used (for detection purposes):**
- Mimikatz
- Procdump
- SharpDump
- Custom dumpers

**Detection Indicators:**
- Process injection into LSASS
- Use of MiniDumpWriteDump API
- Access to protected processes
- Registry modifications to LSA settings

**Prevention:**
- Enable LSA Protection (RunAsPPL)
- Enable Credential Guard
- Monitor for suspicious process access
- Use EDR with memory protection

### Registry-Based Extraction

**Technique:** Copying protected files via registry hives

**Detection Indicators:**
- `reg save` commands targeting SAM/SYSTEM/Security hives
- Unusual registry access patterns
- File creation in temp directories

**Prevention:**
- Monitor registry save operations
- Restrict administrative access
- Implement file integrity monitoring

### Volume Shadow Copy Abuse

**Technique:** Using VSS to copy protected files

**Detection Indicators:**
- VSS shadow copy creation
- Access to shadow copy volumes
- File copying from shadow copies

**Prevention:**
- Monitor VSS operations
- Restrict VSS access to administrators
- Implement application whitelisting

## Defensive Hardening Recommendations

### Registry Settings

```powershell
# Enable LSA Protection (RunAsPPL)
reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL /t REG_DWORD /d 1 /f

# Enable Credential Guard
reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v CredentialGuard /t REG_DWORD /d 1 /f

# Disable Restricted Admin (for security)
reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0 /f

# Enable UAC token filtering
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 0 /f
```

### Group Policy Recommendations

1. **Enable Credential Guard**
   - Computer Configuration → Windows Settings → Security Settings → Local Policies → Security Options
   - "Turn on Virtualization Based Security"

2. **Restrict LSASS Access**
   - Enable "Run LSA as protected process"

3. **Disable NTLM**
   - Where possible, use Kerberos authentication
   - Monitor and alert on NTLM usage

4. **Implement Least Privilege**
   - Remove unnecessary admin rights
   - Use Just-In-Time (JIT) administration

### Monitoring Recommendations

**Key Events to Monitor:**
- Event ID 4688 (Process Creation) - LSASS, procdump, mimikatz
- Event ID 4656 (Handle Requested) - Access to protected files
- Event ID 4663 (Object Access) - Registry hive access
- Event ID 1102 (Audit Log Cleared)
- Event ID 7045 (Service Installation)

**EDR Detection Rules:**
- Process injection into LSASS
- Use of MiniDumpWriteDump API
- Registry modifications to LSA settings
- Execution of known credential dumping tools

## Assessment Documentation Template

When conducting authorized assessments, document:

```markdown
## Credential Security Assessment

### Scope
- Systems tested: [List]
- Authorization: [Reference]
- Date: [Date]

### Findings

#### LSASS Security
- [ ] Credential Guard enabled
- [ ] LSA Protection enabled
- [ ] Monitoring in place

#### SAM Security
- [ ] Local accounts minimized
- [ ] Strong passwords enforced
- [ ] Registry access monitored

#### Active Directory Security
- [ ] NTDS.dit access monitored
- [ ] Admin access restricted
- [ ] Regular audits performed

### Recommendations
1. [Priority 1]
2. [Priority 2]
3. [Priority 3]
```

## Tools for Defensive Analysis

### Detection Tools
- **Sysmon** - Enhanced process and network monitoring
- **OSQuery** - SQL-based system querying
- **Velociraptor** - Endpoint detection and response
- **Sigma** - Detection rule format

### Analysis Tools
- **Volatility** - Memory forensics
- **Mimikatz (authorized use only)** - Understanding attack techniques
- **Impacket** - Network protocol analysis

## References

- [Microsoft Credential Guard Documentation](https://docs.microsoft.com/en-us/windows/security/threat-protection/credential-guard/credential-guard)
- [MITRE ATT&CK - Credential Access](https://attack.mitre.org/tactics/TA0006/)
- [CIS Benchmarks for Windows](https://www.cisecurity.org/benchmark/microsoft_windows)

## Important Notes

1. **Legal Compliance:** Always ensure you have proper authorization before testing
2. **Documentation:** Document all findings and recommendations
3. **Remediation:** Work with system owners to implement fixes
4. **Continuous Monitoring:** Security is ongoing, not one-time
5. **Training:** Educate users about credential security best practices

## When to Use This Skill

Use this skill when:
- Planning authorized penetration tests
- Assessing Windows credential security posture
- Investigating potential credential theft incidents
- Developing defensive hardening strategies
- Creating security documentation and reports
- Training security teams on credential protection

**Do NOT use this skill for:**
- Unauthorized access to systems
- Malicious credential theft
- Activities without proper authorization
- Any illegal or unethical purposes
