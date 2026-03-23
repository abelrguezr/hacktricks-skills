---
name: bloodhound-ad-enumeration
description: Active Directory enumeration and visualization using BloodHound, ADRecon, and related tools. Use this skill whenever the user needs to map AD relationships, find privilege escalation paths, enumerate GPOs, or visualize attack paths in Windows domains. Trigger on mentions of BloodHound, AD enumeration, privilege escalation, Kerberoasting, GPO analysis, Active Directory reconnaissance, SharpHound, or domain mapping.
---

# BloodHound & Active Directory Enumeration

This skill helps you enumerate and visualize Active Directory relationships to identify privilege escalation paths, lateral movement opportunities, and security misconfigurations.

## When to Use This Skill

Use this skill when you need to:
- Map Active Directory relationships and trust structures
- Find privilege escalation paths in a Windows domain
- Enumerate Group Policy Objects (GPOs) and their configurations
- Identify Kerberoastable service accounts
- Visualize attack paths through AD
- Perform AD health checks and risk assessments
- Collect AD data for offline analysis

## Tool Selection Guide

| Tool | Best For | Noise Level | Privileges Required |
|------|----------|-------------|---------------------|
| **BloodHound + SharpHound** | Graph visualization, path finding | Medium-High | Domain user (elevated for full data) |
| **ADRecon** | Comprehensive Excel report | Medium | Domain user |
| **AD Explorer** | GUI browsing, snapshot comparison | Low | Domain user |
| **Group3r** | GPO misconfiguration detection | Low | Domain user |
| **PingCastle** | AD health check, risk scoring | Low | Domain user |
| **RustHound-CE** | Stealthy ADWS collection | Low | Domain user |

## BloodHound Deployment

### Quick Start (Docker)

```bash
# Deploy BloodHound CE
curl -L https://ghst.ly/getbhce | docker compose -f - up

# Access Web UI at http://localhost:8080
# Default credentials: admin / (check logs for password)
```

### Collector Selection

Choose the right collector based on your access level and stealth requirements:

#### SharpHound (Full Collection)
```powershell
# Full sweep - most comprehensive but noisy
SharpHound.exe --CollectionMethods All

# Targeted collection - balance of data and stealth
SharpHound.exe --CollectionMethods Group,LocalAdmin,Session,Trusts,ACL

# Stealth mode - LDAP only, minimal noise
SharpHound.exe --Stealth --LDAP
```

#### RustHound-CE (Stealthy ADWS)
```bash
# Low-noise collection via ADWS
rusthound-ce -d corp.local -u svc.collector -p 'Passw0rd!' -c All -z
```

#### AzureHound (Azure AD)
```powershell
# Azure AD enumeration
Invoke-AzureHound -TenantId <tenant-id> -ClientSecret <secret>
```

## Critical: Running Collectors Elevated

**Why elevation matters:**
- UAC creates filtered tokens for interactive admins, stripping sensitive privileges
- Non-elevated shells miss high-value privileges like `SeBackupPrivilege`, `SeDebugPrivilege`
- BloodHound won't ingest privilege edges from filtered tokens
- Local LPE edges are invisible without elevated collection

**Always run collectors elevated when possible** to capture:
- Token privileges (`SeBackupPrivilege`, `SeDebugPrivilege`, `SeImpersonatePrivilege`, `SeAssignPrimaryTokenPrivilege`)
- Logon rights (`SeInteractiveLogonRight`, `SeRemoteInteractiveLogonRight`, `SeNetworkLogonRight`, `SeServiceLogonRight`, `SeBatchLogonRight`)
- Deny entries that gate lateral movement

## Collection Strategies

### Strategy 1: GPO/SYSVOL Parsing (Stealthy, Low-Privilege)

**Use when:** You have normal user access and need to stay quiet

**Process:**
1. Enumerate GPOs over LDAP: `(objectCategory=groupPolicyContainer)`
2. Read each `gPCFileSysPath` to locate GPO files
3. Fetch `MACHINE\Microsoft\Windows NT\SecEdit\GptTmpl.inf` from SYSVOL
4. Parse `[Privilege Rights]` section mapping privilege names to SIDs
5. Resolve GPO links via `gPLink` on OUs/sites/domains
6. Attribute rights to computers in linked containers

**Pros:** Works with normal user, quiet operation
**Cons:** Only sees GPO-pushed rights, misses local tweaks

