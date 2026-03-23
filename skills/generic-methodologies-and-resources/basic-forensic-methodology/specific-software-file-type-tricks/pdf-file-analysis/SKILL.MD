---
name: pdf-forensics-analysis
description: Analyze PDF files for security forensics, CTF challenges, and malicious content detection. Use this skill whenever the user needs to examine a PDF file for hidden data, malicious scripts, embedded files, or suspicious constructs. Trigger on requests involving PDF analysis, PDF forensics, PDF security review, suspicious PDF investigation, CTF PDF challenges, or any task requiring deep inspection of PDF structure and content.
---

# PDF Forensics Analysis

A comprehensive skill for analyzing PDF files for security forensics, CTF challenges, and malicious content detection.

## When to Use This Skill

Use this skill when:
- Investigating a suspicious PDF file
- Solving CTF challenges involving PDF forensics
- Performing security reviews of PDF documents
- Looking for hidden data, steganography, or malicious content in PDFs
- Analyzing PDF structure for anomalies or obfuscation
- Extracting embedded files or metadata from PDFs

## Quick Triage Workflow

### Step 1: Initial Assessment

Start with fast keyword statistics to identify potential issues:

```bash
# Install tools if needed
pip install pdfid pdf-parser peepdf

# Quick triage - keyword statistics
pdfid.py <suspicious.pdf>

# Check file type (may reveal polyglot files)
file <suspicious.pdf>

# Look for multiple EOF markers (incremental updates)
grep -c '%%EOF' <suspicious.pdf>
```

### Step 2: Deep Inspection

Use pdf-parser for interactive or automatic analysis:

```bash
# Interactive mode - explore object tree
pdf-parser.py -f <suspicious.pdf>

# Automatic report generation
pdf-parser.py -a <suspicious.pdf>

# Search for specific objects
pdf-parser.py -search "/JS" -raw <suspicious.pdf>
```

### Step 3: Extract Embedded Content

```bash
# List embedded files
peepdf "open <suspicious.pdf>" "objects embeddedfile"

# Extract specific embedded objects
peepdf "open <suspicious.pdf>" "objects embeddedfile" "extract <obj-num>" -o dumps/

# Extract all streams
pdf-parser.py -extract <suspicious.pdf>
```

### Step 4: Decrypt if Needed

```bash
# Remove password protection
qpdf --password='<password>' --decrypt <encrypted.pdf> <clean.pdf>

# Linearize and remove unreferenced objects
qpdf --qdf --remove-unreferenced <suspicious.pdf> <clean.pdf>
```

## Common Malicious Constructs to Hunt

Search for these keywords in PDF content:

| Object | Description | Risk Level |
|--------|-------------|------------|
| `/OpenAction`, `/AA` | Auto-exec on open | High |
| `/JS`, `/JavaScript` | Embedded JavaScript | High |
| `/Launch`, `/SubmitForm` | External process launchers | High |
| `/URI`, `/GoToE` | URL redirects | Medium |
| `/EmbeddedFile`, `/Filespec` | File attachments | High |
| `/RichMedia`, `/Flash`, `/3D` | Multimedia objects | Medium |
| `/ObjStm`, `/XFA`, `/AcroForm` | Object streams/forms | Medium |
| Multiple `%%EOF` | Incremental updates | Medium |

### Suspicious String Patterns

When combined with malicious keywords, these strings warrant deeper analysis:
- `powershell`, `cmd.exe`, `calc.exe`
- `base64` encoded content
- `http://`, `https://` (especially with suspicious domains)
- `mshta`, `wscript`, `cscript`
- `certutil`, `bitsadmin`

## Hidden Data Locations

Check these areas for concealed content:

1. **Invisible layers** - Objects with zero opacity or outside viewport
2. **XMP metadata** - Adobe's metadata format often contains hidden info
3. **Incremental generations** - Data appended after signing
4. **Same-color text** - Text matching background color
5. **Text behind images** - Overlapping objects
6. **Non-displayed comments** - Annotation objects
7. **Polyglot files** - Valid PDF + another format (e.g., Word with macros)

## Recent Attack Techniques (2023-2025)

### MalDoc in PDF Polyglot (2023)
- MHT-based Word document appended after `%%EOF`
- File is both valid PDF and DOC
- Contains `<w:WordDocument>` string
- AV engines parsing only PDF layer miss the macro

