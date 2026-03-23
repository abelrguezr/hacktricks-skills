#!/bin/bash
# Fuzzing Environment Setup Script
# Prepares macOS system for fuzzing operations

set -e

echo "=== macOS Fuzzing Environment Setup ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠ Warning: Some operations require sudo. Retrying with sudo..."
    exec sudo "$0" "$@"
fi

echo "[*] Step 1: Preventing system sleep..."
echo ""

# Disable sleep
if command -v systemsetup &> /dev/null; then
    echo "Setting sleep to never..."
    sudo systemsetup -setsleep Never 2>/dev/null || echo "  (systemsetup may require GUI)"
fi

# Alternative with pmset
echo "Using pmset to disable sleep..."
pmset sleep 0 2>/dev/null || echo "  (pmset failed)"

echo "✓ Sleep disabled"
echo ""

echo "[*] Step 2: Configuring SSH persistence..."
echo ""

# Backup sshd_config
if [ -f /etc/ssh/sshd_config ]; then
    if [ ! -f /etc/ssh/sshd_config.fuzzing.bak ]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.fuzzing.bak
        echo "✓ Backed up sshd_config"
    fi
    
    # Add keepalive settings if not present
    if ! grep -q "ClientAliveInterval" /etc/ssh/sshd_config; then
        echo ""
        echo "# Fuzzing session persistence"
        echo "TCPKeepAlive yes"
        echo "ClientAliveInterval 0"
        echo "ClientAliveCountMax 0"
        >> /etc/ssh/sshd_config
        echo "✓ Added SSH keepalive settings"
    else
        echo "✓ SSH keepalive settings already present"
    fi
    
    # Restart SSH
    echo "Restarting SSH daemon..."
    sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist 2>/dev/null || true
    sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
    echo "✓ SSH restarted"
else
    echo "⚠ sshd_config not found (SSH may not be enabled)"
fi
echo ""

echo "[*] Step 3: Configuring core dumps..."
echo ""

# Enable core dumps
echo "Current core dump settings:"
sysctl kern.coredump
sysctl kern.sugid_coredump
sysctl kern.corefile

# Create cores directory if it doesn't exist
if [ ! -d /cores ]; then
    mkdir -p /cores
    chmod 1777 /cores
    echo "✓ Created /cores directory"
fi
echo ""

echo "[*] Step 4: Disabling crash reporting (optional)..."
echo ""

read -p "Disable crash reporting? (y/N): " DISABLE_CRASH
if [[ "$DISABLE_CRASH" =~ ^[Yy]$ ]]; then
    echo "Disabling ReportCrash..."
    launchctl unload -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist 2>/dev/null || true
    sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist 2>/dev/null || true
    echo "✓ Crash reporting disabled"
    echo "  To re-enable: run 're-enable-crash-reporting.sh'"
else
    echo "✓ Crash reporting left enabled"
fi
echo ""

echo "[*] Step 5: Checking SIP status..."
echo ""

SIP_STATUS=$(csrutil status 2>/dev/null || echo "Unable to check")
echo "$SIP_STATUS"

if echo "$SIP_STATUS" | grep -qi "enabled"; then
    echo ""
    echo "⚠ SIP is enabled. For full debugging capabilities:"
    echo "  1. Reboot into Recovery Mode"
    echo "  2. Run: csrutil disable"
    echo "  3. Reboot normally"
    echo ""
    echo "  Or for partial disable (allows debugging):"
    echo "  csrutil enable --without debug"
fi
echo ""

echo "[*] Step 6: Creating fuzzing directories..."
echo ""

FUZZ_BASE="${HOME}/fuzzing"
mkdir -p "$FUZZ_BASE/input"
mkdir -p "$FUZZ_BASE/crashes"
mkdir -p "$FUZZ_BASE/artifacts"
mkdir -p "$FUZZ_BASE/logs"

echo "✓ Created fuzzing directories:"
echo "  - $FUZZ_BASE/input (place input files here)"
echo "  - $FUZZ_BASE/crashes (crash outputs will go here)"
echo "  - $FUZZ_BASE/artifacts (runtime artifacts)"
echo "  - $FUZZ_BASE/logs (fuzzer logs)"
echo ""

echo "[*] Step 7: Checking available tools..."
echo ""

