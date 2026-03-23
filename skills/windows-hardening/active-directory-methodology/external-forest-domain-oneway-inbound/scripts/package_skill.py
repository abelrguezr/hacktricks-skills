#!/usr/bin/env python3
"""Package an AD External Forest Trust skill into a .skill file."""

import os
import sys
import json
import zipfile
from pathlib import Path

def package_skill(skill_path: str, output_path: str = None) -> str:
    """Package a skill directory into a .skill file."""
    skill_dir = Path(skill_path)
    
    if not skill_dir.exists():
        raise FileNotFoundError(f"Skill directory not found: {skill_path}")
    
    if not skill_dir.is_dir():
        raise NotADirectoryError(f"Path is not a directory: {skill_path}")
    
    # Determine output path
    if output_path is None:
        skill_name = skill_dir.name
        output_path = f"{skill_name}.skill"
    
    output_file = Path(output_path)
    
    # Create the .skill file (which is a zip)
    with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as skill_zip:
        # Add all files from the skill directory
        for file_path in skill_dir.rglob('*'):
            if file_path.is_file():
                # Store with relative path from skill directory
                arcname = file_path.relative_to(skill_dir)
                skill_zip.write(file_path, arcname)
    
    print(f"[+] Packaged skill to: {output_file.absolute()}")
    print(f"[+] Size: {output_file.stat().st_size} bytes")
    
    # List contents
    print("\n[+] Contents:")
    with zipfile.ZipFile(output_file, 'r') as skill_zip:
        for name in skill_zip.namelist():
            print(f"    - {name}")
    
    return str(output_file)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python package_skill.py <skill-directory> [output-file]")
        print("Example: python package_skill.py ad-external-forest-trust/")
        sys.exit(1)
    
    skill_dir = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    try:
        result = package_skill(skill_dir, output_file)
        print(f"\n[+] Success! Install with: cp {result} ~/.local/share/anthropic/claude/skills/")
    except Exception as e:
        print(f"[-] Error: {e}")
        sys.exit(1)
