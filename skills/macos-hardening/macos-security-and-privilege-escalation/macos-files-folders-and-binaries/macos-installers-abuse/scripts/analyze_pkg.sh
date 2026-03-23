#!/bin/bash
# macOS Installer Package Security Analyzer
# Scans extracted package contents for security vulnerabilities

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <extracted_package_directory>"
    echo "Example: $0 /tmp/extracted_package/"
    exit 1
fi

PKG_DIR="$1"

if [ ! -d "$PKG_DIR" ]; then
    echo "Error: Directory not found: $PKG_DIR"
    exit 1
fi

cd "$PKG_DIR"

echo "========================================"
echo "macOS Installer Package Security Analysis"
echo "========================================"
echo "Package directory: $PKG_DIR"
echo "Analysis time: $(date)"
echo ""

# Initialize findings
VULNERABILITIES=0
WARNINGS=0

# Function to report findings
report_vuln() {
    echo "[VULNERABILITY] $1"
    ((VULNERABILITIES++))
}

report_warning() {
    echo "[WARNING] $1"
    ((WARNINGS++))
}

report_info() {
    echo "[INFO] $1"
}

echo "=== Distribution XML Analysis ==="
if [ -f "Distribution" ]; then
    report_info "Distribution file found"
    
    # Check for JavaScript
    if grep -q "<script>" Distribution; then
        report_vuln "JavaScript code found in Distribution XML"
        echo "  - This can execute arbitrary commands via system.run()"
        
        # Extract and show script content
        if grep -q "system.run" Distribution; then
            report_vuln "system.run() calls detected in Distribution"
            echo "  - Commands found:"
            grep -o 'system\.run("[^"]*"' Distribution | head -5 | sed 's/system.run("//' | sed 's/"//' | while read cmd; do
                echo "    * $cmd"
            done
        fi
        
        # Check for sandbox bypass
        if grep -q "isSandboxed" Distribution; then
            report_warning "Sandbox detection code found - possible evasion technique"
        fi
    else
        report_info "No JavaScript in Distribution"
    fi
    
    # Check for require-scripts setting
    if grep -q 'require-scripts="false"' Distribution; then
        report_warning "Scripts not required - may allow bypass"
    fi
else
    report_info "No Distribution file found"
fi

echo ""
echo "=== PackageInfo Analysis ==="
if [ -f "PackageInfo" ]; then
    report_info "PackageInfo file found"
    
    # Extract identifier
    if grep -q "<installer-gui-script" PackageInfo; then
        IDENTIFIER=$(grep -o 'identifier="[^"]*"' PackageInfo | head -1 | sed 's/identifier="//' | sed 's/"//')
        report_info "Package identifier: $IDENTIFIER"
    fi
    
    # Check for script paths
    if grep -q "<file" PackageInfo; then
        report_info "File entries found in PackageInfo"
    fi
else
    report_info "No PackageInfo file found"
fi

echo ""
echo "=== Scripts Analysis ==="
if [ -f "Scripts" ]; then
    report_info "Scripts archive found"
    
    # Try to extract and analyze scripts
    SCRIPTS_DIR=$(mktemp -d)
    cd "$SCRIPTS_DIR"
    
    if cat "$PKG_DIR/Scripts" | gzip -dc | cpio -i 2>/dev/null; then
        report_info "Scripts extracted successfully"
        
        # Check for pre/post install scripts
        for script in preinstall postinstall preupgrade postupgrade precheck; do
            if [ -f "$script" ]; then
                report_info "Found $script script"
                
                # Check for suspicious commands
                if grep -qE "(curl|wget|nc|netcat|bash|sh|python|perl|ruby)" "$script" 2>/dev/null; then
                    report_warning "$script contains network or interpreter commands"
                fi
                
                # Check for world-writable paths
                if grep -qE "(/var/tmp/|/tmp/|/Users/Shared/)" "$script" 2>/dev/null; then
                    report_vuln "$script references world-writable directories"
                fi
                
                # Check for root execution patterns
                if grep -q "AuthorizationExecuteWithPrivileges" "$script" 2>/dev/null; then
                    report_vuln "$script uses AuthorizationExecuteWithPrivileges"
                fi
            fi
        done
    else
        report_info "Could not extract Scripts archive"
    fi
    
    cd "$PKG_DIR"
    rm -rf "$SCRIPTS_DIR"
else
    report_info "No Scripts archive found"
fi

echo ""
echo "=== Payload Analysis ==="
if [ -f "Payload" ]; then
    PAYLOAD_SIZE=$(stat -f%z "Payload" 2>/dev/null || stat -c%s "Payload" 2>/dev/null || echo "unknown")
    report_info "Payload size: $PAYLOAD_SIZE bytes"
    
    if [ "$PAYLOAD_SIZE" -lt 1000 ]; then
        report_warning "Very small payload - may be script-only package"
    fi
else
    report_info "No Payload file found"
fi

echo ""
echo "=== Privilege Escalation Vector Check ==="

# Check for public directory execution patterns
if grep -rqE "(/var/tmp/|/tmp/|/Users/Shared/)" . 2>/dev/null; then
    report_vuln "Package references world-writable directories"
    echo "  - Attacker could replace files before execution"
fi

# Check for fixed /tmp paths (CVE-2021-26089 pattern)
if grep -rqE "/tmp/[a-zA-Z0-9_]+/" . 2>/dev/null; then
    report_warning "Package uses fixed /tmp paths - mount hijacking risk"
    echo "  - See CVE-2021-26089 for details"
fi

echo ""
echo "=== Summary ==="
echo "Vulnerabilities found: $VULNERABILITIES"
echo "Warnings: $WARNINGS"
echo ""

if [ $VULNERABILITIES -gt 0 ]; then
    echo "⚠️  SECURITY ISSUES DETECTED"
    echo "Review the findings above and consider:"
    echo "  - Removing JavaScript from Distribution"
    echo "  - Avoiding world-writable script paths"
    echo "  - Validating AuthorizationExecuteWithPrivileges usage"
    echo "  - Using secure temporary directories"
else
    echo "✓ No critical vulnerabilities detected"
    echo "  (This does not guarantee the package is safe)"
fi

echo ""
echo "Analysis complete."