TOOLS=("lldb" "dtrace" "dtruss" "otool" "nm" "objdump" "strings" "codesign")
for tool in "${TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✓ $tool: $(which $tool)"
    else
        echo "✗ $tool: not found"
    fi
done
echo ""

echo "[*] Step 8: Creating helper scripts..."
echo ""

# Create a quick fuzzing launcher
cat > "$FUZZ_BASE/run_fuzz.sh" << 'EOF'
#!/bin/bash
# Quick fuzzing launcher

if [ $# -lt 2 ]; then
    echo "Usage: $0 <command_with_FUZZ> <input_dir>"
    echo "Example: $0 '/path/to/app FUZZ' ./input"
    exit 1
fi

COMMAND="$1"
INPUT_DIR="$2"
OUTPUT_DIR="${3:-$HOME/fuzzing/crashes}"
ITERATIONS="${4:-100000}"

mkdir -p "$OUTPUT_DIR"

echo "Starting fuzzing..."
echo "Command: $COMMAND"
echo "Input: $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo "Iterations: $ITERATIONS"
echo ""

# Check if litefuzz is available
if command -v litefuzz &> /dev/null; then
    litefuzz -l -c "$COMMAND" -i "$INPUT_DIR" -o "$OUTPUT_DIR" -n "$ITERATIONS" -ez
else
    echo "⚠ litefuzz not found. Install from: https://github.com/sec-tools/litefuzz"
    echo ""
    echo "Falling back to simple loop..."
    
    for i in $(seq 1 $ITERATIONS); do
        INPUT_FILE=$(ls -1t "$INPUT_DIR" | head -1)
        if [ -n "$INPUT_FILE" ]; then
            echo "Iteration $i: $INPUT_FILE"
            eval "$COMMAND" "$INPUT_DIR/$INPUT_FILE" 2>&1 || echo "CRASH at iteration $i" >> "$OUTPUT_DIR/crashes.log"
        fi
        
        if [ $((i % 1000)) -eq 0 ]; then
            echo "Progress: $i / $ITERATIONS"
        fi
    done
fi

echo ""
echo "Fuzzing complete. Check $OUTPUT_DIR for crashes."
EOF

chmod +x "$FUZZ_BASE/run_fuzz.sh"
echo "✓ Created $FUZZ_BASE/run_fuzz.sh"

# Create crash analysis script
cat > "$FUZZ_BASE/analyze_crash.sh" << 'EOF'
#!/bin/bash
# Crash report analyzer

CRASH_DIR="${1:-$HOME/Library/Logs/DiagnosticReports}"

echo "=== Recent Crash Reports ==="
ls -lt "$CRASH_DIR"/*.crash 2>/dev/null | head -10
echo ""

echo "=== Latest Crash Analysis ==="
LATEST_CRASH=$(ls -t "$CRASH_DIR"/*.crash 2>/dev/null | head -1)
if [ -n "$LATEST_CRASH" ]; then
    echo "File: $LATEST_CRASH"
    echo ""
    echo "--- Exception Type ---"
    grep -A 2 "Exception Type" "$LATEST_CRASH" || echo "Not found"
    echo ""
    echo "--- Exception Codes ---"
    grep -A 2 "Exception Codes" "$LATEST_CRASH" || echo "Not found"
    echo ""
    echo "--- Backtrace (first 20 frames) ---"
    grep -A 20 "Backtrace" "$LATEST_CRASH" | head -25 || echo "Not found"
else
    echo "No crash reports found"
fi
EOF

chmod +x "$FUZZ_BASE/analyze_crash.sh"
echo "✓ Created $FUZZ_BASE/analyze_crash.sh"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Fuzzing environment ready!"
echo ""
echo "Quick start:"
echo "  1. Place input files in: $FUZZ_BASE/input/"
echo "  2. Run: $FUZZ_BASE/run_fuzz.sh '/path/to/app FUZZ' $FUZZ_BASE/input"
echo "  3. Check crashes in: $FUZZ_BASE/crashes/"
echo ""
echo "Useful commands:"
echo "  - Monitor crashes: watch -n 1 'ls -lt $FUZZ_BASE/crashes/'"
echo "  - Analyze crash: $FUZZ_BASE/analyze_crash.sh"
echo "  - View logs: tail -f $FUZZ_BASE/logs/*"
echo ""
echo "To re-enable crash reporting later:"
echo "  launchctl load -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist"
echo "  sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist"
