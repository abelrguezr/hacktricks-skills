#!/bin/bash
# Hash identification helper for CTF challenges
# Usage: hash-identify.sh <hash>

if [ -z "$1" ]; then
    echo "Usage: hash-identify.sh <hash>"
    echo "Example: hash-identify.sh 5f4dcc3b5aa765d61d8327deb882cf99"
    exit 1
fi

HASH="$1"

echo "=== Hash Identification ==="
echo "Input: $HASH"
echo "Length: ${#HASH} characters"
echo ""

# Check for common format indicators
if [[ "$HASH" =~ ^\$2[aby]\$ ]]; then
    echo "✓ Detected: bcrypt"
    echo "  Hashcat mode: 3200"
    echo "  John format: bcrypt"
    exit 0
fi

if [[ "$HASH" =~ ^\$6\$ ]]; then
    echo "✓ Detected: SHA-512 crypt"
    echo "  Hashcat mode: 1800"
    echo "  John format: sha512crypt"
    exit 0
fi

if [[ "$HASH" =~ ^\$5\$ ]]; then
    echo "✓ Detected: SHA-256 crypt"
    echo "  Hashcat mode: 1700"
    echo "  John format: sha256crypt"
    exit 0
fi

if [[ "$HASH" =~ ^\$2y\$ ]]; then
    echo "✓ Detected: bcrypt (alternative)"
    echo "  Hashcat mode: 3200"
    echo "  John format: bcrypt"
    exit 0
fi

if [[ "$HASH" =~ ^\$3\$ ]]; then
    echo "✓ Detected: MD5 crypt"
    echo "  Hashcat mode: 100"
    echo "  John format: md5crypt"
    exit 0
fi

if [[ "$HASH" =~ ^\$4\$ ]]; then
    echo "✓ Detected: SHA-256 crypt (alternative)"
    echo "  Hashcat mode: 1700"
    echo "  John format: sha256crypt"
    exit 0
fi

# Check hash length for common algorithms
LEN=${#HASH}

case $LEN in
    32)
        echo "✓ Likely: MD5 (32 hex chars)"
        echo "  Hashcat mode: 0"
        echo "  John format: md5"
        ;;
    40)
        echo "✓ Likely: SHA-1 (40 hex chars)"
        echo "  Hashcat mode: 100"
        echo "  John format: sha1"
        ;;
    64)
        echo "✓ Likely: SHA-256 (64 hex chars)"
        echo "  Hashcat mode: 1400"
        echo "  John format: sha256"
        ;;
    128)
        echo "✓ Likely: SHA-512 (128 hex chars)"
        echo "  Hashcat mode: 1700"
        echo "  John format: sha512"
        ;;
    32|40|64|128)
        echo "✓ Length matches common hash (see above)"
        ;;
    *)
        echo "? Unusual length: $LEN characters"
        echo "  Try: hashid '$HASH'"
        ;;
esac

echo ""
echo "=== Next Steps ==="
echo "1. Save hash to file: echo '$HASH' > hashes.txt"
echo "2. Try hashcat: hashcat -m <mode> -a 0 hashes.txt wordlist.txt"
echo "3. Or try John: john --wordlist=wordlist.txt --format=<fmt> hashes.txt"
