---
name: sips-icc-oob-write-exploit
description: How to understand, test, and detect the macOS sips ICC profile out-of-bounds write vulnerability (CVE-2024-44236). Use this skill whenever the user mentions ICC profiles, sips vulnerability, CVE-2024-44236, macOS image processing exploits, heap corruption in color profiles, or needs to generate malicious ICC test files for security research. Also trigger for YARA rule creation for ICC anomalies, macOS security patching verification, or when analyzing embedded color profile attacks.
---

# SIPS ICC Profile OOB Write Exploit (CVE-2024-44236)

A skill for understanding, testing, and detecting the out-of-bounds zero-write vulnerability in Apple's Scriptable Image Processing System (sips) ICC profile parser.

## What This Skill Does

This skill helps you:
- Generate malicious ICC profile test files for security research
- Understand the heap corruption mechanism and exploitation chain
- Create YARA detection rules for the vulnerability
- Verify patching status and implement mitigations
- Analyze embedded ICC profile attacks in images

## Quick Start

### Generate a Test ICC Profile

Run the bundled PoC generator to create a malicious ICC file:

```bash
python scripts/generate_evil_icc.py output/evil.icc
```

This creates a minimal ICC profile with the `offsetToCLUT == tagDataSize` condition that triggers the OOB write.

### Verify the Vulnerability (Research Only)

On a vulnerable macOS system (15.0.1, sips-307):

```bash
sips --verifyColor output/evil.icc
# or
sips -s format png payload.jpg --out out.png
```

> ⚠️ **Warning**: Only test on isolated, vulnerable systems you own. This can cause crashes or code execution.

## Vulnerability Overview

### The Bug

The vulnerability is in the `lutAToBType` (`mAB `) and `lutBToAType` (`mBA `) tag handlers in sips-307:

```c
if (offsetToCLUT <= tagDataSize) {
    // BAD: zero 16 bytes starting at offsetToCLUT
    for (uint32_t i = offsetToCLUT; i < offsetToCLUT + 16; i++)
        buffer[i] = 0;  // no bounds check!
}
```

When `offsetToCLUT == tagDataSize`, the parser writes **16 bytes past the allocated buffer**.

### Exploitation Chain

1. **Craft malicious ICC** with `offsetToCLUT == tagDataSize`
2. **Trigger parsing** via any sips operation (Preview, QuickLook, Mail, Safari)
3. **Heap metadata corruption** on nano_zone allocator
4. **Arbitrary write** via poisoned free list
5. **Vtable overwrite** → ROP chain execution

### Impact

- **CVSS 7.8** - Remote code execution
- Bypasses Gatekeeper (embedded in benign images)
- Affects: Preview, QuickLook, Safari, Mail attachments
- Patched: macOS 15.2 / 14.7.1 (Oct 30, 2024)

## Detection

### YARA Rule

Use the bundled YARA rule to detect malicious ICC profiles:

```bash
yara -r scripts/icc_mab_anomaly.yara /path/to/files/
```

The rule checks for:
- Valid ICC header (`acsp` magic)
- `mAB ` or `mBA ` tags
- `offsetToCLUT == tagDataSize` condition

### Manual Verification

Check if a system is patched:

```bash
# Check macOS version
sw_vers

# Check sips version (vulnerable: 307 on 15.0.1)
# Patched in 15.2 / 14.7.1+
```

### DFIR Indicators

Look for in unified log:
- Recent `sips --verifyColor` execution
- `ColorSync` library loads by sandboxed apps
- Unexpected Preview/QuickLook spawns

## Mitigation

### Immediate Actions

1. **Patch**: Update to macOS ≥ 15.2 / 14.7.1 or iOS/iPadOS ≥ 18.1
2. **Strip ICC profiles** from untrusted images:
   ```bash
   exiftool -icc_profile= -overwrite_original <file>
   ```
3. **Deploy YARA rule** on email gateways and EDR
4. **Sandbox** Preview/QuickLook for unknown content

### Long-term Hardening

- Run image processing in isolated VMs
- Monitor for sips/ColorSync anomalies
- Implement file type validation before processing

## Test Cases

### Case 1: Basic OOB Trigger

```bash
python scripts/generate_evil_icc.py test1.icc
sips --verifyColor test1.icc  # Should crash on vulnerable systems
```

### Case 2: Embedded in Image

```bash
# Create a test image with embedded malicious ICC
python scripts/embed_icc_in_image.py input.jpg test1.icc output.jpg
sips -s format png output.jpg --out out.png
```

### Case 3: YARA Detection

```bash
yara scripts/icc_mab_anomaly.yara test1.icc
# Should match: ICC_mAB_offsetToCLUT_anomaly
```

## References

- **ZDI-24-1445**: Trend Micro advisory on CVE-2024-44236
  https://www.zerodayinitiative.com/advisories/ZDI-24-1445/
- **Apple HT213981**: macOS Sonoma 15.2 security content
  https://support.apple.com/en-us/HT213981
- **CVE-2025-24185**: Related variant (patched April 2025)

## Related Skills

- `icc-profile-analysis` - Deep ICC profile parsing and analysis
- `macos-heap-exploitation` - nano_zone allocator exploitation techniques
- `yara-rule-creation` - Writing detection rules for file-based attacks

## Notes

- This skill is for **security research and defensive purposes only**
- Always test on systems you own or have explicit authorization for
- The PoC generator creates files that can crash vulnerable systems
- Keep your test environment isolated from production networks
