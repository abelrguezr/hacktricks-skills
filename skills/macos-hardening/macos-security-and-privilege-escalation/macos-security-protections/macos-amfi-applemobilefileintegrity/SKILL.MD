---
name: macos-amfi-security
description: macOS AMFI (AppleMobileFileIntegrity) security reference. Use this skill whenever the user asks about macOS kernel security, code signing enforcement, AMFI boot arguments, MACF policies, amfid daemon, provisioning profiles, or macOS privilege escalation related to file integrity. Trigger for any macOS security research, jailbreak analysis, or code signing questions.
---

# macOS AMFI Security Reference

A comprehensive reference for AppleMobileFileIntegrity (AMFI) security mechanisms on macOS.

## Quick Reference

### What is AMFI?

AppleMobileFileIntegrity is a kernel extension that enforces code signature verification on macOS. It provides:
- Code signature verification logic for XNU kernel
- Entitlement checking for sensitive operations
- Debugging and task port access control
- Library validation enforcement

### Key Components

| Component | Path | Purpose |
|-----------|------|--------|
| `AMFI.kext` | Kernel | Core integrity enforcement |
| `amfid` | `/usr/libexec/amfid` | User-space daemon for signature checks |
| `libmis.dylib` | `MobileDevice.framework` | Decision logic library |

---

## AMFI Boot Arguments

These boot arguments can debilitate or disable AMFI enforcement:

| Argument | Effect |
|----------|--------|
| `amfi_unrestricted_task_for_pid` | Allow `task_for_pid` without required entitlements |
| `amfi_allow_any_signature` | Allow any code signature |
| `cs_enforcement_disable` | System-wide code signing enforcement disabled |
| `amfi_prevent_old_entitled_platform_binaries` | Void platform binaries with entitlements |
| `amfi_get_out_of_my_way` | **Disables AMFI completely** |

### Usage

```bash
# Add to boot arguments (requires SIP disabled)
# In recovery mode or via NVRAM
nvram boot-args="amfi_get_out_of_my_way"
```

---

## MACF Policies

AMFI registers these MACF (Mandatory Access Control Framework) policies:

### Credential Label Policies

| Policy | Purpose |
|--------|--------|
| `cred_check_label_update_execve` | Label update performed, returns 1 |
| `cred_label_associate` | Update AMFI's MAC label slot |
| `cred_label_destroy` | Remove AMFI's MAC label slot |
| `cred_label_init` | Initialize AMFI's MAC label slot to 0 |
| `cred_label_update_execve` | Check process entitlements for label modification |

### File System Policies

| Policy | Purpose |
|--------|--------|
| `file_check_mmap` | Check if mmap sets executable memory; triggers library validation |
| `file_check_library_validation` | Verify platform binary loading, TeamID matching, entitlements |
| `vnode_check_exec` | Load executable, set `cs_hard | cs_kill` flags |
| `vnode_check_getextattr` | Check `com.apple.root.installed` and quarantine status |
| `vnode_check_setextattr` | Check `com.apple.private.allow-bless` entitlement |
| `vnode_check_signature` | Call XNU for code signature verification |

### Process Policies

| Policy | Purpose |
|--------|--------|
| `proc_check_inherit_ipc_ports` | Control task port inheritance (TeamID, entitlements) |
| `proc_check_expose_task` | Enforce task port exposure entitlements |
| `proc_check_get_task` | Check `get-task-allow`, `task_for_pid-allow` entitlements |
| `proc_check_run_cs_invalid` | Intercept `ptrace()` calls, check debugging entitlements |
| `proc_check_map_anon` | Check `dynamic-codesigning` entitlement for `MAP_JIT` flag |
| `proc_check_mprotect` | Deny `VM_PROT_TRUSTED` flag usage |

### Exception/Debugging Policies

| Policy | Purpose |
|--------|--------|
| `amfi_exc_action_check_exception_send` | Exception message sent to debugger |
| `amfi_exc_action_label_*` | Label lifecycle during exception handling |

### System Policies

| Policy | Purpose |
|--------|--------|
| `policy_initbsd` | Set up trusted NVRAM keys |
| `policy_syscall` | Check DYLD policies (unrestricted segments, env vars) |

---

## amfid Daemon

### Communication

- **Port**: `HOST_AMFID_PORT` (special port 18)
- **Protocol**: Mach messages via MIG (Mach Interface Generator)
- **Protection**: SIP prevents root from hijacking special ports; only `launchd` can access

### Debugging amfid

```bash
# Set breakpoint in mach_msg to intercept AMFI checks
lldb -p $(pgrep amfid)
(lldb) breakpoint set --name mach_msg
(lldb) process continue
```

### Key Functions

The main functions are reversed and documented in *OS Internals Volume III*.

---

## Provisioning Profiles

### Overview

Provisioning profiles sign code and grant entitlements:

| Profile Type | Use Case |
|--------------|----------|
| **Developer** | Testing, limited devices |
| **Enterprise** | All devices, distribution |
| **Apple Store** | Signed by Apple, no profile needed |

### File Extensions

