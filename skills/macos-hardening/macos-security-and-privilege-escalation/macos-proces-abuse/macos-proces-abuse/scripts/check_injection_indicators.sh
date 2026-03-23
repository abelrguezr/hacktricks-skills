#!/bin/bash
# macOS Process Injection Indicator Checker
# For authorized security research only

set -e

echo "=== macOS Process Injection Indicator Check ==="
echo "Running as: $(whoami)"
echo "Date: $(date)"
echo ""

# Check for suspicious environment variables
echo "--- Environment Variable Checks ---"
SUSPICIOUS_VARS=(
    "DYLD_INSERT_LIBRARIES"
    "CFNETWORK_LIBRARY_PATH"
    "RAWCAMERA_BUNDLE_PATH"
    "ELECTRON_RUN_AS_NODE"
    "_JAVA_OPTS"
    "PYTHONINSPECT"
    "PYTHONSTARTUP"
    "PYTHONPATH"
    "PYTHONHOME"
)

for var in "${SUSPICIOUS_VARS[@]}"; do
    value=$(printenv "$var" 2>/dev/null || echo "")
    if [ -n "$value" ]; then
        echo "[!] $var is set: $value"
    else
        echo "[✓] $var is not set"
    fi
done

echo ""
echo "--- Process Analysis ---"

# Check for processes with suspicious characteristics
if command -v ps &> /dev/null; then
    echo "Checking for processes with elevated privileges..."
    ps aux | head -20
fi

echo ""
echo "--- Symlink/Hardlink Check ---"

# Check for suspicious symlinks in common locations
COMMON_PATHS=(
    "/usr/bin"
    "/usr/local/bin"
    "/opt/homebrew/bin"
    "/Library/PrivilegedHelperTools"
)

for path in "${COMMON_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo "Checking $path for symlinks..."
        find "$path" -type l 2>/dev/null | head -10 || echo "  No symlinks found"
    fi
done

echo ""
echo "--- Electron Debug Check ---"

# Check for Electron processes with debug flags
if command -v ps &> /dev/null; then
    echo "Checking for Electron processes with debug flags..."
    ps aux | grep -i electron | grep -E "(inspect|debug|remote)" || echo "  No suspicious Electron processes found"
fi

echo ""
echo "=== Check Complete ==="
echo "Remember: This tool is for authorized security research only."
