#!/bin/bash
# Docker Image Security Scanner
# Scans a Docker image for vulnerabilities using multiple tools

set -e

IMAGE="${1:-}"
OUTPUT_DIR="${2:-./scan-results}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image-name> [output-dir]"
    echo "Example: $0 myapp:latest ./results"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "=== Docker Image Security Scan ==="
echo "Image: $IMAGE"
echo "Output: $OUTPUT_DIR"
echo ""

# Check if trivy is available
if command -v trivy &> /dev/null; then
    echo "[1/3] Running Trivy scan..."
    trivy image \
        --format json \
        --output "$OUTPUT_DIR/trivy-results.json" \
        --severity HIGH,CRITICAL \
        "$IMAGE" 2>/dev/null || echo "Trivy scan completed with warnings"
    
    trivy image \
        --format table \
        --severity HIGH,CRITICAL \
        "$IMAGE" 2>/dev/null || true
else
    echo "[1/3] Trivy not installed, skipping..."
    echo "Install with: go install github.com/aquasecurity/trivy@latest"
fi

echo ""

# Check if snyk is available
if command -v snyk &> /dev/null; then
    echo "[2/3] Running Snyk scan..."
    snyk container test "$IMAGE" \
        --json-file-output="$OUTPUT_DIR/snyk-results.json" \
        --severity-threshold=high 2>/dev/null || echo "Snyk scan completed with warnings"
else
    echo "[2/3] Snyk not installed, skipping..."
    echo "Install with: npm install -g snyk"
fi

echo ""

# Check if docker scan is available
if docker scan --help &> /dev/null 2>&1; then
    echo "[3/3] Running Docker scan..."
    docker scan "$IMAGE" 2>/dev/null || echo "Docker scan completed with warnings"
else
    echo "[3/3] Docker scan not available, skipping..."
fi

echo ""
echo "=== Scan Complete ==="
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Review vulnerabilities in $OUTPUT_DIR"
echo "2. Update base image if critical vulnerabilities found"
echo "3. Rebuild and rescan"
