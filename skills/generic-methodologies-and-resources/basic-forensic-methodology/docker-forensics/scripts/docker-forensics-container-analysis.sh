#!/bin/bash
# Docker Container Forensics Analysis Script
# Usage: ./docker-forensics-container-analysis.sh <container_name_or_id>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <container_name_or_id>"
    echo "Example: $0 wordpress"
    exit 1
fi

CONTAINER="$1"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="forensics_report_${CONTAINER}_${TIMESTAMP}"

mkdir -p "$OUTPUT_DIR"

echo "=== Docker Container Forensics Analysis ==="
echo "Container: $CONTAINER"
echo "Output directory: $OUTPUT_DIR"
echo ""

# 1. Container status
echo "[1/7] Container status..."
docker ps -a --filter "id=$CONTAINER" > "$OUTPUT_DIR/container_status.txt"
cat "$OUTPUT_DIR/container_status.txt"
echo ""

# 2. Container diff
echo "[2/7] Container modifications (docker diff)..."
docker diff "$CONTAINER" > "$OUTPUT_DIR/container_diff.txt" 2>&1 || echo "Failed to run docker diff" >> "$OUTPUT_DIR/container_diff.txt"
cat "$OUTPUT_DIR/container_diff.txt"
echo ""

# 3. Container inspect
echo "[3/7] Container inspection..."
docker inspect "$CONTAINER" > "$OUTPUT_DIR/container_inspect.json" 2>&1 || echo "Failed to inspect container" >> "$OUTPUT_DIR/container_inspect.json"
echo "Saved to: $OUTPUT_DIR/container_inspect.json"
echo ""

# 4. Process list
echo "[4/7] Running processes in container..."
docker exec "$CONTAINER" ps auxf > "$OUTPUT_DIR/processes.txt" 2>&1 || echo "Failed to list processes" >> "$OUTPUT_DIR/processes.txt"
cat "$OUTPUT_DIR/processes.txt"
echo ""

# 5. Network connections
echo "[5/7] Network connections..."
docker exec "$CONTAINER" netstat -tulpn > "$OUTPUT_DIR/network_connections.txt" 2>&1 || \
docker exec "$CONTAINER" ss -tulpn > "$OUTPUT_DIR/network_connections.txt" 2>&1 || \
echo "Failed to get network connections" >> "$OUTPUT_DIR/network_connections.txt"
cat "$OUTPUT_DIR/network_connections.txt"
echo ""

# 6. Recent file modifications
echo "[6/7] Recently modified files..."
docker exec "$CONTAINER" find / -type f -mtime -1 2>/dev/null | head -50 > "$OUTPUT_DIR/recent_files.txt" || \
echo "Failed to find recent files" >> "$OUTPUT_DIR/recent_files.txt"
echo "Recent files (last 24h):"
head -20 "$OUTPUT_DIR/recent_files.txt"
echo ""

# 7. Suspicious files check
echo "[7/7] Checking for common suspicious files..."
SUSPICIOUS_FILES=(
    "/etc/shadow"
    "/etc/passwd"
    "/root/.ssh/authorized_keys"
    "/root/.bash_history"
    "/tmp/*"
    "/var/tmp/*"
    "/etc/crontab"
    "/etc/cron.d/*"
)

echo "Suspicious file check:" > "$OUTPUT_DIR/suspicious_files.txt"
for file in "${SUSPICIOUS_FILES[@]}"; do
    if docker exec "$CONTAINER" ls -la "$file" 2>/dev/null | grep -q .; then
        echo "FOUND: $file" >> "$OUTPUT_DIR/suspicious_files.txt"
        docker exec "$CONTAINER" ls -la "$file" >> "$OUTPUT_DIR/suspicious_files.txt" 2>&1
    else
        echo "NOT FOUND: $file" >> "$OUTPUT_DIR/suspicious_files.txt"
    fi
done
cat "$OUTPUT_DIR/suspicious_files.txt"
echo ""

echo "=== Analysis Complete ==="
echo "All reports saved to: $OUTPUT_DIR/"
echo ""
echo "Next steps:"
echo "1. Review $OUTPUT_DIR/container_diff.txt for modifications"
echo "2. Check $OUTPUT_DIR/suspicious_files.txt for concerning files"
echo "3. Use 'docker cp' to extract any suspicious files for deeper analysis"
