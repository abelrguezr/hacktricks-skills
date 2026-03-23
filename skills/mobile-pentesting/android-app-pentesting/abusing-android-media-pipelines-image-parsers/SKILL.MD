---
name: android-media-exploit-research
description: Security research skill for analyzing Android media pipeline vulnerabilities, image parser exploits, and codec-based attack vectors. Use this skill when investigating Android security, analyzing DNG/TIFF parser vulnerabilities, researching 0-click exploit techniques, or auditing media processing services. Trigger this skill for any Android security research involving MediaStore, image codecs, audio decoders, or privileged system services that process media files. Make sure to use this skill whenever the user mentions Android security research, media parser vulnerabilities, DNG exploits, codec exploits, or any investigation of Android system services that process media.
---

# Android Media Pipeline Exploit Research

A skill for security researchers analyzing Android media processing vulnerabilities, image parser exploits, and codec-based attack vectors for legitimate security testing and defense.

## When to Use This Skill

Use this skill when:
- Investigating Android security vulnerabilities in media processing
- Analyzing DNG/TIFF image parser vulnerabilities
- Researching 0-click exploit techniques in Android
- Auditing media processing services (MediaStore, gallery apps, messaging apps)
- Understanding heap exploitation under Android allocators (Scudo, jemalloc)
- Analyzing codec vulnerabilities (Dolby UDC, Quram, etc.)
- Preparing security assessments for Android OEM firmware

## Core Attack Vectors

### 1. MediaStore Privileged Parser Delivery

Modern OEM builds run privileged media indexers that rescan `MediaStore` for AI features, sharing, and widgets.

**Attack Surface:**
- System services with elevated permissions parse media automatically
- WhatsApp, Messages, and other apps drop files into MediaStore
- Privileged services (e.g., `com.samsung.ipservice`) parse without user interaction
- Inherited permissions: full read/write to gallery, ability to drop new media

**Example Detection:**
```bash
# Check file type (DNG disguised as JPEG)
$ file IMG-2025-02-10.jpeg
TIFF image data...

# Inspect embedded opcodes
$ exiftool IMG-2025-02-10.jpeg | grep "Opcode List"
Opcode List 1 : [opcode 23], [opcode 23], ...
```

**Key Insight:** Any image parser reachable through MediaStore becomes remotely reachable if an attacker can convince a target to save media.

### 2. Audio Codec 0-Click Vectors

Messaging stacks auto-decode audio for transcription/search before user opens messages.

**Google Messages → Dolby UDC Path:**
- Incoming RCS/SMS audio handed to Dolby Unified Decoder
- Located in `/vendor/lib64/libcodec2_soft_ddpdec.so`
- Decodes before user interaction (0-click surface)

**Parse Constraints (DD+):**
- Each syncframe has up to 6 blocks
- Each block copies up to `0x1FF` bytes of skip data
- Skip buffer scanned for EMDF: `syncword (0xX8)` + `emdf_container_length (16b)` + variable fields
- `emdf_payload_size` parsed with unbounded `variable_bits(8)` loop
- Payload allocated in per-frame "evo heap" bump allocator

### 3. DNG Opcode Interpreter Vulnerabilities

DNG files embed three opcode lists applied at different decode stages. Vendor implementations often trust attacker-supplied parameters.

#### DeltaPerColumn Plane Bounds Bug

**Vulnerability:**
- Attackers set `plane=5125` and `planes=5123` (Stage-3 only exposes planes 0-2)
- Implementation computes `opcode_last_plane = image_planes + opcode_planes` instead of `plane + count`
- No bounds checking on resulting plane range
- Loop writes delta to `raw_pixel_buffer[plane_index]` with controlled offset

**Primitive:**
- Plane 5125 → offset `5125 * 2 bytes/pixel = 0x2800`
- Each opcode adds 16-bit float value to targeted location
- Precise heap OOB add primitive

#### Turning Increments into Arbitrary Writes

