#!/bin/bash
# Find CCACHE tickets in /tmp and other common locations

echo "=== Finding CCACHE Tickets ==="
echo ""

# Check current KRB5CCNAME
echo "Current KRB5CCNAME:"
env | grep KRB5CCNAME || echo "Not set"
echo ""

# Find tickets in /tmp
echo "Tickets in /tmp:"
ls -la /tmp/krb5cc_* 2>/dev/null || echo "No tickets found in /tmp"
echo ""

# Find tickets in /var/tmp
echo "Tickets in /var/tmp:"
ls -la /var/tmp/krb5cc_* 2>/dev/null || echo "No tickets found in /var/tmp"
echo ""

# Find tickets in user home directories
echo "Tickets in home directories:"
find /home -name "krb5cc_*" 2>/dev/null || echo "No tickets found in /home"
echo ""

# Find tickets in /root
echo "Tickets in /root:"
ls -la /root/krb5cc_* 2>/dev/null || echo "No tickets found in /root"
echo ""

# List all krb5cc files system-wide (requires root)
echo "All krb5cc files (may require root):"
find / -name "krb5cc_*" 2>/dev/null | head -20 || echo "Search completed"
echo ""

# Check for extracted tickets from tickey
echo "Tickets extracted by tickey:"
ls -la /tmp/__krb_*.ccache 2>/dev/null || echo "No tickey-extracted tickets found"
echo ""

echo "=== Done ==="
