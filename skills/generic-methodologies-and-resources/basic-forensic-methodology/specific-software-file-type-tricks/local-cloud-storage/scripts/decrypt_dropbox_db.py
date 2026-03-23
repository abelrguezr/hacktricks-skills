#!/usr/bin/env python3
"""
Decrypt Dropbox .dbx files using DPAPI

This script orchestrates the decryption of Dropbox encrypted databases.
It requires the DPAPI master key, SYSTEM/SECURITY hives, and user credentials.

Usage:
    python decrypt_dropbox_db.py --dbx-file config.dbx \
        --dpapi-key <path> --system-hive <path> --security-hive <path> \
        --master-key <path> --username <user> --password <pass>

Note: This script uses the DataProtectionAPI library for DPAPI decryption.
Install with: pip install dpapi
"""

import sys
import argparse
from pathlib import Path
import subprocess
import json


def check_dependencies():
    """Check if required dependencies are installed"""
    missing = []
    
    try:
        import dpapi
    except ImportError:
        missing.append('dpapi (pip install dpapi)')
    
    try:
        import sqlite3
    except ImportError:
        missing.append('sqlite3 (usually included with Python)')
    
    if missing:
        print("Missing dependencies:")
        for dep in missing:
            print(f"  - {dep}")
        sys.exit(1)


def derive_dropbox_key(primary_key: str, salt: str = None, iterations: int = None) -> str:
    """
    Derive the final Dropbox encryption key using PBKDF2
    
    Args:
        primary_key: The primary key from DataProtectionDecryptor
        salt: Dropbox salt (default: 0D638C092E8B82FC452883F95F355B8E)
        iterations: PBKDF2 iterations (default: 1066)
        
    Returns:
        Hex-encoded derived key
    """
    if salt is None:
        salt = "0D638C092E8B82FC452883F95F355B8E"
    if iterations is None:
        iterations = 1066
    
    # Use CyberChef recipe via subprocess if available
    # Otherwise, use Python's hashlib
    try:
        from hashlib import pbkdf2_hmac, sha1
        import binascii
        
        # Convert hex strings to bytes
        key_bytes = binascii.unhexlify(primary_key)
        salt_bytes = binascii.unhexlify(salt)
        
        # Derive key using PBKDF2 with SHA1
        derived = pbkdf2_hmac('sha1', key_bytes, salt_bytes, iterations, dklen=16)
        
        return binascii.hexlify(derived).decode('ascii')
    except Exception as e:
        print(f"Error deriving key: {e}", file=sys.stderr)
        return None


def decrypt_dbx_file(
    dbx_path: str,
    output_path: str,
    encryption_key: str
) -> bool:
    """
    Decrypt a .dbx file using sqlite3 with the -k flag
    
    Args:
        dbx_path: Path to encrypted .dbx file
        output_path: Path for decrypted .db output
        encryption_key: Hex-encoded encryption key
        
    Returns:
        True if successful, False otherwise
    """
    try:
        # Use sqlite3 command line tool
        cmd = [
            'sqlite3',
            f'-k{encryption_key}',
            dbx_path,
            f'.backup {output_path}'
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"Successfully decrypted {dbx_path} to {output_path}")
            return True
        else:
            print(f"Error decrypting file: {result.stderr}", file=sys.stderr)
            return False
    except FileNotFoundError:
        print("Error: sqlite3 command not found. Install SQLite3.", file=sys.stderr)
        return False


