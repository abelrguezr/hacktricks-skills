---
name: windows-enterprise-ipc-exploitation
description: Analyze and document Windows local privilege escalation chains in enterprise software (endpoint agents, auto-updaters, driver utilities). Use this skill whenever investigating IPC vulnerabilities, auto-updater hijacking, TOCTOU race conditions, or supply-chain attacks in products like Netskope, ASUS DriverHub, MSI Center, Acer Control Centre, or similar enterprise tools. Also use when creating detection rules for these attack patterns or documenting privilege escalation paths for security assessments.
---

# Windows Enterprise IPC Exploitation Analysis

This skill helps security researchers and penetration testers analyze, document, and detect privilege escalation vulnerabilities in Windows enterprise software that expose privileged IPC surfaces.

## When to Use This Skill

Use this skill when:
- Investigating local privilege escalation in endpoint security agents, auto-updaters, or driver utilities
- Analyzing IPC vulnerabilities (TCP, named pipes, ALPC) in enterprise software
- Documenting privilege escalation chains for security assessments
- Creating detection rules for auto-updater hijacking or IPC abuse
- Reversing encrypted IPC protocols or caller verification bypasses
- Analyzing TOCTOU race conditions in update mechanisms
- Investigating supply-chain attacks via compromised update infrastructure

## Core Attack Patterns

### 1. IPC-Based Enrollment Hijacking

**Pattern**: Low-privileged UI process communicates with SYSTEM service over localhost IPC to force re-enrollment to attacker-controlled server.

**Key indicators**:
- JSON-over-TCP on localhost (commonly ports 127.0.0.1:*)
- JWT tokens with `alg=None` or weak signing
- Configuration endpoints accepting arbitrary hostnames
- Registry-derived encryption keys (device IDs, ProductID)

**Analysis checklist**:
```
[ ] Identify IPC endpoints (netstat -ano, Wireshark loopback capture)
[ ] Map UI process ↔ service process relationships
[ ] Extract command IDs and message schemas
[ ] Check for JWT/token validation weaknesses
[ ] Look for registry keys with encryption material (HKLM\SOFTWARE\<vendor>)
[ ] Test caller verification (image path, process name checks)
```

### 2. Update Channel Hijacking

**Pattern**: Once client talks to attacker server, deliver malicious signed packages that SYSTEM service installs.

**Common bypasses**:
- CN allow-list only (no chain validation)
- Optional digest flags (`check_msi_digest: false`)
- CERT_DIGEST property present but not enforced
- Substring-based URL validation (`.vendor.com.attacker.tld`)

**Detection focus**:
- MSI installation from temp directories
- Certificate installation to Trusted Root store
- Signed binaries loading DLLs from non-canonical paths
- Update manifest modifications

### 3. Caller Verification Bypass

**Pattern**: Service restricts IPC callers by image path/name; bypass via injection or suspended process spawning.

**Techniques**:
- DLL injection into allow-listed vendor binary
- Spawn allow-listed binary suspended, patch NtContinue, resume
- Proxy IPC from inside trusted process

**Driver constraints to respect**:
- Avoid PROCESS_CREATE_THREAD on protected processes
- Avoid PROCESS_SUSPEND_RESUME on already-running protected processes
- Use CREATE_SUSPENDED on new process, then patch early thunk

### 4. Browser-to-Localhost CSRF

**Pattern**: Privileged HTTP service on localhost accepts browser requests with weak Origin validation.

**Indicators**:
- `string_contains(".vendor.com")` on Origin header
- Download URL validation reuses same substring logic
- State-changing endpoints (Reboot, UpdateApp) accessible via POST

**Test approach**:
```
1. Register domain embedding trusted TLD (driverhub.vendor.com.attacker.tld)
2. Host malicious page with fetch/XHR to localhost endpoint
3. Verify Origin header passes validation
4. Confirm state-changing action executes
```

### 5. TOCTOU Race Conditions

**Pattern**: File copied, verified, then executed without locking; attacker races to overwrite between verification and execution.

**Exploitation**:
- Send Frame A with legitimate signed binary (passes verification)
- Spam Frame B with malicious payload (overwrites temp file)
- Scheduler executes overwritten payload as SYSTEM

**Detection**:
- Monitor file modifications in temp directories during update operations
- Alert on signature verification followed by file replacement
- Track scheduled task creation with temp file paths

