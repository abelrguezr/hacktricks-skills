---
name: document-steganography
description: Analyze documents for hidden steganographic content. Use this skill whenever the user needs to extract hidden data from PDFs, Office files (.docx/.xlsx/.pptx), or other document formats. Trigger on requests to find hidden files, extract embedded content, analyze document structures, or investigate suspicious documents in CTFs, forensics, or security research.
---

# Document Steganography Analysis

This skill helps you extract hidden content from document containers like PDFs and Office OOXML files. Documents are often just containers with embedded files, streams, and hidden objects.

## Quick Start

```bash
# For PDFs
python scripts/analyze_pdf.py <file.pdf>

# For Office files (.docx/.xlsx/.pptx)
python scripts/analyze_office.py <file.docx>
```

## PDF Analysis

PDFs are structured containers with objects, streams, and optional embedded files. Hidden content often appears as:
- Embedded attachments
- Compressed object streams
- Hidden objects (JavaScript, embedded images, odd streams)

### Step-by-Step Process

1. **Get basic info**
   ```bash
   pdfinfo file.pdf
   ```

2. **List and extract attachments**
   ```bash
   pdfdetach -list file.pdf
   pdfdetach -saveall file.pdf
   ```

3. **Flatten and decompress**
   ```bash
   qpdf --qdf --object-streams=disable file.pdf out.pdf
   ```

4. **Search for suspicious content**
   ```bash
   strings out.pdf | grep -iE "(password|secret|hidden|flag|base64)"
   grep -a "JVBER" out.pdf  # Find embedded PDFs
   ```

### What to Look For

- Objects with unusual stream lengths
- JavaScript actions (`/JS` or `/JavaScript`)
- Embedded images in unexpected places
- Base64-encoded data in text streams
- References to external files or URLs

## Office OOXML Analysis

Office OOXML files (`.docx`, `.xlsx`, `.pptx`) are ZIP containers with XML and assets. Hidden payloads often appear in:
- Media files (`word/media/`)
- Relationship files (`_rels/`)
- Custom XML parts
- Unusual file structures

### Step-by-Step Process

1. **List contents**
   ```bash
   7z l file.docx
   ```

2. **Extract to inspect**
   ```bash
   7z x file.docx -oout/
   ```

3. **Check key locations**
   ```bash
   # Main document content
   cat out/word/document.xml
   
   # Relationships (may point to hidden resources)
   cat out/word/_rels/*.rels
   
   # Embedded media
   ls -la out/word/media/
   ```

4. **Search for suspicious patterns**
   ```bash
   grep -r "http" out/
   grep -r "base64" out/
   grep -r "flag" out/
   ```

### What to Look For

- External URLs in relationship files
- Unusual file types in `media/`
- Custom XML parts not in standard locations
- Large or oddly-named files
- References to non-existent resources

## Examples

### Example 1: Extracting PDF Attachments

**Input:** User has `suspicious_report.pdf` and suspects hidden files

**Process:**
```bash
# List attachments
pdfdetach -list suspicious_report.pdf
# Output: 1: hidden_data.txt

# Extract all
pdfdetach -saveall suspicious_report.pdf
# Creates: hidden_data.txt

# Inspect
strings hidden_data.txt
```

### Example 2: Finding Hidden Office Content

**Input:** User has `meeting_notes.docx` with suspicious behavior

**Process:**
```bash
# Extract
7z x meeting_notes.docx -oextracted/

# Check relationships
cat extracted/word/_rels/document.xml.rels
# May reveal: <Relationship Id="rId3" Type="..." Target="../hidden/secret.xml"/>

# Inspect hidden parts
ls -la extracted/word/hidden/
```

### Example 3: CTF Flag Hunting

**Input:** User has `document.pdf` in a CTF challenge

**Process:**
```bash
# Flatten PDF
qpdf --qdf --object-streams=disable document.pdf flat.pdf

# Search for flag patterns
strings flat.pdf | grep -i "flag{"
strings flat.pdf | grep -i "ctf{"

# Check for embedded images
pdfimages -list flat.pdf
```

## Common Tools

| Tool | Purpose |
|------|--------|
| `pdfinfo` | Basic PDF metadata |
| `pdfdetach` | List/extract PDF attachments |
| `qpdf` | Flatten and decompress PDFs |
| `7z` | Extract Office OOXML files |
| `strings` | Extract readable text from binaries |
| `grep` | Search for patterns |

## Tips

1. **Always work on copies** - Don't modify original files
2. **Check file extensions** - A `.pdf` might actually be something else
3. **Look for inconsistencies** - File size vs. content, metadata vs. actual content
4. **Search broadly** - Use `strings` and `grep` to find anything unusual
5. **Check relationships** - In OOXML, `_rels/` files often reveal hidden structure

## When to Use This Skill

Use this skill when:
- Investigating suspicious documents
- Extracting hidden files from PDFs or Office documents
- Participating in CTF challenges with document-based steganography
- Performing forensic analysis on document files
- Looking for embedded content, attachments, or hidden streams
- Analyzing document structure for security research