def extract_dpapi_key(
    registry_path: str,
    system_hive: str,
    security_hive: str,
    master_key_path: str,
    username: str,
    password: str
) -> str:
    """
    Extract and decrypt the DPAPI key
    
    This is a placeholder - actual implementation requires the dpapi library
    and proper handling of Windows registry hives.
    
    Args:
        registry_path: Path to NTUSER.DAT registry hive
        system_hive: Path to SYSTEM hive
        security_hive: Path to SECURITY hive
        master_key_path: Path to DPAPI master key file
        username: Windows username
        password: Windows password
        
    Returns:
        Decrypted primary key (hex string)
    """
    print("Note: DPAPI decryption requires the dpapi library and proper setup.")
    print("For production use, consider using:")
    print("  - DataProtectionDecryptor (NirSoft)")
    print("  - libdpapi (https://github.com/eliben/libdpapi)")
    print("  - pypykatz (https://github.com/skelsec/pypykatz)")
    
    # Placeholder - in real implementation, this would:
    # 1. Read the encrypted key from registry
    # 2. Use DPAPI to decrypt it with the master key
    # 3. Return the decrypted primary key
    
    return None


def main():
    parser = argparse.ArgumentParser(
        description='Decrypt Dropbox .dbx files using DPAPI'
    )
    parser.add_argument(
        '--dbx-file', '-d',
        required=True,
        help='Path to encrypted .dbx file (e.g., config.dbx)'
    )
    parser.add_argument(
        '--output', '-o',
        help='Output path for decrypted database (default: <name>.db)'
    )
    parser.add_argument(
        '--key', '-k',
        help='Pre-computed encryption key (hex). If provided, skips DPAPI decryption.'
    )
    parser.add_argument(
        '--primary-key', '-p',
        help='Primary key from DataProtectionDecryptor. Will derive final key.'
    )
    
    # DPAPI decryption arguments (optional if --key or --primary-key provided)
    dpapi_group = parser.add_argument_group('DPAPI Decryption (optional)')
    dpapi_group.add_argument(
        '--dpapi-key',
        help='Path to encrypted DPAPI key file'
    )
    dpapi_group.add_argument(
        '--system-hive',
        help='Path to SYSTEM registry hive'
    )
    dpapi_group.add_argument(
        '--security-hive',
        help='Path to SECURITY registry hive'
    )
    dpapi_group.add_argument(
        '--master-key',
        help='Path to DPAPI master key file'
    )
    dpapi_group.add_argument(
        '--username',
        help='Windows username'
    )
    dpapi_group.add_argument(
        '--password',
        help='Windows password'
    )
    
    args = parser.parse_args()
    
    # Check dependencies
    check_dependencies()
    
    # Determine output path
    dbx_path = Path(args.dbx_file)
    if not dbx_path.exists():
        print(f"Error: File not found: {args.dbx_file}", file=sys.stderr)
        sys.exit(1)
    
    if args.output:
        output_path = args.output
    else:
        output_path = str(dbx_path.with_suffix('.db'))
    
    # Get encryption key
    encryption_key = None
    
    if args.key:
        encryption_key = args.key
    elif args.primary_key:
        print(f"Deriving key from primary key...")
        encryption_key = derive_dropbox_key(args.primary_key)
        if encryption_key:
            print(f"Derived key: {encryption_key}")
    elif all([args.dpapi_key, args.system_hive, args.security_hive, 
              args.master_key, args.username, args.password]):
        print("Extracting DPAPI key...")
        primary_key = extract_dpapi_key(
            args.dpapi_key,
            args.system_hive,
            args.security_hive,
            args.master_key,
            args.username,
            args.password
        )
        if primary_key:
            encryption_key = derive_dropbox_key(primary_key)
    else:
        print("Error: Must provide either:")
        print("  --key <encryption_key>")
        print("  --primary-key <primary_key>")
        print("  or all DPAPI decryption arguments")
        sys.exit(1)
    
    if not encryption_key:
        print("Error: Could not obtain encryption key", file=sys.stderr)
        sys.exit(1)
    
    # Decrypt the file
    success = decrypt_dbx_file(str(dbx_path), output_path, encryption_key)
    
    if success:
        print(f"\nDecrypted database saved to: {output_path}")
        print("\nYou can now query it with:")
        print(f"  python query_gdrive_db.py {output_path}")
    else:
        sys.exit(1)


if __name__ == '__main__':
    main()
