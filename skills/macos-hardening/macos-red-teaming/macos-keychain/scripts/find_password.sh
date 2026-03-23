#!/bin/bash
# Find and display a generic password for a specific account
# Usage: ./find_password.sh "AccountName"

if [ -z "$1" ]; then
    echo "Usage: $0 \"AccountName\""
    echo "Example: $0 \"Slack\""
    exit 1
fi

security find-generic-password -a "$1" -g
