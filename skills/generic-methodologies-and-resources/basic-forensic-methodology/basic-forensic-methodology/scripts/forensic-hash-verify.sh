#!/bin/bash
# Forensic Hash Verification Script
# Calculates and verifies hash values for evidence files

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <evidence_file> [hash_file]"
    echo "  Without hash_file: calculates MD5, SHA1, SHA256"
    echo "  With hash_file: verifies against stored hashes"
    exit 1
fi

EVIDENCE_FILE="$1"
HASH_FILE="$2"

if [ ! -f "$EVIDENCE_FILE" ]; then
    echo "Error: Evidence file not found: $EVIDENCE_FILE"
    exit 1
fi

echo "=== Forensic Hash Analysis ==="
echo "File: $EVIDENCE_FILE"
echo "Size: $(du -h "$EVIDENCE_FILE" | cut -f1)"
echo ""

if [ -z "$HASH_FILE" ]; then
    # Calculate hashes
    echo "Calculating hash values..."
    echo ""
    echo "MD5:    $(md5sum "$EVIDENCE_FILE" | cut -d' ' -f1)"
    echo "SHA1:   $(sha1sum "$EVIDENCE_FILE" | cut -d' ' -f1)"
    echo "SHA256: $(sha256sum "$EVIDENCE_FILE" | cut -d' ' -f1)"
    echo ""
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
else
    # Verify against stored hashes
    if [ ! -f "$HASH_FILE" ]; then
        echo "Error: Hash file not found: $HASH_FILE"
        exit 1
    fi
    
    echo "Verifying against stored hashes..."
    if md5sum -c "$HASH_FILE" 2>/dev/null; then
        echo "✓ Hash verification PASSED"
    else
        echo "✗ Hash verification FAILED - Evidence may be compromised!"
        exit 1
    fi
fi

echo ""
echo "=== Analysis Complete ==="
