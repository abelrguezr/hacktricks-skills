---
name: windows-av-edr-defense-research
description: Use this skill for Windows AV/EDR defense research, detection engineering, and authorized security assessments. Trigger when users need to understand AV/EDR bypass techniques for building detections, analyzing malware behavior, conducting authorized penetration testing, or researching Windows security mechanisms. This skill covers AMSI, ETW, Defender, PPL, DLL sideloading, and other Windows security features from a defensive perspective.
---

# Windows AV/EDR Defense Research

A skill for security professionals researching Windows AV/EDR mechanisms, building detection rules, and conducting authorized security assessments.

## When to Use This Skill

Use this skill when:
- Building detection rules for AV/EDR bypass techniques
- Analyzing malware behavior and evasion patterns
- Conducting authorized penetration testing or red team operations
- Researching Windows security mechanisms (AMSI, ETW, PPL, Defender)
- Understanding threat actor tradecraft for threat intelligence
- Developing security controls and mitigations

## Core Concepts

### AV Detection Methods

**Static Detection**
- Known malicious strings/byte patterns in binaries
- File metadata analysis (description, company, signatures, checksums)
- Public tools are frequently flagged due to prior analysis

**Dynamic Analysis**
- Sandbox execution monitoring
- Behavioral analysis of suspicious activities
- Resource checks (RAM < 2GB, CPU temperature, fan speeds)
- Machine-specific checks (domain membership, computer name)

**Behavioral Analysis**
- EDR monitoring of process chains and API calls
- Call-stack analysis for detection
- Memory access patterns

### AMSI (Anti-Malware Scan Interface)

AMSI inspects script behavior in:
- PowerShell (scripts, interactive, dynamic code)
- Windows Script Host (wscript.exe, cscript.exe)
- JavaScript and VBScript
- Office VBA macros
- .NET 4.8+ (including Assembly.Load)

**Detection Indicators:**
- `amsi:` prefix in Defender alerts
- In-memory script scanning without file drops
- PowerShell version 2 avoids AMSI loading

**Defensive Recommendations:**
- Monitor for AMSI initialization failures
- Detect memory patching of AmsiScanBuffer
- Alert on PowerShell version 2 usage in suspicious contexts
- Watch for LdrLoadDll hooking attempts

### ETW (Event Tracing for Windows)

ETW logs events for security monitoring. Bypass attempts include:
- Memory patching of EtwEventWrite to return immediately
- Hooking user-mode ETW providers

**Detection Indicators:**
- Missing expected ETW events from processes
- Memory modifications to ETW functions
- Unusual process behavior without corresponding logs

### Defender Platform Architecture

Defender selects platform from:
```
C:\ProgramData\Microsoft\Windows Defender\Platform\
```

Selection logic:
- Enumerates subfolders
- Picks lexicographically highest version string
- Trusts directory entries including symlinks

**Defensive Recommendations:**
- Monitor Platform folder for new directories/symlinks
- Alert on Defender running from non-standard paths
- Enable tamper protection
- Use WDAC/AppLocker for code integrity

### Protected Process Light (PPL)

PPL enforces signer/level hierarchy:
- Only equal-or-higher protected processes can tamper
- Requires PPL-capable EKU signature
- Needs CREATE_PROTECTED_PROCESS flag

**Protection Levels:**
- Level 0: None
- Level 1: Windows
- Level 2: Windows Light
- Level 3: Anti-Malware Light
- Level 4: Anti-Malware

**Detection Indicators:**
- Processes created with CREATE_PROTECTED_PROCESS
- Unusual PPL level usage by non-AV binaries
- PPL-backed writes to protected directories

### DLL Sideloading & Proxying

**Sideloading:**
- Exploits DLL search order
- Malicious DLL placed alongside victim application
- Program loads attacker-controlled DLL instead of legitimate one

**Proxying:**
- Forwards calls from proxy DLL to original DLL
- Preserves program functionality
- Enables payload execution

**Detection Indicators:**
- DLLs loaded from non-system paths
- Signed DLLs loading unsigned companions
- Process/module chains: LOLBin → non-system DLL → user DLL

**ForwardSideLoading:**
- Uses forwarded exports (TargetDll.TargetFunc)
- Non-KnownDLL targets resolved via normal search order
- Example: keyiso.dll → NCRYPTPROV.dll

### BYOVD (Bring Your Own Vulnerable Driver)

**Attack Pattern:**
1. Signed vulnerable driver loaded (bypasses DSE)
2. Driver registered as kernel service
3. IOCTLs used for privileged operations
4. Can terminate PPL processes, delete files

**Detection Indicators:**
- New kernel services created
- Drivers loaded from world-writable directories
- DeviceIoControl calls to custom device objects
- Process terminations from kernel context

**Mitigations:**
- Enable HVCI and Smart App Control
- Use vulnerable-driver block list
- Monitor kernel service creation
- Alert on suspicious IOCTL patterns

### SmartScreen & Mark of the Web (MoTW)

**MoTW:**
- NTFS Alternate Data Stream (Zone.Identifier)
- Created when files downloaded from internet
- Contains download URL

**SmartScreen:**
- Reputation-based blocking
- Triggers on uncommon downloads
- Bypassed by trusted certificates

**Defensive Recommendations:**
- Monitor Zone.Identifier ADS creation
- Alert on SmartScreen bypass attempts
- Use container-based delivery detection (ISO, etc.)

