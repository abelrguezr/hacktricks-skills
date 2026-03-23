#!/bin/bash
# Android Backup Extraction Script
# Usage: ./android_backup_extract.sh <backup.ab> [output_dir]

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup.ab> [output_dir]"
    echo "Example: $0 backup.ab ./extracted"
    exit 1
fi

BACKUP_FILE="$1"
OUTPUT_DIR="${2:-./extracted}"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file '$BACKUP_FILE' not found"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Extracting Android backup: $BACKUP_FILE"
echo "Output directory: $OUTPUT_DIR"

# Check if ABE is available
if ! command -v java &> /dev/null; then
    echo "Error: Java is required but not installed"
    exit 1
fi

# Find abe.jar (common locations)
ABE_JAR=""
for path in "./abe.jar" "~/abe.jar" "$HOME/abe.jar"; do
    if [ -f "$path" ]; then
        ABE_JAR="$path"
        break
    fi
done

if [ -z "$ABE_JAR" ]; then
    echo "Warning: abe.jar not found. Please ensure Android Backup Extractor is available."
    echo "Download from: https://sourceforge.net/projects/adbextractor/"
    echo "Placing it in the current directory or your home directory."
fi

# Unpack the backup
if [ -n "$ABE_JAR" ]; then
    echo "Unpacking backup with ABE..."
    java -jar "$ABE_JAR" unpack "$BACKUP_FILE" "$OUTPUT_DIR/backup.tar"
    
    # Extract the tar file
    echo "Extracting tar archive..."
    tar -xvf "$OUTPUT_DIR/backup.tar" -C "$OUTPUT_DIR/"
    
    echo "Extraction complete. Results in: $OUTPUT_DIR"
else
    echo "Skipping extraction - ABE not found"
    echo "Manual extraction commands:"
    echo "  java -jar abe.jar unpack $BACKUP_FILE $OUTPUT_DIR/backup.tar"
    echo "  tar -xvf $OUTPUT_DIR/backup.tar -C $OUTPUT_DIR/"
fi

# Calculate hash for integrity
if [ -f "$OUTPUT_DIR/backup.tar" ]; then
    echo ""
    echo "Integrity hash (SHA256):"
    sha256sum "$OUTPUT_DIR/backup.tar"
fi