**Exploitation Recipe:**
1. Corrupt Stage-3 `QuramDngImage.bottom/right` using 480 malformed `DeltaPerColumn` operations
2. Future opcodes treat enormous coordinates as in-bounds
3. `MapTable` opcodes (opcode 7) aimed at fake bounds
4. Use substitution table of zeros or `DeltaPerColumn` with `-Inf` deltas to zero regions
5. Apply additional deltas to write exact values
6. Encode hundreds of thousands of writes in DNG metadata without touching process memory

## Heap Exploitation Under Scudo

### Allocator Bucket Behavior

Scudo buckets allocations by size. Identical chunk sizes land in same region.

**0x30-byte Chunk Objects:**
- `QuramDngImage` descriptors (Stage 1/2/3)
- `QuramDngOpcodeTrimBounds`
- Vendor `Unknown` opcodes (ID ≥14, including ID 23)

**Spacing:** 0x40-byte on heap

### Heap Shaping Sequence

1. Stage-1 `Unknown(23)` opcodes (20,000 entries) spray 0x30 chunks, later freed
2. Stage-2 frees opcodes, places new `QuramDngImage` in freed region
3. 240 Stage-2 `Unknown(23)` entries freed, Stage-3 allocates `QuramDngImage` + raw pixel buffer
4. Crafted `TrimBounds` opcode runs first in list 3, allocates raw pixel buffer before freeing Stage-2
5. 640 additional `TrimBounds` entries marked `minVersion=1.4.0.1` (skipped but allocated)

**Result:** Stage-3 raw buffer immediately before Stage-3 `QuramDngImage`, so plane-based overflow flips descriptor fields.

### Vendor Unknown Opcodes as Data Blobs

Samsung sets high bit in vendor opcode IDs (e.g., ID 23), instructing interpreter to allocate but skip execution.

**Abuse Pattern:**
- Opcode list 1 and 2 `Unknown(23)` entries serve as contiguous scratchpads
- Store payload bytes (JOP chain at offset 0xf000, shell command at 0x10000 relative to raw buffer)
- Interpreter treats each object as opcode when list 3 processed
- Commandeering one object's vtable starts executing attacker data

## ASLR Bypass Techniques

### Bogus MapTable Objects

`MapTable` objects are larger than `TrimBounds`, but parser reads extra parameters OOB after layout corruption.

**Bypass Recipe:**
1. Use linear write primitive to partially overwrite `TrimBounds` vtable pointer
2. Craft `MapTable` substitution table mapping lower 2 bytes from neighboring vtable
3. Only low bytes differ between supported builds → single 64K lookup table handles multiple firmware versions and 4KB ASLR slides
4. Patch `TrimBounds` fields (top/left/width/planes) to behave like valid `MapTable`
5. Execute fake opcode over zeroed memory
6. Substitution table pointer references another opcode's vtable → output bytes become leaked low-order addresses
7. Apply additional `MapTable` passes to convert two-byte leaks into offsets toward gadgets

**Target Gadgets:**
- `__ink_jpeg_enc_process_image+64`
- `QURAMWINK_Read_IO2+124`
- `qpng_check_IHDR+624`
- libc's `__system_property_get` entry

## JOP to System() Transition

**Final Exploitation Chain:**

1. `DeltaPerColumn` writes add `0x0100` to offset 0x22 of Stage-3 `QuramDngImage`
2. Raw buffer pointer shifts by 0x10000, now references attacker command string
3. Interpreter executes tail of 1040 `Unknown(23)` opcodes
4. First corrupted entry has vtable replaced with forged table at offset 0xf000
5. `QuramDngOpcode::aboutToApply` resolves `qpng_read_data` (4th entry) from fake table
6. Chained gadgets:
   - Load `QuramDngImage` pointer
   - Add 0x20 to point at raw buffer pointer
   - Dereference, copy result into `x19/x0`
   - Jump through GOT slots rewritten to `system`
7. Final gadget executes `system(<shell command>)` inside `com.samsung.ipservice`

## Allocator Variant Considerations

**Two Payload Families:**
- **jemalloc:** Relies on size-class control via tile/subIFD sizing
- **scudo:** Disabled quarantine makes 0x30-byte freelist reuse deterministic

