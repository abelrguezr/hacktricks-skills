---
name: printnightmare-hardening
description: Windows Print Spooler security hardening and PrintNightmare vulnerability remediation. Use this skill whenever the user mentions Print Spooler security, PrintNightmare, CVE-2021-1675, CVE-2021-34527, CVE-2021-34481, CVE-2022-21999, SpoolFool, Windows printer vulnerabilities, or needs to harden Windows systems against Print Spooler attacks. Also trigger for domain controller hardening, RPC printer service security, or when users ask about disabling the Print Spooler service.
---

# PrintNightmare Hardening Skill

This skill helps you assess, detect, and remediate Print Spooler vulnerabilities on Windows systems, including the PrintNightmare family of CVEs and related exploits.

## When to use this skill

Use this skill when:
- You need to check if a Windows system is vulnerable to PrintNightmare or SpoolFool
- You want to harden a Windows system against Print Spooler attacks
- You need to disable the Print Spooler service (especially on Domain Controllers)
- You're investigating suspicious Print Spooler activity
- You need to create detection rules for Print Spooler exploitation
- You're asked about CVE-2021-1675, CVE-2021-34527, CVE-2021-34481, or CVE-2022-21999

## Quick Actions

### Check Spooler Status

```powershell
# Check if Print Spooler is running
Get-Service -Name Spooler

# Check startup type
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Spooler' -Name Start
```

### Disable Spooler (Recommended for Domain Controllers)

```powershell
# Stop and disable the service
Stop-Service Spooler -Force
Set-Service Spooler -StartupType Disabled
```

### Apply Point & Print Restrictions

```powershell
# Restrict driver installation to administrators only
New-Item -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint' -Force
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint' `
  -Name 'RestrictDriverInstallationToAdministrators' -Value 1 -PropertyType DWORD -Force
```

## Vulnerability Assessment

### CVE Coverage

| CVE | Name | Impact | Status |
|-----|------|--------|--------|
| CVE-2021-1675 | PrintNightmare #1 | Local Privilege Escalation | Patched June 2021 |
| CVE-2021-34527 | PrintNightmare | Remote Code Execution | Patched July 2021 |
| CVE-2021-34481 | Point & Print | Local Privilege Escalation | Patched July 2021 |
| CVE-2022-21999 | SpoolFool | Local Privilege Escalation | Patched February 2022 |

### Assessment Checklist

1. **Patch Level**: Verify latest cumulative update is installed
2. **Service Status**: Confirm Spooler is disabled on Domain Controllers
3. **Registry Settings**: Check Point & Print restrictions are enabled
4. **Event Logging**: Ensure PrintService/Operational logs are enabled
5. **Network Exposure**: Verify remote spooler connections are blocked

## Detection Rules

### Event Log Monitoring

Monitor these events for Print Spooler exploitation:

- **Event ID 808** in `Microsoft-Windows-PrintService/Operational`: "The print spooler failed to load a plug-in module"
- **Event ID 1102** in Security log: Audit policy changes
- **Sysmon Event ID 7**: Image loaded by `spoolsv.exe`
- **Sysmon Event ID 11/23**: File write/delete in `C:\Windows\System32\spool\drivers\*`

### Process Lineage Alerts

Alert when `spoolsv.exe` spawns:
- `cmd.exe`
- `rundll32.exe`
- `powershell.exe`
- Any unsigned binary

### Sysmon Configuration

```xml
<!-- Add to Sysmon config for Print Spooler monitoring -->
<FileCreate>
  <TargetFilename condition="contains">C:\Windows\System32\spool\drivers\</TargetFilename>
  <ParentImage condition="is">C:\Windows\System32\spoolsv.exe</ParentImage>
</FileCreate>

<ProcessCreate>
  <ParentImage condition="is">C:\Windows\System32\spoolsv.exe</ParentImage>
  <Image condition="notStartsWith">C:\Windows\System32\</Image>
</ProcessCreate>
```

## Hardening Procedures

### Domain Controller Hardening

Domain Controllers should never need the Print Spooler service:

```powershell
# Disable on all Domain Controllers
Stop-Service Spooler -Force
Set-Service Spooler -StartupType Disabled

# Verify
Get-Service -Name Spooler | Select-Object Name, Status, StartType
```

### Workstation/Server Hardening (if printing is required)

```powershell
# 1. Apply latest patches first
# 2. Restrict Point & Print
New-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\Printers\PointAndPrint' `
  -Name 'RestrictDriverInstallationToAdministrators' -Value 1 -PropertyType DWORD -Force

# 3. Block remote connections via Group Policy
# Computer Configuration → Administrative Templates → Printers
# "Allow Print Spooler to accept client connections" = Disabled

# 4. Enable enhanced logging
New-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Spooler\Parameters' `
  -Name 'SpoolDirectory' -Value 'C:\Windows\System32\spool\PRINTERS' -PropertyType STRING -Force
```

### Group Policy Settings

Apply these GPO settings organization-wide:

| Policy Path | Setting | Value |
|-------------|---------|-------|
| Computer Config → Admin Templates → Printers | Allow Print Spooler to accept client connections | Disabled |
| Computer Config → Admin Templates → Printers | Point and Print Restrictions | Enabled |
| Computer Config → Admin Templates → Printers | Do not add network printers at logon | Enabled |

## Remediation Scripts

Use the bundled scripts for automated remediation:

- `check-spooler-status.ps1` - Assess current spooler configuration
- `disable-spooler.ps1` - Safely disable the Print Spooler service
- `apply-hardening.ps1` - Apply registry and policy hardening
- `generate-detection-rules.ps1` - Create Sysmon and EDR detection rules

## Related Tools

- **mimikatz** `printnightmare` module - Assessment and exploitation testing
- **SharpPrintNightmare** - C# exploitation tool
- **SpoolFool** - CVE-2022-21999 exploit
- **0patch** - Micropatches for unpatched systems

## References

- Microsoft KB5005652: Point & Print driver installation behavior
- CVE-2021-1675, CVE-2021-34527, CVE-2021-34481, CVE-2022-21999 advisories
- Oliver Lyak - SpoolFool write-up

---

**Note**: Always test hardening changes in a non-production environment first. Disabling the Print Spooler will break local and network printing functionality.
