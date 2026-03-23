#!/bin/bash
# Configure bash to hide command history for security

echo "Configuring history hiding..."

# Set history variables
export HISTFILESIZE=0
export HISTSIZE=0
export HISTCONTROL=ignorespace

# Add to shell config if not already present
CONFIG_FILE="$HOME/.bashrc"

for var in HISTFILESIZE HISTSIZE HISTCONTROL; do
    if ! grep -q "^export $var=" "$CONFIG_FILE" 2>/dev/null; then
        case $var in
            HISTFILESIZE) echo "export $var=0" >> "$CONFIG_FILE" ;;
            HISTSIZE) echo "export $var=0" >> "$CONFIG_FILE" ;;
            HISTCONTROL) echo "export $var=ignorespace" >> "$CONFIG_FILE" ;;
        esac
    fi
done

echo "History hiding configured."
echo ""
echo "Current settings:"
echo "  HISTFILESIZE=$HISTFILESIZE"
echo "  HISTSIZE=$HISTSIZE"
echo "  HISTCONTROL=$HISTCONTROL"
echo ""
echo "Commands starting with a space will not be saved."
echo "Run 'source ~/.bashrc' to apply to new sessions."