### 6. Supply-Chain via Compromised Infrastructure

**Pattern**: Attacker compromises update server/CDN, redirects clients to malicious installers.

**Chains observed**:
- BYO signed binary + DLL sideloading (e.g., Bitdefender BluetoothService.exe + log.dll)
- NSIS with embedded Lua shellcode injection
- Trojanized update.exe with reflective loading

**Detection pivots**:
- Signed vendor EXE loading DLL from outside install path
- Updater dropping executables to %TEMP%
- Mutex artifacts (e.g., `Global\Jdhfv_1.0.1`)
- Lua-driven injection stages

## Detection Rule Development

### XQL Pattern (Cortex XDR)

```sql
// Template for signed binary sideloading detection
config case_sensitive = false
| dataset = xdr_data
| filter event_type = ENUM.LOAD_IMAGE and agent_os_type = ENUM.AGENT_OS_WINDOWS
| filter actor_process_signature_vendor contains "<VENDOR_NAME>"
| filter action_module_path contains "<SUSPICIOUS_DLL>"
| filter actor_process_image_path not contains "Program Files\\<VENDOR>"
```

### YARA Pattern (DLL Sideloading)

```yara
rule SignedBinary_Sideloading {
    meta:
        description = "Detects signed vendor binary loading DLL from non-canonical path"
        author = "Security Researcher"
    strings:
        $vendor_path = "C:\\Program Files\\<VENDOR>" fullword
        $temp_path = "%TEMP%" ascii
        $dll_name = "log.dll" ascii
    condition:
        $dll_name at 0 and ($temp_path or not $vendor_path)
}
```

## Safe Testing Guidelines

**Before testing**:
- Obtain explicit authorization for the target system
- Use isolated lab environment (VMs with snapshots)
- Document baseline system state
- Have rollback procedures ready

**During testing**:
- Test one vulnerability class at a time
- Monitor for system instability
- Avoid destructive actions (reboot, delete) unless authorized
- Log all commands and responses

**After testing**:
- Restore system to baseline
- Document findings with reproduction steps
- Create detection rules for observed patterns
- Report to vendor if undisclosed

## Documentation Template

When documenting a privilege escalation chain, use this structure:

```
## Vulnerability Summary
- Product: <name> <version>
- CVE: <if assigned>
- Impact: Local Privilege Escalation to SYSTEM
- Attack Surface: <IPC type, port, protocol>

## Technical Details
### Component Mapping
- UI Process: <name> (<integrity level>)
- Service Process: <name> (SYSTEM)
- IPC Endpoint: <protocol, port, pipe name>

### Exploitation Flow
1. <step 1>
2. <step 2>
3. <step 3>

### Bypasses Required
- <caller verification>
- <encryption>
- <signature validation>

### Detection Evasion
- <techniques used>
- <artifacts left>

## Detection Rules
- <XQL/Sigma/YARA rules>

## References
- <advisory links>
- <PoC repositories>
```

## Common Tools

| Tool | Purpose |
|------|--------|
| Wireshark | Loopback traffic capture |
| Process Monitor | File/registry/IPC monitoring |
| Frida | Dynamic instrumentation |
| dnSpy | .NET binary analysis |
| sigthief | Certificate cloning |
| NachoVPN | Rogue CA + update server |

## References

- [Netskope CVE-2025-0309 Advisory](https://blog.amberwolf.com/blog/2025/august/advisory---netskope-client-for-windows---local-privilege-escalation-via-rogue-server/)
- [SensePost Bloatware Pwn](https://sensepost.com/blog/2025/pwning-asus-driverhub-msi-center-acer-control-centre-and-razer-synapse-4/)
- [Unit 42 Notepad++ Supply Chain](https://unit42.paloaltonetworks.com/notepad-infrastructure-compromise/)
- [HackTricks Windows Privilege Escalation](https://book.hacktricks.xyz/windows/)

## Next Steps

After initial analysis:
1. Run `scripts/generate-detection-rules.py` to create XQL/Sigma rules
2. Use `scripts/analyze-ipc-traffic.py` to parse captured loopback traffic
3. Document findings using the template above
4. Test detection rules in isolated environment
5. Iterate on bypass techniques if rules are too noisy
