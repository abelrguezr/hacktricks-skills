#!/bin/bash
# Docker Image Forensics Analysis Script
# Usage: ./docker-forensics-image-analysis.sh <image_name_or_tar_file>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <image_name_or_tag>"
    echo "Example: $0 nginx:latest"
    echo "Or: $0 image.tar (for tar files)"
    exit 1
fi

INPUT="$1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Determine if input is a tar file or image name
if [[ "$INPUT" == *.tar ]]; then
    IS_TAR=true
    IMAGE_NAME="imported_image_${TIMESTAMP}"
    echo "Loading image from tar file: $INPUT"
    docker load -i "$INPUT" > /dev/null 2>&1
    IMAGE="$IMAGE_NAME"
else
    IS_TAR=false
    IMAGE="$INPUT"
    echo "Analyzing image: $IMAGE"
fi

OUTPUT_DIR="image_forensics_${IMAGE//\//_}_${TIMESTAMP}"
mkdir -p "$OUTPUT_DIR"

echo "=== Docker Image Forensics Analysis ==="
echo "Image: $IMAGE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# 1. Image inspect
echo "[1/6] Image inspection..."
docker inspect "$IMAGE" > "$OUTPUT_DIR/image_inspect.json" 2>&1
echo "Saved to: $OUTPUT_DIR/image_inspect.json"
echo ""

# 2. Image history
echo "[2/6] Image history..."
docker history --no-trunc "$IMAGE" > "$OUTPUT_DIR/image_history.txt" 2>&1
cat "$OUTPUT_DIR/image_history.txt"
echo ""

# 3. Export image for analysis
echo "[3/6] Exporting image for analysis..."
EXPORT_FILE="$OUTPUT_DIR/image_export.tar"
docker save "$IMAGE" > "$EXPORT_FILE" 2>&1
echo "Exported to: $EXPORT_FILE"
echo "Size: $(du -h $EXPORT_FILE | cut -f1)"
echo ""

# 4. Extract and analyze layers
echo "[4/6] Extracting image layers..."
LAYER_DIR="$OUTPUT_DIR/layers"
mkdir -p "$LAYER_DIR"
cd "$LAYER_DIR"
tar -xf "$EXPORT_FILE"

# Decompress all layers
for d in $(find * -maxdepth 0 -type d); do
    if [ -f "$d/layer.tar" ]; then
        echo "Extracting layer: $d"
        mkdir -p "$d/extracted"
        cd "$d"
        tar -xf ./layer.tar -C ./extracted
        cd ..
    fi
done
cd - > /dev/null

# Count files in each layer
echo "Layer file counts:"
for d in $(find "$LAYER_DIR" -maxdepth 1 -type d -mindepth 1); do
    if [ -d "$d/extracted" ]; then
        FILE_COUNT=$(find "$d/extracted" -type f 2>/dev/null | wc -l)
        echo "  $d: $FILE_COUNT files"
    fi
done
echo ""

# 5. Find suspicious files across layers
echo "[5/6] Searching for suspicious files..."
SUSPICIOUS_PATTERNS=(
    "*.sh"
    "*.py"
    "*.pl"
    "*.rb"
    ".env"
    "credentials"
    "password"
    "secret"
    "api_key"
    "id_rsa"
    "authorized_keys"
)

echo "Suspicious file search results:" > "$OUTPUT_DIR/suspicious_files.txt"
for pattern in "${SUSPICIOUS_PATTERNS[@]}"; do
    RESULTS=$(find "$LAYER_DIR" -name "$pattern" 2>/dev/null | head -20)
    if [ -n "$RESULTS" ]; then
        echo "Pattern '$pattern':" >> "$OUTPUT_DIR/suspicious_files.txt"
        echo "$RESULTS" >> "$OUTPUT_DIR/suspicious_files.txt"
        echo ""
    fi
done
cat "$OUTPUT_DIR/suspicious_files.txt"
echo ""

# 6. Check for common binaries
echo "[6/6] Checking for common binaries..."
BINARIES=("/bin/bash" "/bin/sh" "/usr/bin/curl" "/usr/bin/wget" "/usr/bin/nc" "/usr/bin/netcat")
echo "Binary check:" > "$OUTPUT_DIR/binaries.txt"
for bin in "${BINARIES[@]}"; do
    FOUND=$(find "$LAYER_DIR" -name "$(basename $bin)" 2>/dev/null | head -5)
    if [ -n "$FOUND" ]; then
        echo "FOUND: $bin" >> "$OUTPUT_DIR/binaries.txt"
        echo "$FOUND" >> "$OUTPUT_DIR/binaries.txt"
    else
        echo "NOT FOUND: $bin" >> "$OUTPUT_DIR/binaries.txt"
    fi
done
cat "$OUTPUT_DIR/binaries.txt"
echo ""

# Cleanup if we imported from tar
if [ "$IS_TAR" = true ]; then
    echo "Cleaning up imported image..."
    docker rmi "$IMAGE" > /dev/null 2>&1 || true
fi

echo "=== Analysis Complete ==="
echo "All reports saved to: $OUTPUT_DIR/"
echo ""
echo "Key files to review:"
echo "  - $OUTPUT_DIR/image_history.txt (layer-by-layer changes)"
echo "  - $OUTPUT_DIR/suspicious_files.txt (potential indicators)"
echo "  - $OUTPUT_DIR/binaries.txt (installed tools)"
echo "  - $OUTPUT_DIR/layers/ (extracted layer contents)"
echo ""
echo "For deeper analysis, consider using:"
echo "  - container-diff analyze -t history $EXPORT_FILE"
echo "  - dive $IMAGE (if still available)"