**Detection:**
```bash
grep -a '<w:WordDocument>' <suspicious.pdf>
```

### Shadow-Incremental Updates (2024)
- Second `/Catalog` with malicious `/OpenAction`
- First revision appears benign and signed
- Bypasses tools inspecting only first xref table

**Detection:**
```bash
# Count catalog objects
grep -c '/Catalog' <suspicious.pdf>

# Check for multiple Prev offsets
grep '/Prev' <suspicious.pdf>
```

### Font Parsing UAF (CVE-2024-30284)
- Vulnerable CoolType.dll function
- Triggered from embedded CIDType2 fonts
- Remote code execution when opened
- Patched in APSB24-29, May 2024

## YARA Rule Template

Use this template for custom detection rules:

```yara
rule Suspicious_PDF_AutoExec {
    meta:
        description = "Generic detection of PDFs with auto-exec actions and JS"
        author      = "Your Name"
        last_update = "2025-07-20"
    strings:
        $pdf_magic = { 25 50 44 46 }          // %PDF
        $aa        = "/AA" ascii nocase
        $openact   = "/OpenAction" ascii nocase
        $js        = "/JS" ascii nocase
        $launch    = "/Launch" ascii nocase
        $embedded  = "/EmbeddedFile" ascii nocase
    condition:
        $pdf_magic at 0 and (
            ($aa and $js) or 
            ($openact and $js) or 
            $launch or 
            $embedded
        )
}
```

## Defensive Recommendations

### For Enterprise Environments

1. **Patch management** - Keep Acrobat/Reader on latest Continuous track
2. **Gateway sanitization** - Use `pdfcpu sanitize` or `qpdf --qdf --remove-unreferenced`
3. **Content Disarm & Reconstruction (CDR)** - Convert to images or PDF/A in sandbox
4. **Block risky features** - Disable JavaScript, multimedia, 3D rendering in Reader
5. **User education** - Train on social engineering (invoice/resume lures)

### For Individual Analysis

1. **Never open suspicious PDFs directly** - Use sandboxed environments
2. **Static analysis first** - Always triage before opening
3. **Check multiple tools** - Different tools catch different issues
4. **Preserve evidence** - Work on copies, maintain chain of custody

## Tool Reference

| Tool | Purpose | Install |
|------|---------|--------|
| `pdfid.py` | Quick keyword statistics | `pip install pdfid` |
| `pdf-parser.py` | Deep inspection, extraction | `pip install pdf-parser` |
| `peepdf` | Interactive analysis, extraction | `pip install peepdf` |
| `qpdf` | Decrypt, linearize, sanitize | `apt install qpdf` |
| `pdfcpu` | Validate, sanitize, extract | `go install github.com/pdfcpu/pdfcpu` |
| `pdf-inspector` | Visual object graph browser | Browser-based |
| `PyMuPDF (fitz)` | Safe rendering to images | `pip install pymupdf` |

## Analysis Checklist

- [ ] Run `pdfid.py` for initial triage
- [ ] Check file type with `file` command
- [ ] Count `%%EOF` markers
- [ ] Search for `/JS`, `/OpenAction`, `/AA`
- [ ] Look for embedded files
- [ ] Check for polyglot indicators (`<w:WordDocument>`)
- [ ] Decrypt if password-protected
- [ ] Validate structure with `pdfcpu`
- [ ] Extract and analyze suspicious streams
- [ ] Review XMP metadata
- [ ] Check for multiple `/Catalog` objects

## References

- [Trail of Bits CTF Forensics](https://trailofbits.github.io/ctf/forensics/)
- [Didier Stevens PDF Structure](https://blog.didierstevens.com/2008/04/09/quickpost-about-the-physical-and-logical-structure-of-pdf-files/)
- [qpdf](https://github.com/qpdf/qpdf)
- [PeepDF](https://github.com/jesparza/peepdf)
- [PDF Tricks by Ange Albertini](https://github.com/corkami/docs/blob/master/PDF/PDF.md)
- [JPCERT/CC MalDoc Analysis](https://www.jpcert.or.jp/english/publication/ir_info/2023/20230808_01.html)
- [Adobe Security Updates](https://helpx.adobe.com/security/products/acrobat.html)
