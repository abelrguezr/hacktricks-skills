#!/bin/bash
#
# Bash Jail Enumeration Script
# 
# This script helps identify potential escape vectors from a restricted bash shell.
# Run this to understand what you have access to before attempting escapes.
#
# Usage:
#     bash bash_escape_check.sh
#     # or if bash is restricted:
#     sh bash_escape_check.sh
#

echo "========================================"
echo "Bash Jail Enumeration"
echo "========================================"
echo ""

# Check current shell
echo "[1] Current Shell:"
echo "SHELL=$SHELL"
echo ""

# Check PATH
echo "[2] PATH:"
echo "PATH=$PATH"
echo ""

# List PATH directories
echo "[3] PATH Directories:"
IFS=':' read -ra PATH_DIRS <<< "$PATH"
for dir in "${PATH_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "  $dir: $(ls $dir 2>/dev/null | wc -l) files"
    else
        echo "  $dir: NOT FOUND"
    fi
done
echo ""

# Check environment variables
echo "[4] Environment Variables:"
env | head -20
echo "..."
echo ""

# Check current directory
echo "[5] Current Directory:"
pwd
echo ""

# Check what we can execute
echo "[6] Available Commands:"
for cmd in bash sh zsh python python3 perl ruby nc netcat curl wget vim vi nano cat ls pwd id whoami; do
    if command -v $cmd &> /dev/null; then
        echo "  [OK] $cmd"
    else
        echo "  [X] $cmd"
    fi
done
echo ""

# Check write permissions
echo "[7] Write Permissions:"
for dir in /tmp /var/tmp /dev/shm .; do
    if [ -d "$dir" ]; then
        if [ -w "$dir" ]; then
            echo "  [W] $dir"
        else
            echo "  [R] $dir"
        fi
    fi
done
echo ""

# Check for GTFOBins candidates
echo "[8] GTFOBins Candidates:"
for cmd in find xargs tar zip unzip python perl ruby awk sed nmap; do
    if command -v $cmd &> /dev/null; then
        echo "  [!] $cmd - Check GTFOBins for shell escapes"
    fi
done
echo ""

# Check if we can modify PATH
echo "[9] PATH Modification Test:"
OLD_PATH="$PATH"
PATH=/usr/local/sbin:/usr/sbin:/sbin:/usr/local/bin:/usr/bin:/bin
if [ "$PATH" != "$OLD_PATH" ]; then
    echo "  [OK] PATH can be modified"
else
    echo "  [X] PATH is read-only"
fi
PATH="$OLD_PATH"
echo ""

# Check for vim
echo "[10] Vim Escape Test:"
if command -v vim &> /dev/null; then
    echo "  [!] vim available - can escape with :set shell=/bin/sh :shell"
elif command -v vi &> /dev/null; then
    echo "  [!] vi available - may be able to escape"
else
    echo "  [X] vim/vi not available"
fi
echo ""

echo "========================================"
echo "Enumeration Complete"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Check GTFOBins for any available commands"
echo "2. Try vim escape if available"
echo "3. Try PATH modification"
echo "4. Look for writable directories to create scripts"