## Detection Engineering

### PowerShell Logging

**Techniques to Detect:**
- Transcription/Module Logging disabled
- PowerShell version 2 usage
- Unmanaged PowerShell sessions
- Script execution via stdin

**Detection Queries:**
```powershell
# Check for disabled logging
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellEngine" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Transcript

# Monitor for version 2
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational'; Id=400} | Where-Object {$_.Message -match "Version 2"}
```

### Memory-Based Execution

**C# Assembly Loading:**
- InlineExecute-Assembly (in-process)
- Fork&Run (sacrificial process)
- Reflective loading (no LoadLibrary)

**Detection Indicators:**
- Assembly.Load(byte[]) calls
- Unusual process injection patterns
- Memory regions with RWX permissions
- Missing file artifacts for executed code

### Obfuscation Detection

**Common Techniques:**
- ConfuserEx (control-flow flattening, proxy calls)
- Encryption (increases entropy)
- String obfuscation
- Metamorphic code

**Detection Approaches:**
- Entropy analysis (high entropy = encryption)
- Control-flow graph analysis
- Proxy call detection
- ConfusedByAttribute IOC

## Authorized Assessment Procedures

### Pre-Assessment Checklist

1. **Authorization**
   - Written scope and rules of engagement
   - Legal review completed
   - Stakeholder notification

2. **Environment**
   - Isolated test environment
   - Backup of critical systems
   - Rollback procedures documented

3. **Tools**
   - Custom tooling (not public signatures)
   - Evasion techniques documented
   - Detection coverage mapped

### Assessment Workflow

1. **Reconnaissance**
   - Map AV/EDR products in use
   - Identify logging mechanisms
   - Document security controls

2. **Baseline Testing**
   - Test with known signatures
   - Establish detection baseline
   - Document false positive rates

3. **Evasion Testing**
   - Test AMSI bypass detection
   - Validate ETW monitoring
   - Assess PPL protections

4. **Reporting**
   - Document findings
   - Provide remediation guidance
   - Include detection rules

## Detection Rule Templates

### AMSI Bypass Detection
```yaml
rule_name: AMSI_Bypass_Attempt
description: Detects attempts to bypass AMSI scanning
conditions:
  - process_name: "powershell.exe"
  - command_line: contains "amsiInitFailed" OR "AmsiUtils"
  - memory_access: "amsi.dll" with write permissions
severity: high
```

### DLL Sideloading Detection
```yaml
rule_name: DLL_Sideloading_Attempt
description: Detects potential DLL sideloading activity
conditions:
  - process_name: contains "rundll32.exe" OR "regsvr32.exe"
  - module_path: not starts_with "C:\Windows\System32"
  - parent_process: not in ["explorer.exe", "svchost.exe"]
severity: medium
```

### PPL Abuse Detection
```yaml
rule_name: PPL_Process_Abuse
description: Detects unusual PPL process creation
conditions:
  - process_flags: contains "CREATE_PROTECTED_PROCESS"
  - process_name: not in ["MsMpEng.exe", "Sense.exe", "SecurityHealthService.exe"]
  - protection_level: greater_than 0
severity: high
```

## Research Resources

### Tools for Analysis
- **ThreatCheck**: Identify flagged strings/bytes in binaries
- **Siofra**: Find DLL sideloading vulnerabilities
- **dumpbin**: Enumerate forwarded exports
- **Process Monitor**: Track file/registry activity

### Reference Documentation
- Microsoft Known DLLs: https://learn.microsoft.com/windows/win32/dlls/known-dlls
- Protected Processes: https://learn.microsoft.com/windows/win32/procthread/protected-processes
- EKU Reference: https://learn.microsoft.com/openspecs/windows_protocols/ms-ppsec/
- Windows 11 Forwarded Exports: https://hexacorn.com/d/apis_fwd.txt

## Best Practices

### For Blue Teams
1. Enable all available logging (AMSI, ETW, PowerShell)
2. Implement WDAC/AppLocker for code integrity
3. Monitor for kernel service creation
4. Alert on PPL process anomalies
5. Use vulnerable-driver block lists
6. Enable Defender tamper protection

### For Red Teams (Authorized)
1. Use custom tooling to avoid signatures
2. Chain multiple evasion techniques
3. Test in isolated environments first
4. Document all techniques for reporting
5. Respect scope and authorization
6. Provide detection guidance in reports

### For Researchers
1. Focus on understanding mechanisms, not exploitation
2. Publish findings responsibly
3. Coordinate with vendors on vulnerabilities
4. Contribute to detection communities
5. Maintain ethical standards

## Safety Guidelines

**DO:**
- Use only in authorized environments
- Document all activities
- Provide defensive value
- Share findings responsibly

**DO NOT:**
- Use against systems without authorization
- Deploy in production without approval
- Share attack tools publicly
- Bypass legal or ethical boundaries

## Output Format

When providing analysis or recommendations, use this structure:

```
## Analysis Summary
[Brief overview of findings]

## Detection Gaps
[List of identified gaps]

## Recommended Controls
[Specific defensive measures]

## Detection Rules
[Ready-to-deploy detection logic]

## References
[Relevant documentation and resources]
```

## Iteration Notes

This skill should be updated when:
- New AV/EDR bypass techniques emerge
- Windows security features change
- Detection methodologies improve
- New threat actor tradecraft is observed

Always prioritize defensive value and authorized use cases.