- `.mobileprovision`
- `.provisionprofile`

### Location

```bash
/var/MobileDeviceProvisioningProfiles/
```

### Parsing Profiles

```bash
# Using openssl
openssl asn1parse -inform der -in /path/to/profile

# Using security tool (preferred)
security cms -D -i /path/to/profile
```

### Profile Contents

| Field | Description |
|-------|-------------|
| `AppIDName` | Application identifier |
| `AppleInternalProfile` | Apple internal profile flag |
| `ApplicationIdentifierPrefix` | Team identifier prefix |
| `CreationDate` | `YYYY-MM-DDTHH:mm:ssZ` format |
| `DeveloperCertificates` | Base64-encoded certificate(s) |
| `Entitlements` | Allowed entitlements (restricted set) |
| `ExpirationDate` | `YYYY-MM-DDTHH:mm:ssZ` format |
| `Name` | Application name |
| `ProvisionedDevices` | Valid UDIDs (developer profiles) |
| `ProvisionsAllDevices` | Boolean (true for enterprise) |
| `TeamIdentifier` | Developer identifier array |
| `TeamName` | Human-readable developer name |
| `TimeToLive` | Validity in days |
| `UUID` | Unique profile identifier |
| `Version` | Currently 1 |

### Important Notes

- Entitlements are **restricted** to prevent Apple private entitlements
- Profiles expire and must be renewed
- Enterprise profiles can provision all devices

---

## AMFI Trust Caches

### What is the Trust Cache?

A list of known hashes signed ad-hoc, stored in the kext's `__TEXT.__const` section.

### Usage

- Used for fast signature verification
- Can be extended with external files for sensitive operations
- Maintained by iOS AMFI (similar on macOS)

---

## AMFI Dependencies

Check AMFI's kernel extension dependencies:

```bash
# Method 1: kextstat
kextstat | grep " 19 " | cut -c2-5,50- | cut -d '(' -f1

# Method 2: kmutil (modern)
/usr/bin/kmutil showloaded
```

### Common Dependencies

| ID | Bundle Identifier |
|----|-------------------|
| 8 | `com.apple.kec.corecrypto` |
| 19 | `com.apple.driver.AppleMobileFileIntegrity` |
| 22 | `com.apple.security.sandbox` |
| 24 | `com.apple.AppleSystemPolicy` |
| 67 | `com.apple.iokit.IOUSBHostFamily` |
| 70 | `com.apple.driver.AppleUSBTDM` |
| 71 | `com.apple.driver.AppleSEPKeyStore` |
| 74 | `com.apple.iokit.EndpointSecurity` |
| 81 | `com.apple.iokit.IOUserEthernet` |
| 101 | `com.apple.iokit.IO80211Family` |
| 102 | `com.apple.driver.AppleBCMWLANCore` |
| 118 | `com.apple.driver.AppleEmbeddedUSBHost` |
| 134 | `com.apple.iokit.IOGPUFamily` |
| 135 | `com.apple.AGXG13X` |
| 137 | `com.apple.iokit.IOMobileGraphicsFamily` |
| 138 | `com.apple.iokit.IOMobileGraphicsFamily-DCP` |
| 162 | `com.apple.iokit.IONVMeFamily` |

---

## Security Considerations

### Jailbreak Exploits

Historically abused trust relationships:

1. **amfid communication**: Trust between kext and user-space daemon
2. **libmis.dylib**: Backdoored versions allowed everything
3. **Special port hijacking**: No longer possible on macOS (SIP protected)

### Prevention

- Keep SIP enabled (`csrutil status`)
- Monitor boot arguments
- Verify provisioning profiles
- Check code signatures regularly

---

## References

- **OS Internals Volume III** - https://newosxbook.com/home.html
- **Apple Security Guide** - Official documentation
- **XNU Source Code** - amfi implementation details

---

## Common Tasks

### Check AMFI Status

```bash
# Check if AMFI is loaded
kextstat | grep AppleMobileFileIntegrity

# Check SIP status
csrutil status

# Check boot arguments
nvram boot-args
```

### Inspect Code Signatures

```bash
# Check binary signature
codesign -dv /path/to/binary

# Verify signature
codesign -v /path/to/binary
```

### List Entitlements

```bash
# From binary
plutil -p /path/to/binary/Contents/Info.plist | grep -A 100 NSAppleEventsUsageDescription

# From provisioning profile
security cms -D -i profile.mobileprovision | plutil -p - | grep -A 100 Entitlements
```

### Debug AMFI Behavior

```bash
# Monitor amfid
sudo lldb -p $(pgrep amfid)

# Check library validation
log show --predicate 'process == "amfid"' --last 1h
```

---

## When to Use This Skill

Use this skill when you need to:

- Understand macOS code signing enforcement
- Research AMFI boot arguments for security testing
- Analyze MACF policies and their effects
- Debug amfid daemon behavior
- Parse or create provisioning profiles
- Investigate macOS privilege escalation vectors
- Study kernel extension dependencies
- Understand trust cache mechanisms

This skill provides authoritative reference information for macOS security research and analysis.
