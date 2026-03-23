---
name: zero-click-exploit-chain-audit
description: Security audit skill for analyzing zero-click exploit chains in messaging apps and image parsers. Use this skill whenever the user mentions security auditing, messaging app vulnerabilities, image parser exploits, zero-click attacks, WhatsApp linked-device protocols, RawCamera vulnerabilities, DNG parsing, or any combination of protocol flaws and memory corruption chains. This skill helps security researchers understand attack surfaces, design test methodologies, and create hardening recommendations for messaging applications and media pipelines.
---

# Zero-Click Exploit Chain Audit

A security research skill for analyzing and auditing zero-click exploit chains that combine messaging app protocol vulnerabilities with image parser memory corruption bugs.

## When to Use This Skill

Use this skill when:
- Auditing messaging applications for zero-click vulnerabilities
- Analyzing linked-device or companion protocol implementations
- Testing image parser vulnerabilities (DNG, RAW, vendor-specific formats)
- Designing security assessments for media pipeline components
- Creating hardening recommendations for messaging apps
- Researching exploit chain methodologies for defensive purposes

## Core Concepts

### The Attack Chain Pattern

Zero-click exploits typically follow this pattern:

1. **Protocol Flaw** → Coerces app into fetching untrusted content without user interaction
2. **Remote Content Delivery** → Forces the app to load attacker-controlled media
3. **Parser Vulnerability** → Triggers memory corruption in shared OS image pipeline
4. **Exploitation** → Leaks information and chains gadgets to escape sandbox

### Key Attack Surfaces

#### Messaging App Protocols
- **Linked-device/companion protocols** (WhatsApp, Signal, Telegram)
- **Sync actions** that carry URLs or media references
- **Device metadata** fields that cross trust boundaries
- **Action descriptors** with minimal validation

#### Image Parser Vulnerabilities
- **RawCamera** (iOS/macOS) - DNG/RAW processing
- **Vendor parsers** (Samsung libimagecodec, libOneUI_ImageDecoder)
- **Shared OS media pipelines** (ImageIO, CGImageSource)
- **Auto-preview mechanisms** (thumbnails, notifications, share sheets)

## Audit Workflow

### Phase 1: Protocol Analysis

1. **Capture legitimate traffic**
   - Attach debugger or Frida to client
   - Hook post-decryption handlers
   - Dump decoded protocol payloads
   - Document available action types and parameters

2. **Identify trust boundary crossings**
   - Look for fields carrying URLs without allow-lists
   - Check for `http_url`, `thumbnail_uri`, `download_url`, `render_html`
   - Verify device pairing validation on high-impact fields
   - Test if sender authentication is enforced

3. **Map the attack surface**
   ```
   Protocol Field → Trust Assumption → Validation Check → Risk Level
   resource_url    → Trusted device   → None             → HIGH
   media_type      → Trusted device   → MIME check       → MEDIUM
   device_id       → Paired device    → Key verification → LOW
   ```

### Phase 2: Remote Content Primitive Testing

1. **Forge test actions**
   - Reuse observed protocol schema
   - Modify only attacker-controlled fields
   - Test with benign URLs first
   - Verify the fetch occurs without UI

2. **Instrument the fetch**
   - Monitor HTTP(S) requests from the app
   - Check which renderer handles the content (WKWebView, ImageIO, etc.)
   - Verify MIME type handling
   - Test different content types (HTML, images, etc.)

3. **Validate zero-click behavior**
   - Confirm no notifications or prompts
   - Verify background execution
   - Test across different app states (foreground, background, locked)

### Phase 3: Parser Vulnerability Testing

1. **Identify parser entry points**
   - Trace which system components handle the fetched content
   - Check if content reaches RawCamera, vendor decoders, or other parsers
   - Map the call chain from app to system parser

2. **Fuzz the parser**
   - Use malformed DNG/RAW files as test corpus
   - Target specific metadata fields:
     - `TileByteCounts` / `StripByteCounts`
     - `TileOffsets` / `StripOffsets`
     - `ImageWidth` / `ImageLength`
     - `BitsPerSample`
     - `OpcodeList3` entries
   - Monitor for crashes, hangs, or memory errors

3. **Analyze crashes**
   - Check crash logs for OOB read/write patterns
   - Look for heap metadata corruption
   - Identify register control opportunities
   - Document reliable primitives

### Phase 4: Chain Validation

1. **End-to-end test**
   - Combine protocol primitive with parser payload
   - Verify the full chain executes without user interaction
   - Test on target device(s)
   - Document success criteria

2. **Reliability assessment**
   - Run multiple iterations
   - Test across different app versions
   - Check for race conditions
   - Measure success rate

## Hardening Recommendations

### Protocol Security

- **Enforce strict allow-lists** for all linked-device actions
- **Require device pairing proof** (signed payloads) for high-impact fields
- **Bind actions to per-device keys** and reject unknown senders
- **Validate URL schemes** against allow-lists or signed blobs
- **Implement replay protection** with nonces or timestamps

### Media Pipeline Security

- **Restrict MIME types** to approved list
- **Explicitly reject RAW/DNG** unless feature is required
- **Isolate parser execution** in sandboxed processes
- **Use memory-safe parsers** where available
- **Implement size limits** to prevent resource exhaustion

### Parser Hardening

- **Maintain fuzzing corpora** of malformed files
- **Run regression tests** after every update
- **Enable sanitizers** (ASan, MTE) in test builds
- **Automate crash triage** with symbolicated logs
- **Monitor for heap metadata corruption** patterns

## Test Case Templates

### Protocol Test

```
Test: Linked-device action with unvalidated URL
Setup: Capture legitimate sync action, modify resource_url
Expected: App fetches URL without user interaction
Risk: HIGH - Zero-click remote content delivery
```

### Parser Test

```
Test: Malformed DNG with conflicting TileOffsets
Setup: Create DNG with valid headers but invalid offsets
Expected: Parser crash or memory corruption
Risk: HIGH - Memory corruption primitive
```

### Chain Test

```
Test: Protocol action → HTML → DNG → Parser crash
Setup: Full chain from protocol to parser
Expected: Zero-click crash on target device
Risk: CRITICAL - Complete exploit chain
```

## Safety Guidelines

- **Only test on devices you own or have explicit authorization for**
- **Use isolated test environments** (VMs, test devices)
- **Document all findings** for responsible disclosure
- **Coordinate with vendors** before public disclosure
- **Follow responsible disclosure timelines**

## References

- DNGerousLINK: WhatsApp 0-Click Exploits on iOS and Samsung Devices
- CVE-2025-55177: WhatsApp linked-device authentication bypass
- CVE-2025-43300: RawCamera DNG parser vulnerability
- CVE-2025-21043: Samsung vendor parser out-of-bounds write

## Output Format

When providing audit results, use this structure:

```
# Audit Report: [Target Application]

## Executive Summary
[Brief overview of findings]

## Attack Surface Analysis
- Protocol components: [list]
- Parser components: [list]
- Trust boundaries: [list]

## Test Results
| Test ID | Component | Result | Risk |
|---------|-----------|--------|------|
| T-001   | Protocol  | PASS   | HIGH |
| T-002   | Parser    | FAIL   | MEDIUM |

## Recommendations
1. [Priority 1]
2. [Priority 2]
3. [Priority 3]

## Technical Details
[Detailed findings with reproduction steps]
```

## Next Steps

After initial audit:
1. Prioritize findings by risk and exploitability
2. Create detailed reproduction cases for critical issues
3. Develop hardening patches or mitigations
4. Plan responsible disclosure timeline
5. Schedule follow-up testing after fixes
