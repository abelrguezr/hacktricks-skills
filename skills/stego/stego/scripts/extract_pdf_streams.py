#!/usr/bin/env python3
"""Extract streams and objects from PDF files."""

import sys
import os
import re
import subprocess
from pathlib import Path

def extract_with_qpdf(pdf_path):
    """Use qpdf to extract PDF structure."""
    result = subprocess.run(
        ['qpdf', '--json', pdf_path],
        capture_output=True,
        text=True,
        timeout=30
    )
    
    if result.returncode == 0:
        return result.stdout
    return None

def extract_with_strings(pdf_path):
    """Extract strings from PDF."""
    result = subprocess.run(
        ['strings', '-n', '10', pdf_path],
        capture_output=True,
        text=True,
        timeout=30
    )
    
    return result.stdout

def find_embedded_files(pdf_path):
    """Look for embedded file streams."""
    embedded = []
    
    # Common embedded file signatures
    signatures = {
        'PNG': b'\x89PNG',
        'JPEG': b'\xff\xd8\xff',
        'GIF': b'GIF8',
        'ZIP': b'PK',
        'PDF': b'%PDF',
        'GZIP': b'\x1f\x8b',
    }
    
    try:
        with open(pdf_path, 'rb') as f:
            content = f.read()
            
        for name, sig in signatures.items():
            pos = content.find(sig)
            while pos != -1:
                embedded.append({
                    'type': name,
                    'position': pos,
                    'offset_hex': hex(pos)
                })
                pos = content.find(sig, pos + 1)
    except Exception as e:
        print(f"Error reading file: {e}")
    
    return embedded

def extract_text_content(pdf_path):
    """Extract text content from PDF."""
    result = subprocess.run(
        ['pdftotext', '-layout', pdf_path, '-'],
        capture_output=True,
        text=True,
        timeout=30
    )
    
    return result.stdout if result.returncode == 0 else None

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 extract_pdf_streams.py <pdf_file>")
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    
    if not os.path.exists(pdf_path):
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)
    
    print(f"Analyzing PDF: {pdf_path}")
    print("=" * 60)
    
    # Get file size
    file_size = os.path.getsize(pdf_path)
    print(f"File size: {file_size} bytes")
    
    # Extract text content
    print("\n--- Text Content (first 500 chars) ---")
    text = extract_text_content(pdf_path)
    if text:
        print(text[:500])
        if len(text) > 500:
            print(f"\n... ({len(text) - 500} more characters)")
    else:
        print("Could not extract text (may be image-based PDF)")
    
    # Find embedded files
    print("\n--- Embedded Files ---")
    embedded = find_embedded_files(pdf_path)
    if embedded:
        for item in embedded:
            print(f"{item['type']} at offset {item['offset_hex']}")
    else:
        print("No obvious embedded files found")
    
    # Extract strings with interesting patterns
    print("\n--- Interesting Strings ---")
    strings_output = extract_with_strings(pdf_path)
    if strings_output:
        interesting_patterns = [
            r'flag\{[^}]+\}',
            r'secret[^\s]+',
            r'hidden[^\s]+',
            r'password[^\s]+',
            r'key[^\s]+',
            r'[A-Za-z0-9+/]{50,}={0,2}',  # Base64
        ]
        
        for pattern in interesting_patterns:
            matches = re.findall(pattern, strings_output, re.IGNORECASE)
            if matches:
                print(f"\nPattern '{pattern}':")
                for match in matches[:5]:  # First 5 matches
                    print(f"  {match[:100]}{'...' if len(match) > 100 else ''}")
    
    # Try qpdf JSON extraction
    print("\n--- PDF Structure (via qpdf) ---")
    qpdf_output = extract_with_qpdf(pdf_path)
    if qpdf_output:
        # Count pages
        try:
            import json
            data = json.loads(qpdf_output)
            pages = data.get('pages', {})
            print(f"Pages: {len(pages)}")
            
            # Check for embedded files in structure
            if 'embedded_files' in data:
                print(f"Embedded files in structure: {len(data['embedded_files'])}")
        except:
            print("Could not parse qpdf JSON output")
    else:
        print("qpdf not available or failed")

if __name__ == "__main__":
    main()
