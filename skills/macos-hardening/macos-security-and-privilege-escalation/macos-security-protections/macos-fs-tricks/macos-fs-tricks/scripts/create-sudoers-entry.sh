#!/bin/bash
# Create a sudoers.d entry for privilege escalation
# Usage: ./create-sudoers-entry.sh <username> [output-path]

if [ $# -lt 1 ]; then
    echo "Usage: $0 <username> [output-path]"
    echo "Example: $0 myuser"
    echo "Example: $0 myuser /etc/sudoers.d/myuser"
    exit 1
fi

USERNAME="$1"
OUTPUT_PATH="${2:-/etc/sudoers.d/$USERNAME}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root"
    echo "Try: sudo $0 $USERNAME"
    exit 1
fi

# Create sudoers entry
cat > "$OUTPUT_PATH" << EOF
# Sudoers entry for $USERNAME
# Created by macos-fs-tricks skill
$USERNAME ALL=(ALL) NOPASSWD:ALL
EOF

# Set correct permissions
chmod 440 "$OUTPUT_PATH"
chown root:wheel "$OUTPUT_PATH"

# Validate syntax
echo "Validating sudoers syntax..."
visudo -c -f "$OUTPUT_PATH" 2>&1
if [ $? -eq 0 ]; then
    echo ""
    echo "Successfully created sudoers entry: $OUTPUT_PATH"
    echo "User '$USERNAME' can now run any command with sudo without password."
else
    echo ""
    echo "Warning: Syntax error in sudoers file!"
    rm -f "$OUTPUT_PATH"
    exit 1
fi
