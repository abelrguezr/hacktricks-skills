#!/usr/bin/env python3
"""Detect file/directory name collisions in ZIP files.

Usage:
    python3 detect_collisions.py file.zip

A ZIP can contain both 'X' (file) and 'X/' (directory). Some extractors
get confused and may hide the real file. This is a common anti-reversing
trick in malicious APKs.
"""
import sys
from zipfile import ZipFile
from collections import defaultdict

def detect_collisions(zip_path: str) -> list[tuple[str, list[str]]]:
    """Find names that differ only by trailing slash.
    
    Args:
        zip_path: Path to ZIP file
        
    Returns:
        List of (base_name, [variants]) tuples where len(variants) > 1
    """
    try:
        with ZipFile(zip_path) as z:
            names = z.namelist()
    except FileNotFoundError:
        print(f"Error: File not found: {zip_path}")
        sys.exit(1)
    except ZipFile.BadZipFile:
        print(f"Error: Invalid ZIP file: {zip_path}")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading ZIP: {e}")
        sys.exit(1)
    
    collisions = defaultdict(list)
    for n in names:
        # Normalize: remove trailing slash for comparison
        base = n[:-1] if n.endswith('/') else n
        collisions[base].append(n)
    
    # Filter to actual collisions (more than one variant)
    return [(base, variants) for base, variants in collisions.items() if len(variants) > 1]

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} file.zip")
        sys.exit(1)
    
    zip_path = sys.argv[1]
    collisions = detect_collisions(zip_path)
    
    if not collisions:
        print("No name collisions detected.")
        return
    
    print(f"Found {len(collisions)} name collision(s):\n")
    
    # Highlight critical APK entries
    critical = {'AndroidManifest.xml', 'resources.arsc'}
    critical_patterns = ['classes.dex', 'classes2.dex', 'classes3.dex']
    
    for base, variants in collisions:
        is_critical = base in critical or any(base.endswith(p) for p in critical_patterns)
        marker = " [CRITICAL]" if is_critical else ""
        print(f"COLLISION{marker}: {base}")
        print(f"  Variants: {variants}")
        print()
    
    print("Recommendation: Extract with 'rename' option on conflicts:")
    print(f"  unzip {zip_path} -d outdir")
    print("  When prompted, choose [r]ename for conflicting files")

if __name__ == '__main__':
    main()
