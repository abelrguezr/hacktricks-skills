#!/bin/bash
# Check current user ID state
# Usage: ./check_user_ids.sh

echo "=== Current User ID State ==="
echo ""
echo "id output:"
id
echo ""
echo "Detailed breakdown:"
echo "  UID (ruid):  $(id -u)"
echo "  EUID:        $(id -u -e)"
echo "  GID:         $(id -g)"
echo "  EGID:        $(id -g -e)"
echo ""
echo "Process info:"
ps -p $$ -o pid,uid,euid,suid,args 2>/dev/null || echo "  (suid column not available on this system)"
echo ""
echo "=== Notes ==="
echo "- If UID != EUID, the process is running with different effective privileges"
echo "- SUID binaries typically have EUID matching the file owner"
echo "- Use 'strace -e trace=setuid,setreuid,setresuid' to trace ID changes"
