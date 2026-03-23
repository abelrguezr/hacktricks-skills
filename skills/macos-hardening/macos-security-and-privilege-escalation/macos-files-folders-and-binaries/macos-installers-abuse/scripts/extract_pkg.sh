#!/bin/bash
# macOS Installer Package Extractor
# Extracts .pkg files to analyze their contents

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <package.pkg> <output_directory>"
    echo "Example: $0 /path/to/installer.pkg /tmp/analysis/"
    exit 1
fi

PKG_FILE="$1"
OUTPUT_DIR="$2"

if [ ! -f "$PKG_FILE" ]; then
    echo "Error: Package file not found: $PKG_FILE"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo "Extracting package: $PKG_FILE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Method 1: Use pkgutil (preferred, cleaner)
if command -v pkgutil &> /dev/null; then
    echo "Using pkgutil to extract package..."
    pkgutil --expand "$PKG_FILE" "$OUTPUT_DIR"
    echo "Package extracted successfully."
else
    echo "pkgutil not found, using manual extraction..."
    
    # Method 2: Manual extraction with xar
    if command -v xar &> /dev/null; then
        echo "Extracting archive with xar..."
        xar -xf "$PKG_FILE"
        
        # Extract CPIO archives if they exist
        if [ -f "Scripts" ]; then
            echo "Extracting Scripts archive..."
            mkdir -p scripts_extracted
            cd scripts_extracted
            cat ../Scripts | gzip -dc | cpio -i 2>/dev/null || cpio -i < ../Scripts 2>/dev/null || true
            cd ..
        fi
        
        if [ -f "Payload" ]; then
            echo "Extracting Payload archive..."
            mkdir -p payload_extracted
            cd payload_extracted
            cat ../Payload | gzip -dc | cpio -i 2>/dev/null || cpio -i < ../Payload 2>/dev/null || true
            cd ..
        fi
        
        echo "Package extracted successfully."
    else
        echo "Error: Neither pkgutil nor xar is available."
        echo "Install xar: brew install xar"
        exit 1
    fi
fi

echo ""
echo "Extraction complete. Contents:"
ls -la
echo ""
echo "Next steps:"
echo "  1. Review Distribution file: cat Distribution"
echo "  2. Check PackageInfo: cat PackageInfo"
echo "  3. Extract scripts: cat Scripts | gzip -dc | cpio -i"
echo "  4. Run analysis: ./scripts/analyze_pkg.sh $OUTPUT_DIR"
