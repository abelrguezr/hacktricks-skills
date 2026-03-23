#!/usr/bin/env python3
"""
Inspect the structure of a Synology PAT archive.

PAT files are cpio bundles containing multiple files including:
- hda1.tgz (root filesystem)
- rd.bin (initramfs)
- packages/ (embedded SPK applications)
- Various configuration files
"""

import sys
import subprocess
import tempfile
import shutil
from pathlib import Path


def inspect_pat(pat_path: str):
    """Inspect the structure of a PAT archive."""
    pat_path = Path(pat_path)
    
    if not pat_path.exists():
        raise FileNotFoundError(f"PAT file not found: {pat_path}")
    
    print(f"[+] Inspecting PAT archive: {pat_path}")
    print(f"[+] File size: {pat_path.stat().st_size:,} bytes")
    
    # Check if it's actually a PAT file
    with open(pat_path, 'rb') as f:
        magic = f.read(3)
    
    if magic == b'\xBF\xBA\xAD':
        print(f"[+] Valid PAT magic bytes detected")
    elif magic == b'\xAD\xBE\xEF':
        print(f"[+] Valid SPK magic bytes detected")
    else:
        print(f"[!] Warning: Unknown magic bytes: {magic.hex()}")
    
    # Try to extract and list contents
    # PAT files are typically LZMA-compressed cpio archives
    print(f"\n[+] Attempting to extract PAT structure...")
    
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        
        try:
            # Try LZMA decompression first
            print(f"[+] Trying LZMA decompression...")
            result = subprocess.run(
                ['lzcat', str(pat_path)],
                capture_output=True,
                timeout=30
            )
            
            if result.returncode == 0:
                cpio_data = result.stdout
                
                # Write to temp file for cpio extraction
                cpio_file = tmpdir / 'archive.cpio'
                cpio_file.write_bytes(cpio_data)
                
                # Extract cpio
                extract_dir = tmpdir / 'extracted'
                extract_dir.mkdir()
                
                result = subprocess.run(
                    ['cpio', '-id', '--no-absolute-filenames'],
                    stdin=open(cpio_file, 'rb'),
                    cwd=str(extract_dir),
                    capture_output=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    print(f"[+] Successfully extracted PAT structure")
                    print(f"\n[+] Contents:")
                    print("-" * 60)
                    
                    # List extracted files
                    for item in sorted(extract_dir.iterdir()):
                        if item.is_file():
                            size = item.stat().st_size
                            print(f"  {item.name:40s} {size:,} bytes")
                        elif item.is_dir():
                            print(f"  {item.name}/")
                    
                    print("-" * 60)
                    
                    # Check for common PAT components
                    common_files = ['hda1.tgz', 'rd.bin', 'packages']
                    print(f"\n[+] Common PAT components:")
                    for cf in common_files:
                        cf_path = extract_dir / cf
                        if cf_path.exists():
                            if cf_path.is_file():
                                print(f"  ✓ {cf} ({cf_path.stat().st_size:,} bytes)")
                            else:
                                count = len(list(cf_path.iterdir()))
                                print(f"  ✓ {cf}/ ({count} items)")
                        else:
                            print(f"  ✗ {cf} (not found)")
                    
                    return
            
            # Try direct cpio (some PATs aren't compressed)
            print(f"[+] Trying direct cpio extraction...")
            result = subprocess.run(
                ['cpio', '-it'],
                stdin=open(pat_path, 'rb'),
                capture_output=True,
                timeout=30
            )
            
            if result.returncode == 0:
                print(f"[+] PAT structure (cpio listing):")
                print("-" * 60)
                for line in result.stdout.decode('utf-8', errors='replace').split('\n')[:50]:
                    if line.strip():
                        print(f"  {line}")
                print("-" * 60)
                return
            
        except subprocess.TimeoutExpired:
            print(f"[!] Extraction timed out")
        except FileNotFoundError:
            print(f"[!] Required tools not found (lzcat, cpio)")
            print(f"[+] Install with: apt install p7zip-full cpio")
        except Exception as e:
            print(f"[!] Error during extraction: {e}")
    
    print(f"\n[+] Alternative: Use patology tool")
    print(f"  pip install patology")
    print(f"  python3 -m patology --dump -i {pat_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 inspect_pat_structure.py <pat-file>")
        print("\nInspect the structure of a Synology PAT archive.")
        print("\nExample:")
        print("  python3 inspect_pat_structure.py firmware.pat")
        sys.exit(1)
    
    pat_path = sys.argv[1]
    
    try:
        inspect_pat(pat_path)
    except Exception as e:
        print(f"[!] Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
