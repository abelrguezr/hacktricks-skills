---
name: mediatek-carbonara-exploit
description: MediaTek XFlash Carbonara DA2 hash bypass exploit for firmware analysis and security research. Use this skill whenever analyzing MediaTek device firmware, investigating Download Agent vulnerabilities, performing pre-OS security research, testing for Carbonara/heapb8 vulnerabilities, or working with mtkclient/penumbra tools. Trigger on any mention of MediaTek, XFlash, DA1, DA2, Download Agent, preloader, firmware security, or boot exploit analysis.
---

# MediaTek Carbonara Exploit Guide

## What This Skill Does

This skill helps security researchers understand, detect, and safely test for the Carbonara vulnerability in MediaTek XFlash Download Agents. It covers the exploit mechanics, detection methods, and hardening recommendations.

## When to Use This Skill

- Analyzing MediaTek device firmware for security vulnerabilities
- Investigating Download Agent (DA1/DA2) integrity bypass techniques
- Performing pre-OS security research on MediaTek devices
- Testing devices for Carbonara or heapb8 vulnerability presence
- Working with mtkclient, penumbra, or similar MediaTek exploit frameworks
- Understanding MediaTek boot chain security boundaries

## Trust Boundary: DA1 → DA2

```
BootROM/Preloader → DA1 (signed) → DA2 (USB, integrity-checked) → Payload
```

- **DA1**: Signed/loaded by BootROM. When Download Agent Authorization (DAA) is enabled, only signed DA1 runs.
- **DA2**: Sent over USB. DA1 receives size, load address, and SHA-256, then hashes received DA2 and compares to expected hash stored in RAM.
- **Weakness**: Unpatched loaders don't sanitize DA2 load address/size, keeping the expected hash writable in memory.

## Carbonara Exploit Flow

### The "Two BOOT_TO" Trick

1. **First `BOOT_TO`**: Enter DA1→DA2 staging flow. DA1 allocates memory, prepares DRAM, and exposes the expected-hash buffer in RAM.

2. **Hash-slot overwrite**: Send a payload that scans DA1 memory for the stored DA2-expected hash and overwrites it with SHA-256 of the attacker-modified DA2. This leverages user-controlled load address to write where the hash resides.

3. **Second `BOOT_TO` + digest**: Trigger another `BOOT_TO` with patched DA2 metadata and send the raw 32-byte digest matching the modified DA2. DA1 recomputes SHA-256, compares against the patched expected hash, and jumps into attacker code.

### Why This Works

Because load address/size are attacker-controlled, the same primitive can write anywhere in memory (not just the hash buffer), enabling:
- Early-boot implants
- Secure-boot bypass helpers
- Malicious rootkits
- Arbitrary memory writes with cache invalidation handled by DA

## Detection: Patched vs Vulnerable Loaders

### Hardened Loaders (Patched)

- Updated DAs hardcode DA2 load address to `0x40000000`
- Ignore the address the host supplies
- Writes cannot reach the DA1 hash slot (~0x200000 range)
- Hash remains computed but no longer attacker-writable

### Vulnerable Loaders (Unpatched)

- Accept user-supplied DA2 load address/size
- Keep expected hash writable in memory
- Commonly expose writable hash slots around offsets like `0x22dea4` in V5 DA1

### Detection Methods

```python
# mtkclient/penumbra scan DA1 for address-hardening patterns
# If found, Carbonara is skipped
# Old DAs expose writable hash slots and remain exploitable
```

**V5 vs V6**: Some V6 (XML) loaders still accept user-supplied addresses; newer V6 binaries usually enforce fixed address and are immune unless downgraded.

## Minimal PoC Pattern (mtkclient-style)

```python
if self.xsend(self.Cmd.BOOT_TO):
    # Payload replicates the paid-tool blob that patches expected-hash buffer
    payload = bytes.fromhex("a4de2200000000002000000000000000")
    if self.xsend(payload) and self.status() == 0:
        import hashlib
        # Send raw bytes (not hex) so DA1 compares against patched buffer
        da_hash = hashlib.sha256(self.daconfig.da2).digest()
        if self.xsend(da_hash):
            self.status()
            self.info("All good!")
```

### Key Implementation Details

- `payload` replicates the blob that patches the expected-hash buffer inside DA1
- `sha256(...).digest()` sends raw bytes (not hex string)
- DA2 can be any attacker-built image
- Choosing load address/size allows arbitrary memory placement
- Cache invalidation is handled by DA

## Post-Carbonara: heapb8 Vulnerability

MediaTek patched Carbonara, but a newer vulnerability **heapb8** targets the DA2 USB file download handler on patched V6 loaders:

- Gives code execution even when `boot_to` is hardened
- Abuses heap overflow during chunked file transfers
- Seizes DA2 control flow
- Public in Penumbra/mtk-payloads
- Demonstrates Carbonara fixes don't close all DA attack surface

## Triage and Hardening Recommendations

### Vulnerability Indicators

Devices are vulnerable when:
- DA2 address/size are unchecked
- DA1 keeps the expected hash writable in memory

Devices are mitigated when:
- Later Preloader/DA enforces address bounds
- Hash is kept immutable
- DAA is enabled with proper validation

### Hardening Steps

1. **Enable DAA** (Download Agent Authorization)
2. **Validate BOOT_TO parameters**: bounds checking + authenticity of DA2
3. **Hardcode DA2 load address** to prevent arbitrary writes
4. **Keep hash immutable** in memory
5. **Close only the hash patch without bounding the load** still leaves arbitrary write risk

## Research Workflow

### Step 1: Identify Device and DA Version

```bash
# Use mtkclient to enumerate device info
mtkclient --info
# Check DA version (V5 vs V6)
```

### Step 2: Scan for Carbonara Vulnerability

```bash
# mtkclient/penumbra will auto-detect
# Look for writable hash slot patterns
# Check if address hardening is present
```

### Step 3: Test Exploit (Authorized Research Only)

```bash
# Only test on devices you own or have explicit authorization
# Follow responsible disclosure practices
```

### Step 4: Document Findings

- Record DA version and vulnerability status
- Note any custom patches or mitigations
- Track heapb8 presence on patched devices

## References

- [Carbonara: The MediaTek exploit nobody served](https://shomy.is-a.dev/blog/article/serving-carbonara)
- [Carbonara exploit documentation](https://shomy.is-a.dev/penumbra/Mediatek/Exploits/Carbonara)
- [Penumbra Carbonara source code](https://github.com/shomykohai/penumbra/blob/main/core/src/exploit/carbonara.rs)
- [heapb8: exploiting patched V6 Download Agents](https://blog.r0rt1z2.com/posts/exploiting-mediatek-datwo/)

## Important Notes

- **Legal**: Only test on devices you own or have explicit authorization to test
- **Safety**: Pre-OS exploits can brick devices; proceed with caution
- **Disclosure**: Follow responsible disclosure practices for vulnerabilities
- **Updates**: MediaTek regularly patches these vulnerabilities; check for latest DA versions
