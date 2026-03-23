---
name: ios-exploit-chain-analyzer
description: Analyze iOS zero-click attack chains, CoreAudio vulnerabilities, PAC bypass techniques, and CryptoTokenKit abuse patterns. Use this skill whenever the user mentions iOS security research, iMessage exploitation, zero-click attacks, CoreAudio/AudioConverterService vulnerabilities, arm64e PAC/RPAC bypass, kernel escalation, CryptoTokenKit abuse, BlastDoor bypass, or any iOS exploitation chain analysis. Also trigger for defensive hardening recommendations, vulnerability research, or when analyzing iOS security tutorials and CVE chains.
---

# iOS Exploit Chain Analyzer

A skill for analyzing iOS zero-click attack chains, understanding exploitation techniques, and generating defensive recommendations for security researchers and defenders.

## When to use this skill

Use this skill when:
- Analyzing iOS security vulnerabilities or attack chains
- Researching zero-click exploitation techniques
- Understanding CoreAudio, iMessage, or BlastDoor attack surfaces
- Studying PAC/RPAC bypass methods on arm64e
- Investigating CryptoTokenKit or Secure Enclave abuse
- Creating defensive hardening recommendations
- Parsing iOS security tutorials or CVE documentation
- Preparing security assessments or threat modeling for iOS

## Core workflow

### 1. Parse the attack chain

Break down the exploitation chain into stages:

```
Delivery → Auto-ingestion → Parser Bug → Userland RCE → PAC Bypass → Kernel Escalation → Post-Exploitation
```

For each stage, identify:
- **Component**: Which iOS subsystem is targeted
- **Trigger**: What user action (or lack thereof) enables the stage
- **Primitive**: What capability is gained (R/W, code exec, etc.)
- **Bypass**: What protection is circumvented

### 2. Extract vulnerability details

From the source material, capture:

| Field | Example |
|-------|--------|
| CVE IDs | CVE-2025-31200, CVE-2025-31201 |
| Affected versions | iOS 18.x < 18.4.1 |
| Primary component | CoreAudio → AudioConverterService |
| Delivery vector | iMessage/SMS with malicious audio |
| Key logs | `ACMP4AACBaseDecoder.cpp: inMagicCookie=0x0` |

### 3. Map the BlastDoor bypass

Document how isolation is defeated:

```
Normal path: iMessage → BlastDoor (hardened parser) → Safe
Bypass path: iMessage → "Known sender" framing → BlastDoor disabled → CoreAudio → RCE
```

Key indicators:
- `BlastDoor: Disabled for framing messages`
- `Blackhole disabled; user has disabled filtering unknown senders`

### 4. Analyze the PAC bypass

For arm64e Pointer Authentication bypasses:

1. **Prerequisite**: Arbitrary read/write primitive from userland RCE
2. **Mechanism**: RPAC path enables re-signed pointers or PAC-tolerant execution
3. **Stabilization**: Info leaks defeat KASLR, gadget sequences re-sign pointers
4. **Outcome**: Reliable control flow under PAC constraints

Research notes:
- Target callsites that generate PAC on attacker-controlled values
- Look for predictable context keys or signature generation patterns
- Expect variance by SoC/OS version

### 5. Document kernel escalation

Map userland primitives to kernel control:

```
Userland R/W + PAC bypass → Kernel surface (IOKit, networking, shared memory) → Kernel PC control
```

Common paths:
- **Wireless stack**: AppleBCMWLAN AMPDU handling
- **Media**: Shared memory corruption
- **IOKit**: Device driver interfaces
- **Mach**: IPC interface abuse

Key logs to watch:
```
IO80211ControllerMonitor::setAMPDUstat unhandled kAMPDUStat_ type 14
```

### 6. Assess post-exploitation impact

With kernel compromise, enumerate capabilities:

| Capability | Mechanism | Impact |
|------------|-----------|--------|
| Unauthorized signing | CryptoTokenKit + identityservicesd impersonation | Token/message/payment signing |
| Keychain access | Secure Enclave key operations | Credential theft |
| 2FA interception | Message/identity services | Account takeover |
| Stealth surveillance | Mic/camera/GPS without prompts | Persistent monitoring |

