#!/bin/bash
# List all UTS namespaces on the system with process counts
# Usage: ./list-uts-namespaces.sh

set -e

echo "=== All UTS Namespaces on System ==="
echo ""

# Get all unique UTS namespaces
NAMESPACES=$(sudo find /proc -maxdepth 3 -type l -name uts -exec readlink {} \; 2>/dev/null | sort -u)

if [ -z "$NAMESPACES" ]; then
    echo "No UTS namespaces found (may need root access)"
    exit 1
fi

echo "Namespace ID          | Process Count | Sample PIDs"
echo "----------------------|---------------|------------"

for ns in $NAMESPACES; do
    NS_ID=$(echo "$ns" | grep -oP '\[\K[0-9]+')
    
    # Count processes in this namespace
    COUNT=$(sudo find /proc -maxdepth 3 -type l -name uts -exec ls -l {} \; 2>/dev/null | grep "$NS_ID" | wc -l)
    
    # Get sample PIDs (first 3)
    SAMPLE_PIDS=$(sudo find /proc -maxdepth 3 -type l -name uts -exec ls -l {} \; 2>/dev/null | grep "$NS_ID" | awk '{print $NF}' | sed 's|.*/proc/||' | sed 's|/uts||' | head -3 | tr '\n' ',' | sed 's/,$//')
    
    printf "%-20s | %-13s | %s\n" "$ns" "$COUNT" "$SAMPLE_PIDs"
done

echo ""
echo "Total unique UTS namespaces: $(echo "$NAMESPACES" | wc -l)"
