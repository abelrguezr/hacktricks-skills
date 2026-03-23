#!/bin/bash
# Reconstruct iOS backup from hashed layout to readable paths
# Usage: ./reconstruct_backup.sh <backup_path> <output_path>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <backup_path> <output_path>"
    echo "Example: $0 /path/to/backup /tmp/reconstructed"
    exit 1
fi

BACKUP_PATH="$1"
OUTPUT_PATH="$2"

# Check for required tools
if ! command -v elegant-bouncer &> /dev/null; then
    echo "[!] elegant-bouncer not found. Installing..."
    pip install elegant-bouncer 2>/dev/null || echo "[!] Install elegant-bouncer manually"
fi

if ! command -v mvt-ios &> /dev/null; then
    echo "[!] mvt-ios not found. Install: pip install mvt-ios"
fi

echo "[+] Reconstructing iOS backup..."
echo "    Source: $BACKUP_PATH"
echo "    Output: $OUTPUT_PATH"

# Create output directory
mkdir -p "$OUTPUT_PATH"

# Method 1: Use elegant-bouncer (preferred)
if command -v elegant-bouncer &> /dev/null; then
    echo "[+] Using elegant-bouncer for reconstruction..."
    elegant-bouncer --ios-extract "$BACKUP_PATH" --output "$OUTPUT_PATH"
    echo "✓ Reconstruction complete"
    exit 0
fi

# Method 2: Manual reconstruction using Manifest.db
echo "[+] Using manual reconstruction via Manifest.db..."

MANIFEST_DB="$BACKUP_PATH/Manifest.db"
if [ ! -f "$MANIFEST_DB" ]; then
    echo "[!] Manifest.db not found at $MANIFEST_DB"
    exit 1
fi

# Extract file records and reconstruct paths
sqlite3 "$MANIFEST_DB" "SELECT domain, relativePath, fileID FROM files;" | \
while IFS='|' read -r domain relpath fileid; do
    # Create directory structure
    target_dir="$OUTPUT_PATH/$domain/$relpath"
    target_dir=$(dirname "$target_dir")
    mkdir -p "$target_dir"
    
    # Copy or hardlink the file
    source_file="$BACKUP_PATH/$fileid"
    if [ -f "$source_file" ]; then
        cp "$source_file" "$target_dir/" 2>/dev/null || \
        ln "$source_file" "$target_dir/" 2>/dev/null || true
    fi
done

echo "✓ Manual reconstruction complete"
echo "[+] Output available at: $OUTPUT_PATH"
