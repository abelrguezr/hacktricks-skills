#!/bin/bash
# Check for sudo vulnerabilities and misconfigurations

echo "=== SUDO VULNERABILITY CHECK ==="
echo ""

# Check sudo version
echo "[1] SUDO VERSION"
SUDO_VERSION=$(sudo -V 2>/dev/null | head -1)
echo "$SUDO_VERSION"
if echo "$SUDO_VERSION" | grep -qE '1\.[0-8]\.|1\.9\.[0-9]p[0-1]|1\.9\.10p[0-1]|1\.9\.11'; then
    echo "[!] WARNING: Potentially vulnerable sudo version"
    echo "    Check for CVE-2021-3156 (Baron Samedit)"
    echo "    Check for CVE-2023-22809 (sudoedit)"
fi
echo ""

# Check sudo permissions
echo "[2] SUDO PERMISSIONS"
sudo -l 2>/dev/null || echo "No sudo access"
echo ""

# Check for sudoedit vulnerability (CVE-2023-22809)
echo "[3] SUDOEDIT VULNERABILITY CHECK"
if sudo -l 2>/dev/null | grep -q "sudoedit"; then
    echo "sudoedit is allowed. Testing for CVE-2023-22809..."
    # This is a safe check - we're not actually exploiting
    echo "    If sudo version < 1.9.12p2, this is vulnerable"
    echo "    Exploit: SUDO_EDITOR='vim -- /etc/sudoers' sudoedit /etc/hosts"
fi
echo ""

# Check sudoers files
echo "[4] SUDOERS FILES"
echo "/etc/sudoers:"
ls -la /etc/sudoers 2>/dev/null
echo "/etc/sudoers.d/:"
ls -la /etc/sudoers.d/ 2>/dev/null
echo ""

# Check for NOPASSWD entries
echo "[5] NOPASSWD ENTRIES"
grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#"
echo ""

# Check sudo tokens
echo "[6] SUDO TOKENS"
ls -la /var/run/sudo/ 2>/dev/null || echo "No sudo tokens directory"
echo ""

# Check for doas (OpenBSD alternative)
echo "[7] DOAS CHECK"
if command -v doas &> /dev/null; then
    echo "doas is installed"
    doas -l 2>/dev/null || echo "No doas access"
else
    echo "doas not installed"
fi
echo ""

echo "=== SUDO CHECK COMPLETE ==="
