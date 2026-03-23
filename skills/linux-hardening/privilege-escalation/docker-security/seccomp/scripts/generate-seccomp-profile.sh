#!/bin/bash
# Generate a seccomp whitelist profile from strace output
# Usage: ./generate-seccomp-profile.sh < strace_output.txt > profile.json
#
# This script parses strace output and creates a whitelist seccomp profile
# allowing only the syscalls observed in the trace.

set -e

if [ ! -t 0 ]; then
    # Reading from stdin (strace output)
    STRACE_INPUT=$(cat)
else
    echo "Usage: $0 < strace_output.txt > profile.json" >&2
    echo "Example: docker run --rm busybox strace ls | $0 > profile.json" >&2
    exit 1
fi

# Extract unique syscall names from strace output
# strace format: syscall_name(args...) = return_value
SYSCALLS=$(echo "$STRACE_INPUT" | \
    grep -oE '^[a-z_]+\(' | \
    sed 's/(//' | \
    sort -u | \
    grep -v '^$')

# Essential syscalls that should always be allowed
ESSENTIAL_SYSCALLS="exit exit_group sigreturn brk mmap munmap mprotect"

# Combine observed syscalls with essential ones
ALL_SYSCALLS=$(echo -e "$SYSSCALLS\n$ESSENTIAL_SYSCALLS" | sort -u | grep -v '^$')

# Generate JSON profile
echo '{'
echo '  "defaultAction": "SCMP_ACT_KILL",'
echo '  "syscalls": ['

FIRST=true
for syscall in $ALL_SYSCALLS; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo ','
    fi
    printf '    {"name": "%s", "action": "SCMP_ACT_ALLOW"}' "$syscall"
done

echo ''
echo '  ]'
echo '}'