**Shared Primitives:**
- DeltaPerColumn bug → MapTable zero/write → bogus vtable → JOP

## Security Testing Methodology

### 1. Identify Target Services

```bash
# Find media processing services
adb shell dumpsys package | grep -i "media\|gallery\|image"

# Check for privileged services
adb shell dumpsys activity services | grep -i "ipservice\|mediastore"

# List loaded libraries in target process
adb shell cat /proc/<pid>/maps | grep -i "codec\|quram\|libimage"
```

### 2. Test Parser Behavior

```bash
# Send test DNG file
adb push test.dng /sdcard/Download/

# Trigger MediaStore scan
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d "file:///sdcard/Download/test.dng"

# Monitor for crashes
adb logcat | grep -i "quram\|dng\|opcode"
```

### 3. Analyze Heap Layout

```bash
# Dump heap state (requires root)
cat /proc/<pid>/maps

# Check allocator type
cat /proc/<pid>/auxv | grep -i "scudo\|jemalloc"
```

### 4. Validate Exploitation Primitives

- **OOB Write:** Verify plane bounds bug with controlled DNG
- **Heap Adjacency:** Confirm chunk reuse patterns
- **ASLR Bypass:** Test address leakage via MapTable
- **Code Execution:** Validate JOP chain to system()

## Defensive Recommendations

### For OEMs/Developers

1. **Bounds Checking:** Always validate plane indices, opcode parameters, and buffer sizes
2. **Input Sanitization:** Reject malformed DNG files with suspicious opcode counts
3. **Sandboxing:** Run media parsers in restricted sandboxes with minimal permissions
4. **Allocator Hardening:** Enable Scudo quarantine, use hardened allocators
5. **Code Signing:** Verify media processing libraries are signed and unmodified
6. **Rate Limiting:** Limit automatic media parsing frequency

### For Security Researchers

1. **Responsible Disclosure:** Report vulnerabilities to vendor before public disclosure
2. **Reproducible POCs:** Create minimal, reliable proof-of-concept files
3. **Version Testing:** Test across multiple firmware versions and allocator variants
4. **Documentation:** Document exploitation chain clearly for vendor remediation

## References

- [Project Zero – A look at an Android ITW DNG exploit](https://projectzero.google/2025/12/android-itw-dng.html)
- [Project Zero – Pixel 0-click: CVE-2025-54957 in Dolby UDC](https://projectzero.google/2026/01/pixel-0-click-part-1.html)

## Test Cases

### Test Case 1: Explain MediaStore Attack Vector
**Prompt:** "Explain how an attacker could exploit Android MediaStore to trigger privileged parser execution without user interaction."

**Expected Output:**
- Description of MediaStore automatic scanning
- Privileged service permissions
- Delivery via messaging apps
- Example with DNG disguised as JPEG

### Test Case 2: Analyze DNG Opcode Vulnerability
**Prompt:** "Analyze the DeltaPerColumn plane bounds vulnerability in DNG parsers. What makes it exploitable?"

**Expected Output:**
- Explanation of plane bounds bug
- How OOB write primitive works
- Heap corruption potential
- Connection to arbitrary write capability

### Test Case 3: Heap Shaping Under Scudo
**Prompt:** "Describe how to shape the heap under Scudo for Android DNG exploit development."

**Expected Output:**
- Scudo bucket behavior
- 0x30-byte chunk objects
- Heap shaping sequence
- Achieving deterministic adjacency

### Test Case 4: ASLR Bypass Technique
**Prompt:** "How can an attacker bypass ASLR when exploiting Android image parsers?"

**Expected Output:**
- MapTable substitution table technique
- Low-byte address leakage
- Gadget offset calculation
- Multi-version compatibility

### Test Case 5: Security Testing Methodology
**Prompt:** "What steps should a security researcher take to test Android media parser vulnerabilities?"

**Expected Output:**
- Service identification
- Parser behavior testing
- Heap layout analysis
- Primitive validation
- Responsible disclosure practices