Key logs:
```
CryptoTokenKit operation:2 algo:algid:sign:ECDSA:digest-X962:SHA256
CryptoTokenKit <sepk:p256(d) kid=9a86778f7163e305> parsed for identityservicesd
```

## Defensive recommendations

### Immediate mitigations

1. **Patch level**: Update to iOS 18.4.1 or later
2. **Parser hardening**: Strict validation for codec cookies/atoms, bounds checks
3. **iMessage isolation**: Never relax BlastDoor/Blackhole for "known sender" contexts
4. **PAC hardening**: Reduce PAC-gadget availability, bind signatures to unpredictable contexts
5. **CryptoTokenKit**: Require post-kernel attestation, verify entitlements at call-time
6. **Kernel surfaces**: Harden wireless AMPDU/status handling, minimize userland-controlled inputs

### Long-term hardening

- **Runtime attestation**: Enforce for CTK consumers
- **Minimize ambient authority**: Least privilege for cryptographic operations
- **Defense in depth**: Multiple isolation layers (BlastDoor, Blackhole, PAC, KASLR)
- **Telemetry**: Monitor for parser anomalies and wireless stack errors
- **Threat modeling**: Assume kernel compromise is catastrophic; design accordingly

## Research patterns

### Fuzzing targets

When researching similar vulnerabilities:

1. **AudioConverterService**: Fuzz AAC/AMR magic cookies, MP4 codec atoms
2. **Container metadata**: Invalid/short/NULL values, length confusion
3. **Heap corruption**: Overflows/underflows, OOB reads/writes
4. **Decoder initialization**: Size/length parameters, magic cookie validation

### Log analysis

Watch for these indicators in telemetry:

```
# Parser issues
AudioConverterService ACMP4AACBaseDecoder.cpp: inMagicCookie=0x0

# BlastDoor bypass
IDSDaemon BlastDoor: Disabled for framing messages
SpamFilter Blackhole disabled

# Kernel escalation
IO80211ControllerMonitor::setAMPDUstat unhandled kAMPDUStat_

# Post-exploitation
CryptoTokenKit operation:2 algo:algid:sign:ECDSA
```

## Output formats

### Vulnerability summary

```
## Vulnerability: [Name]
- **CVE**: [IDs]
- **Affected**: [Versions]
- **Component**: [Subsystem]
- **Delivery**: [Vector]
- **Chain**: [Stage 1] → [Stage 2] → [Stage 3]
- **Impact**: [What can be done]
- **Mitigation**: [Patch/hardening]
```

### Attack chain diagram

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Delivery  │ →  │  Parser Bug  │ →  │  Userland   │
│  (iMessage) │    │ (CoreAudio)  │    │    RCE      │
└─────────────┘    └──────────────┘    └─────────────┘
                                              ↓
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Kernel    │ ←  │  PAC Bypass  │ ←  │  Info Leak  │
│  Escalation │    │   (RPAC)     │    │  (KASLR)    │
└─────────────┘    └──────────────┘    └─────────────┘
                                              ↓
┌─────────────────────────────────────────────────────┐
│              Post-Exploitation                      │
│  CryptoTokenKit abuse, Keychain, Surveillance      │
└─────────────────────────────────────────────────────┘
```

### Defensive checklist

```
## iOS Hardening Checklist

- [ ] Update to latest iOS version
- [ ] Review BlastDoor/Blackhole configuration
- [ ] Audit CryptoTokenKit entitlements
- [ ] Enable runtime attestation for CTK
- [ ] Monitor parser telemetry for anomalies
- [ ] Harden wireless stack inputs
- [ ] Review PAC gadget availability
- [ ] Implement defense-in-depth isolation
```

## Important notes

- **Educational use only**: This skill is for defensive research and understanding attack techniques
- **Lab environments**: Only test in isolated, controlled environments
- **Legal compliance**: Ensure all research complies with applicable laws and policies
- **Patch promptly**: Keep devices updated to mitigate known vulnerabilities

## References

When analyzing iOS exploitation chains, consult:
- Apple security updates and release notes
- CVE databases for specific vulnerability details
- Research papers on arm64e PAC and iOS hardening
- Vendor advisories for affected components

---

**Remember**: Understanding these attack chains helps defenders build better protections. Use this knowledge responsibly to improve iOS security posture, not to exploit devices.
