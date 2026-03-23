---
name: esim-javacard-security
description: Security research and analysis for eSIM/JavaCard vulnerabilities. Use this skill when investigating eUICC security, analyzing Java Card VM type-safety issues, testing for Remote SIM Provisioning (RSP) vulnerabilities, or researching smart card exploitation techniques. Trigger for any queries about eSIM security, Java Card bytecode verification, GSMA TS.48 profiles, or smart card penetration testing.
---

# eSIM / JavaCard Security Research

A skill for security researchers analyzing eSIM vulnerabilities, Java Card VM exploitation, and smart card security assessment.

## When to Use This Skill

Use this skill when:
- Investigating eUICC (Embedded UICC) security vulnerabilities
- Analyzing Java Card Virtual Machine type-safety issues
- Testing Remote SIM Provisioning (RSP) security
- Researching smart card penetration testing methodologies
- Understanding GSMA TS.48 profile vulnerabilities
- Assessing eSIM cloning and hijacking risks
- Reviewing Java Card bytecode verification bypasses

## Core Concepts

### Attack Surface

1. **Remote Application Management (RAM)**
   - eSIM profiles embed Java Card applets
   - Provisioning via APDUs tunneled through SMS-PP or HTTPS
   - Compromised RAM keys enable remote `INSTALL`/`LOAD` of malicious applets

2. **Java Card Bytecode Execution**
   - Applets execute inside the VM
   - Missing runtime checks enable memory corruption
   - Type confusion primitives lead to arbitrary read/write

### The Type-Confusion Primitive

The `getfield`/`putfield` instructions should only operate on object references. Vulnerable implementations skip validation, allowing:

1. Create byte-array: `byte[] buf = new byte[0x100];`
2. Cast to object: `Object o = (Object)buf;` (illegal but unverified)
3. Use `putfield` to overwrite 16-bit values in adjacent objects
4. Use `getfield` to read arbitrary memory via hijacked pointers

This provides **arbitrary read/write** in the eUICC address space.

## Exploitation Workflow (Educational)

### Step 1: Firmware Enumeration

Query undocumented `GET DATA` item `DF1F` to identify vulnerable firmware:

```
APDU: 80 CA DF 1F 00
Response: "ECu10.13" indicates vulnerable Kigen firmware
```

### Step 2: Malicious Applet Installation

Abuse publicly-known keys from TS.48 Generic Test Profile (v≤6):

```
// LOAD command (block n)
80 E6 02 00 <data>

// INSTALL command
80 E6 0C 00 <data>
```

### Step 3: Trigger Type Confusion

When the applet is selected, it performs write-what-where to hijack pointer tables and leak memory through APDU responses.

### Step 4: Key Extraction

Private EC key is copied to applet RAM and returned in chunks via normal APDU responses.

### Step 5: eUICC Impersonation

Stolen key pair + certificates enable authentication to any RSP server as a legitimate card.

## Vulnerability Assessment Checklist

### Pre-Engagement

- [ ] Confirm authorization for testing
- [ ] Document target eUICC model and firmware version
- [ ] Verify legal compliance with GSMA regulations

### Technical Checks

- [ ] Query `GET DATA DF1F` for firmware string
- [ ] Inspect loaded profiles for TS.48 test profiles (v≤6)
- [ ] Check if RAM keys are publicly known
- [ ] Attempt basic cast primitive (`objarrconfusion`)
- [ ] Test for Security Domain private key exposure

### Risk Indicators

| Indicator | Risk Level | Action |
|-----------|------------|--------|
| Firmware `ECu10.13` | Critical | Vulnerable to type confusion |
| TS.48 v≤6 with static RAM keys | Critical | Directly exploitable |
| TS.48 v7 without RAM keys | Medium | Requires key leak |
| On-card bytecode verification | Low | Mitigated |

## Mitigations

### Vendor-Level

1. **On-card bytecode verification**
   - Enforce full control-flow & data-flow type tracking
   - Not just stack-top validation

2. **Hide array header**
   - Place `length` field outside overlapping object fields
   - Prevents type confusion via field offset collision

3. **Harden RAM keys policy**
   - Never ship profiles with public keys
   - Disable `INSTALL` in test profiles
   - TS.48 v7 removes RAM keysets

### Operator-Level

4. **RSP server heuristics**
   - Rate-limit profile downloads per EID
   - Monitor geographic anomalies
   - Validate certificate freshness

5. **Profile lifecycle management**
   - Keep devices off legacy test profiles
   - Apply OTA updates blocking applet loading with TS.48 v≤6
   - Remove test profiles from factory images

## Automated Testing

### Basic Security Check (bsc)

The `bsc` command reveals Java Card VM vulnerability status:

```
scard> bsc
castcheck        [arbitrary int/obj casts]
ptrgranularity   [pointer granularity/tr table presence]
locvaraccess     [local variable access]
stkframeaccess   [stack frame access]
instfieldaccess  [instance field access]
objarrconfusion  [object/array size field confusion]
```

### Test Modules

- `introspector` – Full VM and memory explorer (~1.7 MB Java)
- `security-test` – Generic verification bypass applet (~150 KB)
- `exploit` – Kigen eUICC compromise module (~72 KB)

## Cloning/Hijacking Impact

Installing the same profile on multiple devices routes traffic to whichever device most recently registered. This enables:

- Voice/SMS hijacking
- 2FA SMS interception
- Profile cloning to secondary eUICCs
- Java Card application patching (e.g., STK spyware insertion)
- Operator secret extraction

## References

- [Security Explorations – eSIM security](https://security-explorations.com/esim-security.html)
- [GSMA TS.48 Generic Test Profile v7.0](https://www.gsma.com/get-involved/working-groups/gsma_resources/ts-48-v7-0-generic-euicc-test-profile-for-device-testing/)
- [GSMA AN-2025-07 Preventing misuse of an eUICC Profile](https://www.gsma.com/solutions-and-impact/technologies/esim/gsma_resources/an-2025-07-preventing-misuse-of-an-euicc-profile-and-installation-of-malicious-java-card-application-v1-0/)
- [Java Card VM Specification 3.1](https://docs.oracle.com/en/java/javacard/3.1/jc-vm-spec/F12650_05.pdf)

## Important Notes

- This skill is for **authorized security research only**
- Always obtain proper authorization before testing
- GSMA regulations and local laws apply
- Vulnerabilities described are publicly disclosed and patched in updated firmware
- Focus on defensive measures and mitigation strategies
