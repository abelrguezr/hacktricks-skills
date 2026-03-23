#!/usr/bin/env python3
"""Analyze Office OOXML files for steganographic content."""

import subprocess
import sys
import os
import tempfile
import shutil
import zipfile
import xml.etree.ElementTree as ET

def run_command(cmd, check=True):
    """Run a shell command and return output."""
    print(f"$ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, check=check)
    if result.stdout:
        print(result.stdout)
    if result.stderr and check:
        print(result.stderr, file=sys.stderr)
    return result

def analyze_office(file_path):
    """Perform comprehensive Office OOXML steganography analysis."""
    
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        return
    
    # Create working directory
    work_dir = tempfile.mkdtemp(prefix="office_analysis_")
    print(f"Working directory: {work_dir}")
    
    try:
        # Step 1: List contents
        print("\n=== Step 1: File Contents ===")
        run_command(["7z", "l", file_path], check=False)
        
        # Step 2: Extract
        print("\n=== Step 2: Extracting ===")
        extract_dir = os.path.join(work_dir, "extracted")
        os.makedirs(extract_dir)
        
        with zipfile.ZipFile(file_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
        
        print(f"Extracted to: {extract_dir}")
        
        # Step 3: Analyze structure
        print("\n=== Step 3: Directory Structure ===")
        for root, dirs, files in os.walk(extract_dir):
            level = root.replace(extract_dir, '').count(os.sep)
            indent = ' ' * 2 * level
            print(f"{indent}{os.path.basename(root)}/")
            subindent = ' ' * 2 * (level + 1)
            for file in files:
                print(f"{subindent}{file}")
        
        # Step 4: Check relationships
        print("\n=== Step 4: Relationship Files ===")
        rels_dir = os.path.join(extract_dir, "word", "_rels")
        if os.path.exists(rels_dir):
            for rel_file in os.listdir(rels_dir):
                if rel_file.endswith('.rels'):
                    rel_path = os.path.join(rels_dir, rel_file)
                    print(f"\n--- {rel_file} ---")
                    try:
                        tree = ET.parse(rel_path)
                        root = tree.getroot()
                        for rel in root.findall('.//{http://schemas.openxmlformats.org/package/2006/relationships}Relationship'):
                            target = rel.get('Target', '')
                            rel_type = rel.get('Type', '')
                            print(f"  Target: {target}")
                            print(f"  Type: {rel_type}")
                            # Check for suspicious targets
                            if any(x in target.lower() for x in ['http', 'external', 'hidden', 'secret']):
                                print(f"  ⚠️  SUSPICIOUS: {target}")
                    except Exception as e:
                        print(f"  Error parsing: {e}")
        else:
            print("No relationship files found.")
        
        # Step 5: Check media
        print("\n=== Step 5: Media Files ===")
        media_dir = os.path.join(extract_dir, "word", "media")
        if os.path.exists(media_dir):
            for media_file in os.listdir(media_dir):
                media_path = os.path.join(media_dir, media_file)
                size = os.path.getsize(media_path)
                print(f"  {media_file} ({size} bytes)")
                # Check for unusual file types
                if not any(media_file.lower().endswith(ext) for ext in ['.png', '.jpg', '.jpeg', '.gif', '.emf', '.wmf']):
                    print(f"    ⚠️  Unusual file type")
        else:
            print("No media directory found.")
        
        # Step 6: Search for suspicious patterns
        print("\n=== Step 6: Suspicious Patterns ===")
        patterns = [
            (r"http[s]?://", "URLs"),
            (r"flag\{", "CTF flag"),
            (r"base64", "Base64 data"),
            (r"password", "Password"),
            (r"secret", "Secret"),
        ]
        
        import re
        for root, dirs, files in os.walk(extract_dir):
            for file in files:
                if file.endswith(('.xml', '.rels')):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', errors='ignore') as f:
                            content = f.read()
                            for pattern, description in patterns:
                                matches = re.findall(pattern, content, re.IGNORECASE)
                                if matches:
                                    print(f"\n[{description}] in {file}:")
                                    for match in matches[:3]:
                                        print(f"  {match}")
                    except Exception as e:
                        pass
        
        print(f"\n=== Analysis Complete ===")
        print(f"Extracted files: {extract_dir}")
        print("\nManual inspection recommended for:")
        print("  - Unusual file types in media/")
        print("  - External URLs in relationships")
        print("  - Custom XML parts")
        
    finally:
        # Ask user if they want to keep the working directory
        print(f"\nKeep working directory {work_dir}? (y/n)")
        response = input().strip().lower()
        if response != 'y':
            shutil.rmtree(work_dir)
            print("Working directory removed.")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python analyze_office.py <file.docx>")
        sys.exit(1)
    
    analyze_office(sys.argv[1])
