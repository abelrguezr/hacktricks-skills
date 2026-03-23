#!/bin/bash
# Check write permissions on PATH directories for DLL hijacking opportunities
# Usage: ./check_dll_permissions.sh [path_to_check]
# If no path provided, checks common Windows directories

if [ -z "$1" ]; then
    echo "Checking common Windows directories for write permissions..."
    echo "Run this on a Windows system with accesschk or icacls available"
    echo ""
    echo "# Check all PATH directories (PowerShell)"
    echo '$env:Path -split ";" | ForEach-Object { icacls $_ 2>$null | Select-String "(F) (M) (W)" }'
    echo ""
    echo "# Check specific directory"
    echo 'icacls "C:\path\to\check"'
    echo ""
    echo "# Using accesschk (Sysinternals)"
    echo 'accesschk.exe -dqv "C:\path\to\check"'
else
    echo "Checking permissions for: $1"
    echo "On Windows, run: icacls \"$1\""
    echo "Or: accesschk.exe -dqv \"$1\""
fi
