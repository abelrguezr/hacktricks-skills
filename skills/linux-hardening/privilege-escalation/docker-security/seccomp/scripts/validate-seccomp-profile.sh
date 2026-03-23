#!/bin/bash
# Validate a seccomp profile JSON file
# Usage: ./validate-seccomp-profile.sh profile.json

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <profile.json>" >&2
    exit 1
fi

PROFILE="$1"

if [ ! -f "$PROFILE" ]; then
    echo "Error: File not found: $PROFILE" >&2
    exit 1
fi

echo "Validating seccomp profile: $PROFILE"
echo "================================"

# Check if file is valid JSON
if ! python3 -m json.tool "$PROFILE" > /dev/null 2>&1; then
    echo "❌ Invalid JSON syntax"
    python3 -m json.tool "$PROFILE" 2>&1 | head -5
    exit 1
fi
echo "✓ Valid JSON syntax"

# Check for required fields
DEFAULT_ACTION=$(python3 -c "import json; print(json.load(open('$PROFILE')).get('defaultAction', ''))")

if [ -z "$DEFAULT_ACTION" ]; then
    echo "❌ Missing 'defaultAction' field"
    exit 1
fi
echo "✓ defaultAction: $DEFAULT_ACTION"

# Check for valid action values
VALID_ACTIONS="SCMP_ACT_ALLOW SCMP_ACT_KILL SCMP_ACT_TRAP SCMP_ACT_ERRNO SCMP_ACT_LOG"
if ! echo "$VALID_ACTIONS" | grep -q "$DEFAULT_ACTION"; then
    echo "❌ Invalid defaultAction: $DEFAULT_ACTION"
    echo "   Valid values: $VALID_ACTIONS"
    exit 1
fi
echo "✓ Valid defaultAction value"

# Count syscalls
SYSCALL_COUNT=$(python3 -c "import json; print(len(json.load(open('$PROFILE')).get('syscalls', [])))")
echo "✓ Syscall rules: $SYSCALL_COUNT"

# Check for common dangerous syscalls in whitelist
if [ "$DEFAULT_ACTION" = "SCMP_ACT_ALLOW" ]; then
    echo ""
    echo "⚠ Warning: Using blacklist mode (defaultAction: ALLOW)"
    echo "  Consider using whitelist mode (defaultAction: KILL) for better security"
fi

# List blocked syscalls if in whitelist mode
if [ "$DEFAULT_ACTION" = "SCMP_ACT_KILL" ]; then
    echo ""
    echo "Allowed syscalls:"
    python3 -c "
import json
profile = json.load(open('$PROFILE'))
for rule in profile.get('syscalls', []):
    if rule.get('action') == 'SCMP_ACT_ALLOW':
        print(f'  - {rule.get(\"name\")}')
" | head -20
    if [ "$SYSCALL_COUNT" -gt 20 ]; then
        echo "  ... and $((SYSCALL_COUNT - 20)) more"
    fi
fi

echo ""
echo "✓ Profile validation complete"
