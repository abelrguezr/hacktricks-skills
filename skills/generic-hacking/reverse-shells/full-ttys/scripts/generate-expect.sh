#!/bin/bash
# Generate an expect script for interacting with programs without TTY
# Usage: ./generate-expect.sh <command> <password> <prompt_pattern>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <command> <password> [prompt_pattern]"
    echo "Example: $0 'sudo cat /root/root.txt' 'mypassword' 'password'"
    exit 1
fi

COMMAND="$1"
PASSWORD="$2"
PROMPT="${3:-password}"

OUTPUT_FILE="expect_script.exp"

cat > "$OUTPUT_FILE" << EOF
#!/usr/bin/expect -f
set timeout 30
spawn $COMMAND
expect "*$PROMPT*"
send "$PASSWORD\\r"
interact
EOF

chmod +x "$OUTPUT_FILE"

echo "Generated expect script: $OUTPUT_FILE"
echo ""
echo "Content:"
cat "$OUTPUT_FILE"
echo ""
echo "Run it with: ./expect_script.exp"
