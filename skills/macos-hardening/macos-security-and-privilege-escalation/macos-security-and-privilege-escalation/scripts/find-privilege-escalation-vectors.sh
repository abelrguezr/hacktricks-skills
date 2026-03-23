#!/bin/bash
# Privilege Escalation Vector Finder
# Identifies potential privilege escalation opportunities on macOS

set -e

echo "=== Privilege Escalation Vector Analysis ==="
echo "Started at: $(date)"
echo ""

OUTPUT_FILE="privilege_escalation_findings.txt"

# Function to add finding
add_finding() {
    local severity="$1"
    local category="$2"
    local description="$3"
    local details="$4"
    
    echo "[SEVERITY: $severity] [CATEGORY: $category]" >> "$OUTPUT_FILE"
    echo "$description" >> "$OUTPUT_FILE"
    if [ -n "$details" ]; then
        echo "Details: $details" >> "$OUTPUT_FILE"
    fi
    echo "" >> "$OUTPUT_FILE"
}

# Initialize output file
echo "# Privilege Escalation Analysis Report" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "User: $(whoami)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Check 1: SUID/SGID Binaries
echo "Checking SUID/SGID binaries..."
SUID_COUNT=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
SGID_COUNT=$(find / -perm -2000 -type f 2>/dev/null | wc -l)

if [ "$SUID_COUNT" -gt 0 ] || [ "$SGID_COUNT" -gt 0 ]; then
    add_finding "MEDIUM" "SUID/SGID" "Found SUID/SGID binaries" "SUID: $SUID_COUNT, SGID: $SGID_COUNT. Review for known vulnerabilities."
fi

# Check 2: World-Writable System Files
echo "Checking world-writable system files..."
WW_FILES=$(find /usr /System /Library -perm -0002 -type f 2>/dev/null | wc -l)

if [ "$WW_FILES" -gt 0 ]; then
    add_finding "HIGH" "File Permissions" "Found world-writable files in system directories" "Count: $WW_FILES. These could be exploited for privilege escalation."
fi

# Check 3: Writable System Directories
echo "Checking writable system directories..."
WW_DIRS=$(find /usr /System /Library -perm -0002 -type d 2>/dev/null | wc -l)

if [ "$WW_DIRS" -gt 0 ]; then
    add_finding "HIGH" "Directory Permissions" "Found writable directories in system paths" "Count: $WW_DIRS. Could allow file creation by unprivileged users."
fi

# Check 4: Sudo Access
echo "Checking sudo access..."
SUDO_ACCESS=$(sudo -l 2>&1 | head -5)

if echo "$SUDO_ACCESS" | grep -q "ALL"; then
    add_finding "CRITICAL" "Sudo Access" "User has sudo privileges" "$SUDO_ACCESS"
else
    add_finding "INFO" "Sudo Access" "Limited or no sudo access" "$SUDO_ACCESS"
fi

# Check 5: Cron Jobs
echo "Checking cron jobs..."
CRON_FILES=$(ls /etc/cron.* 2>/dev/null | wc -l)

if [ "$CRON_FILES" -gt 0 ]; then
    add_finding "MEDIUM" "Scheduled Tasks" "Found cron configuration files" "Count: $CRON_FILES. Check for writable cron jobs or scripts."
fi

# Check 6: LaunchDaemons
echo "Checking LaunchDaemons..."
LD_COUNT=$(ls /Library/LaunchDaemons/ 2>/dev/null | wc -l)

if [ "$LD_COUNT" -gt 0 ]; then
    add_finding "MEDIUM" "System Services" "Found LaunchDaemons" "Count: $LD_COUNT. Review for privilege escalation opportunities."
fi

# Check 7: PATH Injection
echo "Checking PATH injection opportunities..."
PATH_DIRS=$(echo $PATH | tr ':' '\n')
for dir in $PATH_DIRS; do
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        add_finding "HIGH" "PATH Injection" "Writable directory in PATH" "Directory: $dir"
    fi
done

# Check 8: SIP Status
echo "Checking SIP status..."
SIP_STATUS=$(csrutil status 2>&1 || echo "Cannot determine (requires recovery mode)")

if echo "$SIP_STATUS" | grep -qi "disabled"; then
    add_finding "CRITICAL" "SIP" "System Integrity Protection is disabled" "This allows modification of system files and kernel extensions."
else
    add_finding "INFO" "SIP" "System Integrity Protection status" "$SIP_STATUS"
fi

# Summary
echo "" >> "$OUTPUT_FILE"
echo "=== Summary ===" >> "$OUTPUT_FILE"
echo "Critical: $(grep -c '\[SEVERITY: CRITICAL\]' "$OUTPUT_FILE" || echo 0)" >> "$OUTPUT_FILE"
echo "High: $(grep -c '\[SEVERITY: HIGH\]' "$OUTPUT_FILE" || echo 0)" >> "$OUTPUT_FILE"
echo "Medium: $(grep -c '\[SEVERITY: MEDIUM\]' "$OUTPUT_FILE" || echo 0)" >> "$OUTPUT_FILE"
echo "Info: $(grep -c '\[SEVERITY: INFO\]' "$OUTPUT_FILE" || echo 0)" >> "$OUTPUT_FILE"

echo ""
echo "=== Analysis Complete ==="
echo "Findings saved to: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
