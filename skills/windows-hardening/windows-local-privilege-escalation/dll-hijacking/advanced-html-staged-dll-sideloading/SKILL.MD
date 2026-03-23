---
name: ashen-lepus-dll-sideloading-analysis
description: Analyze and detect Ashen Lepus (WIRTE) advanced DLL side-loading attacks with HTML-staged payloads. Use this skill whenever investigating suspicious DLL loading patterns, HTML-based C2 staging, or Middle Eastern diplomatic targeting campaigns. Trigger for any analysis of netutils.dll, srvcli.dll, dwampi.dll, wtsapi32.dll, or propsys.dll side-loading, HTML comment-based payload extraction, or Rclone-based exfiltration patterns.
---

# Ashen Lepus DLL Side-Loading Analysis

A skill for analyzing the advanced multi-stage DLL side-loading technique weaponized by Ashen Lepus (aka WIRTE) against Middle Eastern diplomatic networks.

## What This Skill Does

This skill helps security analysts:
- Understand the Ashen Lepus multi-stage side-loading chain
- Detect HTML-staged C2 payloads with dynamic tag extraction
- Identify Rclone-based exfiltration patterns
- Generate detection rules for the technique
- Analyze captured traffic for the specific patterns

## Attack Chain Overview

```
Decoy EXE → AshenLoader (DLL sideload) → HTML C2 → AshenStager → 
AshenOrchestrator → Modules (persistence, recon, exfil)
```

### Stage 1: Initial Side-Loading
- Archive-based social engineering delivers EXE + malicious DLL + decoy PDF
- EXE side-loads DLL named after trusted library (netutils.dll, srvcli.dll, dwampi.dll, wtsapi32.dll, propsys.dll)
- AshenLoader performs host recon, encrypts with AES-CTR, POSTs to API-looking paths

### Stage 2: HTML Staging
- C2 responds with `<headerp>...</headerp>` containing Base64/AES-CTR encrypted AshenStager
- Only delivers payload when IP geolocates to target region AND User-Agent matches
- Other clients receive benign HTML (news/health sites)

### Stage 3: Second Side-Load
- AshenStager deploys with another legitimate binary importing wtsapi32.dll
- Fetches HTML with `<article>...</article>` containing AshenOrchestrator

### Stage 4: Modular Controller
- AshenOrchestrator decodes Base64 JSON config
- `tg` + `au` fields → AES key → decrypts `xrk` → XOR key for modules
- Modules delivered via HTML comments redirecting to arbitrary tags

## HTML Container Parsing Pattern

The technique uses dynamic tag names to evade static detection:

```csharp
<!-- TAG: <customtag> -->
<customtag>BASE64_PAYLOAD_HERE</customtag>
```

Extraction logic:
1. Parse HTML comment for tag name: `<!-- TAG: <xyz> -->`
2. Extract content from `<xyz>...</xyz>`
3. Base64 decode
4. AES-CTR decrypt with embedded key/nonce
5. XOR with derived key if present

## Detection Pivots

### Process Monitoring
- Alert on signed processes loading DLLs from user-writable paths
- Focus on DLL names: netutils, srvcli, dwampi, wtsapi32, propsys
- Use: `Get-ProcessMitigation -Module` + Procmon filters

### Network Detection
- HTTPS responses with large Base64 blobs in unusual HTML tags
- HTML comments with `<!-- TAG: <xyz> -->` pattern
- Base64 strings inside `<script>` blocks (HTML smuggling variant)
- C2 redirects that only respond to exact User-Agent strings

### Persistence Detection
- Scheduled tasks running svchost.exe with non-service arguments:
  - `WindowsDefenderUpdate\Windows Defender Updater`
  - `WindowsServicesUpdate\Windows Services Updater`
  - `Automatic Windows Update`

### Exfiltration Detection
- Rclone binaries outside IT-managed locations
- New rclone.conf files pointing to unknown HTTPS endpoints
- Sync jobs from `C:\Users\Public\` directories

## Scripts

### parse_html_staging.py
Extracts payloads from HTML-staged C2 responses using the Ashen Lepus pattern.

### generate_detection_rules.py
Generates Sigma/YARA rules for the technique.

## Usage Examples

### Analyzing a Suspicious HTML Response
```
Use parse_html_staging.py with the captured HTML to extract any embedded payloads
Check for the <!-- TAG: <xyz> --> comment pattern
Look for Base64 content in unusual tags
```

### Hunting in Your Environment
```
1. Search for scheduled tasks matching the persistence patterns
2. Monitor for DLL loads from user-writable paths
3. Inspect HTTPS responses for Base64 blobs in HTML
4. Check for Rclone in unexpected locations
```

### Generating Detection Rules
```
Run generate_detection_rules.py to create:
- Sigma rules for process monitoring
- YARA rules for payload detection
- Network detection patterns
```

## Key Indicators

### DLL Names to Watch
- netutils.dll
- srvcli.dll
- dwampi.dll
- wtsapi32.dll
- propsys.dll

### C2 Patterns
- Paths: `/api/v1/account`, `/api/v2/account`
- Parameters: `token=`, `id=`, `q=`, `auth=`
- User-Agent pinning (exact match required)
- Geo-fenced responses

### HTML Patterns
- `<!-- TAG: <xyz> -->` comments
- `<headerp>`, `<article>`, or dynamic tags with Base64
- Base64 in `<script>` blocks

### Persistence Tasks
- `C:\Windows\System32\Tasks\Windows\WindowsDefenderUpdate\`
- `C:\Windows\System32\Tasks\Windows\WindowsServicesUpdate\`
- `C:\Windows\System32\Tasks\Automatic Windows Update`

## References

- [Unit42: Ashen Lepus AshTag Malware Suite](https://unit42.paloaltonetworks.com/hamas-affiliate-ashen-lepus-uses-new-malware-suite-ashtag/)
- [Talos: HTML Smuggling Evasion Techniques](https://blog.talosintelligence.com/hidden-between-the-tags-insights-into-evasion-techniques-in-html-smuggling/)
- [Check Point: WIRTE 2024 Campaigns](https://research.checkpoint.com/2024/hamas-affiliated-threat-actor-expands-to-disruptive-activity/)
- [OWN-CERT: WIRTE Analysis](https://www.own.security/en/ressources/blog/wirte-analyse-campagne-cyber-own-cert)

## Important Notes

- This skill is for **defensive security analysis only**
- The techniques described are for understanding adversary TTPs
- Detection rules should be tested in controlled environments
- Always follow your organization's security policies when investigating
