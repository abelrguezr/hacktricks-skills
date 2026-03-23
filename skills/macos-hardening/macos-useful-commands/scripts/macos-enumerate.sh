#!/bin/bash
# macOS System Enumeration Script
# Quick comprehensive system overview

set -e

OUTPUT_DIR="${1:-./macos-enumeration-output}"
mkdir -p "$OUTPUT_DIR"

echo "=== macOS System Enumeration ==="
echo "Timestamp: $(date)"
echo "Output directory: $OUTPUT_DIR"
echo ""

# System Information
echo "[1/8] System Information..."
system_profiler SPSoftwareDataType > "$OUTPUT_DIR/system-info.txt" 2>&1
system_profiler SPHardwareDataType >> "$OUTPUT_DIR/system-info.txt" 2>&1

# Network Configuration
echo "[2/8] Network Configuration..."
networksetup -listallnetworkservices > "$OUTPUT_DIR/network.txt" 2>&1
networksetup -listallhardwareports >> "$OUTPUT_DIR/network.txt" 2>&1
networksetup -getinfo Wi-Fi >> "$OUTPUT_DIR/network.txt" 2>&1 || true
lsof -i -P -n 2>/dev/null | grep LISTEN > "$OUTPUT_DIR/listening-ports.txt" 2>&1 || true

# Running Services
echo "[3/8] Running Services..."
launchctl list > "$OUTPUT_DIR/services.txt" 2>&1

# Installed Applications
echo "[4/8] Installed Applications..."
system_profiler SPApplicationsDataType > "$OUTPUT_DIR/applications.txt" 2>&1

# Homebrew Packages
echo "[5/8] Homebrew Packages..."
if command -v brew &> /dev/null; then
    brew list > "$OUTPUT_DIR/brew-packages.txt" 2>&1
else
    echo "Homebrew not installed" > "$OUTPUT_DIR/brew-packages.txt"
fi

# User Information
echo "[6/8] User Information..."
whoami > "$OUTPUT_DIR/users.txt" 2>&1
id >> "$OUTPUT_DIR/users.txt" 2>&1
w >> "$OUTPUT_DIR/users.txt" 2>&1 || true

# Disk Information
echo "[7/8] Disk Information..."
df -h > "$OUTPUT_DIR/disk.txt" 2>&1
diskutil list >> "$OUTPUT_DIR/disk.txt" 2>&1 || true

# Security Checks
echo "[8/8] Security Checks..."
echo "VM Detection:" > "$OUTPUT_DIR/security.txt" 2>&1
if system_profiler SPHardwareDataType SPDisplaysDataType 2>/dev/null | grep -Eiq 'qemu|kvm|vmware|virtualbox'; then
    echo "  WARNING: VM indicators detected" >> "$OUTPUT_DIR/security.txt"
else
    echo "  No VM indicators found" >> "$OUTPUT_DIR/security.txt"
fi

echo ""
echo "Enumeration complete!"
echo "Results saved to: $OUTPUT_DIR/"
echo ""
echo "Output files:"
ls -la "$OUTPUT_DIR/"
