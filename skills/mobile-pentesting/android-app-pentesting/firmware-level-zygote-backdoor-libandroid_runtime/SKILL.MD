---
name: android-firmware-audit
description: Analyze Android firmware for supply-chain backdoors and firmware-level compromises. Use this skill whenever the user needs to audit Android firmware images, detect Zygote-level backdoors, investigate libandroid_runtime.so modifications, analyze firmware artifacts, or perform mobile forensics on compromised devices. Trigger for any request involving Android firmware analysis, backdoor detection, supply-chain security auditing, or mobile device forensics.
---

# Android Firmware Audit & Backdoor Analysis

A skill for security researchers to analyze Android firmware for supply-chain compromises, Zygote-level backdoors, and firmware-level persistence mechanisms.

## When to Use This Skill

Use this skill when:
- Auditing Android firmware images for malicious modifications
- Investigating suspected firmware-level backdoors or supply-chain compromises
- Analyzing `libandroid_runtime.so` or other system libraries for injected code
- Performing mobile forensics on potentially compromised devices
- Detecting Zygote injection attacks or native library tampering
- Investigating protected broadcast receivers or suspicious IPC mechanisms
- Analyzing firmware artifacts from incident response or threat hunting

## Core Analysis Workflow

### 1. Firmware Extraction

Android firmware ships as sparse images. Extract partitions first:

```bash
# Install lpunpack for sparse image handling
pip install lpunpack

# Extract super.img (Android 10+)
lpunpack super.img

# Or extract individual partitions
lpunpack system.img
lpunpack vendor.img
```

After extraction, you'll have partition directories containing the filesystem structure.

### 2. Library Analysis

Focus on `libandroid_runtime.so` in `/system/lib[64]/`:

```bash
# Locate the library
find extracted/ -name "libandroid_runtime.so"

# Check for extra symbols (indicates injected code)
nm -D libandroid_runtime.so | grep -E "(Vndx|log_check|AK_)"

# Disassemble and search for suspicious calls
objdump -d libandroid_runtime.so | grep -A5 "println_native"

# Look for RC4 decryption patterns (common in droppers)
strings libandroid_runtime.so | grep -i "rc4\|decrypt\|aes"
```

### 3. Artifact Detection

Check for these forensic indicators:

**File artifacts:**
- `/data/dalvik-cache/arm*/system@framework@vndx_*.jar@classes.jar`
- `/data/dalvik-cache/arm64*/system@framework@vndx_*.jar@classes.jar`
- Modified `libandroid_runtime.so` with extra symbols
- Static libraries in vendor paths: `vendor/mediatek/proprietary/external/libutils/`

**Logcat indicators:**
- Tag `AK_CPP` (Keenadu-specific)
- Unusual `println_native` call patterns
- Protected broadcast receivers: `com.action.SystemOptimizeService`, `com.action.SystemProtectService`

**Process indicators:**
- `system_server` spawning unexpected DEX loaders
- Apps with elevated permissions they shouldn't have
- Binder transactions to unknown services

### 4. Attack Chain Understanding

Firmware-level backdoors typically follow this pattern:

```
1. Supply-chain compromise → Malicious static lib linked into system .so
2. Zygote injection → Code executes in every app fork
3. Native dropper → RC4-decrypt payload to dalvik-cache
4. DexClassLoader → Load malicious DEX in target process
5. Binder IPC → Server in system_server, clients in apps
6. C2 communication → Encrypted, delayed activation
```

### 5. C2 Analysis

If you find C2 infrastructure, analyze these patterns:

**Host discovery:**
- Base64 → gzip → AES-128-CFB decryption
- Key derivation: `MD5("ota.host.ba60d29da7fd4794b5c5f732916f7d5c")`
- IV: `"0102030405060708"`

**Victim registration:**
- Endpoint: `/ak/api/pts/v4`
- Params: `m=MD5(IMEI)`, `n=w|m` (network type)
- Encryption: AES-128-CFB with key `MD5("ota.api.bbf6e0a947a5f41d7f5226affcfd858c")`

**Module container format:**
```c
struct KeenaduPayload {
    int32_t  version;
    uint8_t  padding[0x100];
    uint8_t  salt[0x20];
    KeenaduChunk config;   // size + data
    KeenaduChunk payload;  // size + data
    KeenaduChunk signature;// size + data
} __packed;
```

## Detection Scripts

Use the bundled scripts for automated analysis:

```bash
# Check firmware for known backdoor indicators
python scripts/check_firmware_artifacts.py <firmware-path>

# Analyze libandroid_runtime.so for injected symbols
python scripts/analyze_runtime_so.py <path-to-so>

# Extract and decrypt C2 payloads (if you have the keys)
python scripts/analyze_c2_payload.py <payload-file>
```

## Remediation Guidance

If compromise is confirmed:

1. **Device-level:**
   - Factory reset (may not remove firmware-level persistence)
   - Flash clean firmware from manufacturer
   - Check bootloader for modifications

2. **Firmware-level:**
   - Obtain clean firmware from official sources
   - Verify firmware signatures before flashing
   - Audit vendor partitions for malicious libraries

3. **Organizational:**
   - Identify affected device models and firmware versions
   - Check for supply-chain compromise in vendor components
   - Implement firmware signing verification
   - Monitor for C2 traffic patterns

## Common False Positives

- Legitimate vendor libraries may have similar naming patterns
- Some OEMs use custom logging mechanisms
- Protected broadcasts exist for legitimate system services
- Always verify with multiple indicators before concluding compromise

## References

- [Keenadu firmware backdoor analysis](https://securelist.com/keenadu-android-backdoor/118913/)
- [lpunpack utility for Android sparse images](https://github.com/unix3dgforce/lpunpack)
- [Android Security Architecture](https://source.android.com/docs/security/architecture)
- [Android Firmware Analysis Guide](https://github.com/androguard/androguard/wiki/Android-Firmware-Analysis)

## Output Format

When presenting analysis results, use this structure:

```
## Firmware Audit Results

### Summary
- Firmware version: [version]
- Device model: [model]
- Compromise status: [confirmed/suspected/clean]

### Findings
- [List of artifacts found]
- [Confidence level for each finding]

### Evidence
- [File paths and hashes]
- [Code snippets or disassembly]
- [Network indicators]

### Recommendations
- [Immediate actions]
- [Long-term remediation]
```

## Safety Notes

- This skill is for defensive security research and incident response
- Do not use techniques to create or deploy backdoors
- Always have proper authorization before analyzing firmware
- Handle extracted payloads in isolated environments
- Report findings to appropriate vendors and CERTs
