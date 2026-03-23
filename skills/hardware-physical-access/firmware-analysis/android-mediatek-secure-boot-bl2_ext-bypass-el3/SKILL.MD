---
name: mediatek-secure-boot-analysis
description: Analyze MediaTek bootloader vulnerabilities, particularly bl2_ext secure-boot bypasses. Use this skill when investigating MediaTek device boot chains, analyzing secure boot verification gaps, triaging boot logs for authentication bypasses, or documenting firmware security issues. Trigger when users mention MediaTek bootloaders, bl2_ext, secure boot bypass, EL3 vulnerabilities, seccfg manipulation, or firmware analysis on MediaTek devices.
---

# MediaTek Secure Boot Analysis

A skill for analyzing MediaTek bootloader vulnerabilities, particularly the bl2_ext secure-boot bypass that allows EL3 code execution when seccfg is unlocked.

## When to Use This Skill

Use this skill when:
- Analyzing MediaTek device boot chains for security vulnerabilities
- Investigating bl2_ext verification gaps or secure boot bypasses
- Triaging boot/expdb logs for authentication status
- Documenting firmware security issues on MediaTek platforms
- Understanding seccfg manipulation and DA-mode operations
- Researching EL3-level vulnerabilities in MediaTek bootloaders

## Safety Warnings

> **Critical**: Early-boot patching can permanently brick devices if offsets are wrong. Always:
> - Keep full dumps of all partitions before modification
> - Maintain a reliable recovery path (EDL/DA access, test points)
> - Test on disposable hardware first
> - Use board-specific logging/UART to validate execution paths

## MediaTek Boot Flow

### Normal Boot Path
```
BootROM → Preloader → bl2_ext (EL3, verified) → TEE → GenieZone (GZ) → LK/AEE → Linux kernel (EL1)
```

### Vulnerable Path (seccfg unlocked)
```
BootROM → Preloader → bl2_ext (EL3, NOT verified) → [attacker-controlled] → TEE/GZ/LK/Kernel (unsigned)
```

**Key Trust Boundary**: bl2_ext executes at EL3 and verifies TEE, GenieZone, LK/AEE, and kernel. If bl2_ext itself is not authenticated, the entire chain collapses.

## Root Cause Analysis

On affected devices, the Preloader does not enforce authentication of the bl2_ext partition when seccfg indicates an "unlocked" state. This allows:

1. Flashing attacker-controlled bl2_ext that runs at EL3
2. Patching the verification policy function to unconditionally report success
3. Loading unsigned TEE/GZ/LK/Kernel images downstream

## Triage Workflow

### Step 1: Dump Boot/Expdb Logs

Capture boot logs around the bl2_ext load phase. Look for these indicators:

```bash
# Search for authentication status
grep -i "img_auth_required" boot.log
grep -i "cert vfy" boot.log
```

### Step 2: Analyze Authentication Status

**Verification SKIPPED** (vulnerable):
```
[PART] img_auth_required = 0
[PART] Image with header, name: bl2_ext, addr: FFFFFFFFh, mode: FFFFFFFFh, size:654944, magic:58881688h
[PART] part: lk_a img: bl2_ext cert vfy(0 ms)
```

**Verification ENFORCED** (not vulnerable via this path):
```
[PART] img_auth_required = 1
[PART] part: lk_a img: bl2_ext cert vfy(127 ms)
```

### Step 3: Check seccfg Status

Use Penumbra or similar DA tools to check target configuration:

```bash
# Check if SBC (Secure Boot Chain) is enabled
# bit 0 set → SBC enabled
```

## Verification Logic Locations

The relevant check typically resides inside the bl2_ext image:

- **Function names**: `verify_img`, `sec_img_auth`, or similar
- **Patch approach**: Force function to return success or bypass verification call entirely
- **Requirements**: Preserve stack/frame setup and return expected status codes

## Practical Analysis Chain

1. **Obtain bootloader partitions** via OTA/firmware packages, EDL/DA readback, or hardware dumping
2. **Identify bl2_ext verification routine** using disassembly/reverse engineering
3. **Analyze patch points** for verification bypass
4. **Document affected components** (TEE, GZ, LK, Kernel)

## Tooling References

### Fenrir (PoC Patching Toolkit)

Reference implementation for Nothing Phone (2a) and CMF Phone 1:

```bash
./build.sh pacman                    # build from bin/pacman.bin
./build.sh pacman /path/to/boot.bin  # build from custom bootloader
./flash.sh                           # flash via fastboot
```

**Supported devices**:
- Nothing Phone (2a) (Pacman) - fully supported
- CMF Phone 1 (Tetris) - partial support

### Penumbra (MTK DA Operations)

Rust crate/CLI for MTK preloader/bootrom interaction:

**Capabilities**:
- Discover MTK USB port
- Load Download Agent (DA) blob
- Issue privileged commands (seccfg lock flipping, partition readback)

**Environment setup**:
```bash
# Linux
sudo apt install libudev-dev
sudo usermod -aG dialout $USER
# Create udev rules or run with sudo
```

## Device-Specific Notes

| Device | Status | Notes |
|--------|--------|-------|
| Nothing Phone (2a) | Confirmed | Pacman, fully supported |
| CMF Phone 1 | Known working | Tetris, incomplete support |
| Vivo X80 Pro | Observed | Did not verify bl2_ext even when locked |
| NothingOS 4 stable | Patched | BP2A.250605.031.A3 re-enabled verification |

## Security Implications

- **EL3 code execution** after Preloader
- **Full chain-of-trust collapse** for rest of boot path
- **Ability to boot unsigned** TEE/GZ/LK/Kernel
- **Persistent compromise** possible via modified boot images

## Analysis Scripts

Use the bundled scripts for common analysis tasks:

```bash
# Analyze boot logs for authentication status
python scripts/analyze-boot-logs.py <boot.log>

# Check seccfg status from DA output
python scripts/check-seccfg-status.py <da-output.json>
```

## References

- [Fenrir – MediaTek bl2_ext secure‑boot bypass](https://github.com/R0rt1z2/fenrir)
- [Penumbra – MTK DA flash/readback & seccfg tooling](https://github.com/shomykohai/penumbra)
- [Cyber Security News – Nothing Phone PoC](https://cybersecuritynews.com/nothing-phone-code-execution-vulnerability/)

## Output Format

When analyzing a MediaTek device, provide:

1. **Device identification** (model, chipset, firmware version)
2. **Boot chain analysis** (normal vs. vulnerable path)
3. **Authentication status** (img_auth_required value, verification time)
4. **Vulnerability assessment** (affected, patched, unknown)
5. **Recommended next steps** (further analysis, tooling, safety precautions)
