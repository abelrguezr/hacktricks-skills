#!/usr/bin/env python3
"""Modify attribute names in AppleDouble (._*) files.

Usage:
    python3 modify_appledouble.py <appledouble-file> <old-name> <new-name>

Example:
    python3 modify_appledouble.py .\_protected com.apple.xxx.xxxx com.apple.acl.text
"""

import sys

def modify_appledouble(filepath, old_name, new_name):
    """Replace an attribute name in an AppleDouble file."""
    try:
        with open(filepath, 'rb+') as f:
            content = f.read()
            old_bytes = old_name.encode('utf-8')
            new_bytes = new_name.encode('utf-8')
            
            if old_bytes not in content:
                print(f"Warning: '{old_name}' not found in {filepath}")
                return False
            
            content = content.replace(old_bytes, new_bytes)
            f.seek(0)
            f.write(content)
            f.truncate()
            
        print(f"Successfully replaced '{old_name}' with '{new_name}' in {filepath}")
        return True
    except Exception as e:
        print(f"Error: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: python3 modify_appledouble.py <appledouble-file> <old-name> <new-name>")
        print("Example: python3 modify_appledouble.py ._protected com.apple.xxx.xxxx com.apple.acl.text")
        sys.exit(1)
    
    filepath = sys.argv[1]
    old_name = sys.argv[2]
    new_name = sys.argv[3]
    
    modify_appledouble(filepath, old_name, new_name)