### Strategy 2: LSA RPC Enumeration (Noisy, Accurate)

**Use when:** You have local admin on targets and need complete data

**Process:**
1. From elevated context on target, open Local Security Policy
2. Call `LsaEnumerateAccountsWithUserRight` for each privilege/logon right
3. Enumerate assigned principals over RPC

**Pros:** Captures all rights including local modifications
**Cons:** Noisy network traffic, requires admin on every host

## Kerberoasting Workflow

Use graph context to keep roasting targeted and efficient:

### Step 1: Collect Once, Work Offline
```bash
rusthound-ce -d corp.local -u svc.collector -p 'Passw0rd!' -c All -z
```

### Step 2: Import and Query
1. Import the ZIP into BloodHound GUI
2. Mark compromised principal as "owned"
3. Run built-in queries:
   - **Kerberoastable Users** - Find SPN accounts
   - **Shortest Paths to Domain Admins** - Prioritize by blast radius

### Step 3: Prioritize Targets
Review before cracking:
- `pwdLastSet` - How old is the password?
- `lastLogon` - Is the account active?
- Allowed encryption types - What can you crack?

### Step 4: Request and Crack
```bash
# Request tickets for prioritized SPNs
netexec ldap dc01.corp.local -u svc.collector -p 'Passw0rd!' \
  --kerberoasting kerberoast.txt --spn svc-sql

# Crack offline with hashcat or john
```

### Step 5: Re-query with New Access
After cracking, re-import into BloodHound with new credentials to discover additional paths.

## Common Attack Paths

### Privilege Escalation via Backup Privilege
```
CanRDP → Host with SeBackupPrivilege → Elevated shell → 
Read SAM/SYSTEM hives → secretsdump.py → Local Admin hash → Lateral movement
```

### GPO-Based Escalation
```
GPO with dangerous permissions → Modify GPO → 
Push malicious policy → Domain-wide impact
```

### Trust Abuse
```
Cross-domain trust → Trust admin rights → 
Domain compromise → Forest-wide access
```

## Other Enumeration Tools

### ADRecon (Comprehensive Report)
```powershell
# Run from Windows host in domain
PS C:\> .\ADRecon.ps1 -OutputDir C:\Temp\ADRecon
```
**Output:** Excel report with ACLs, GPOs, trusts, CA templates

### AD Explorer (GUI Analysis)
1. Connect to domain controller with domain credentials
2. Create offline snapshot: `File → Create Snapshot`
3. Compare snapshots: `File → Compare` to spot permission drifts

### Group3r (GPO Analysis)
```bash
# Execute inside domain
Group3r.exe -f gpo.log   # -s for stdout
```
**Focus:** GPO misconfigurations and dangerous permissions

### PingCastle (Health Check)
```powershell
PingCastle.exe --healthcheck --server corp.local \
  --user bob --password "P@ssw0rd!"
```
**Output:** HTML report with risk scoring and remediation guidance

## Best Practices

1. **Collect once, analyze offline** - Minimize noise by doing one thorough collection
2. **Prioritize by blast radius** - Focus on accounts with admin/infra rights
3. **Use stealth collectors first** - Start with RustHound-CE or SharpHound --Stealth
4. **Mark owned nodes** - In BloodHound, mark compromised principals to find paths
5. **Combine tools** - Use multiple tools to cross-validate findings
6. **Document findings** - Save snapshots and reports for later analysis

## Troubleshooting

### BloodHound not showing privilege edges
- Ensure collector ran elevated
- Check if `SeBackupPrivilege` and similar are in collection
- Try LSA RPC enumeration instead of GPO parsing

### SharpHound fails to connect
- Verify domain connectivity
- Check firewall rules for LDAP (389) and RPC (135)
- Ensure account has read permissions on domain objects

### No paths found in BloodHound
- Verify data was imported correctly
- Check collection methods - try `All` instead of targeted
- Ensure you marked owned nodes correctly

## References

- [BloodHound GitHub](https://github.com/BloodHoundAD/BloodHound)
- [RustHound-CE](https://github.com/g0h4n/RustHound-CE)
- [Beyond ACLs: Mapping Windows Privilege Escalation](https://www.synacktiv.com/en/publications/beyond-acls-mapping-windows-privilege-escalation-paths-with-bloodhound.html)
- [ADRecon](https://github.com/adrecon/ADRecon)
- [PingCastle Documentation](https://www.pingcastle.com/documentation/)
