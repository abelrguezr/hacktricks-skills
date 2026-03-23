#!/bin/bash
# PackageKit PKG Inspection Script
# Checks for shell-based install scripts vulnerable to CVE-2024-27822

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-pkg>"
    echo "Example: $0 /Applications/SomeApp.pkg"
    exit 1
fi

PKG_PATH="$1"
TMP_DIR="/tmp/pkg-inspect-$$"

echo "=== PackageKit PKG Inspection ==="
echo "Package: $PKG_PATH"
echo ""

# Create temp directory
mkdir -p "$TMP_DIR"

# Expand the package
echo "[1] Expanding package..."
pkgutil --expand-full "$PKG_PATH" "$TMP_DIR" 2>/dev/null || {
    echo "  Failed to expand package"
    rm -rf "$TMP_DIR"
    exit 1
}
echo "  Expanded to: $TMP_DIR"
echo ""

# Find install scripts
echo "[2] Finding install scripts..."
SCRIPTS=$(find "$TMP_DIR" -type f \( -name preinstall -o -name postinstall -o -name preflight -o -name postflight \) 2>/dev/null)

if [ -z "$SCRIPTS" ]; then
    echo "  No install scripts found"
else
    echo "  Found scripts:"
    for script in $SCRIPTS; do
        echo "    $script"
    done
fi
echo ""

# Check for shell-based scripts
echo "[3] Checking for shell-based scripts (vulnerable to CVE-2024-27822)..."
VULNERABLE=0
for script in $SCRIPTS; do
    if [ -f "$script" ]; then
        shebang=$(head -n1 "$script" 2>/dev/null || true)
        if echo "$shebang" | grep -qE '^#!/bin/(zsh|bash|sh)'; then
            echo "  [VULNERABLE] $script"
            echo "    Shebang: $shebang"
            VULNERABLE=1
        else
            echo "  [SAFE] $script"
            echo "    Shebang: $shebang"
        fi
    fi
done
echo ""

# Check user's shell environment
echo "[4] User shell environment check:"
if [ -f "~/.zshenv" ]; then
    echo "  ~/.zshenv exists - could be abused for logic bomb"
    echo "  Lines: $(wc -l < ~/.zshenv)"
fi
if [ -f "~/.bash_profile" ]; then
    echo "  ~/.bash_profile exists"
fi
if [ -f "~/.profile" ]; then
    echo "  ~/.profile exists"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ $VULNERABLE -eq 1 ]; then
    echo "[!] VULNERABLE: This package contains shell-based install scripts."
    echo "    On affected macOS versions (Sonoma < 14.5, Ventura < 13.6.7, Monterey < 12.7.5),"
    echo "    these scripts run as root with the user's environment, loading ~/.zshenv."
    echo ""
    echo "    Logic bomb example:"
    echo "    echo 'id > /tmp/pkg-root' >> ~/.zshenv"
else
    echo "[OK] No shell-based install scripts found."
fi
echo ""

# Cleanup
rm -rf "$TMP_DIR"

echo "=== Inspection Complete ==="
