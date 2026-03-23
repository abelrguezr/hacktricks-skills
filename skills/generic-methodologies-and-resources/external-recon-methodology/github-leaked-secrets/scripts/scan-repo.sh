#!/bin/bash
# scan-repo.sh - Scan a repository for leaked secrets using multiple tools
# Usage: ./scan-repo.sh <repo-path> [--all-tools]

set -e

REPO_PATH="${1:-.}"
USE_ALL_TOOLS="${2:-}"

if [[ ! -d "$REPO_PATH" ]]; then
    echo "Error: Repository path '$REPO_PATH' does not exist"
    exit 1
fi

echo "=== Scanning repository: $REPO_PATH ==="
echo ""

# Create output directory
OUTPUT_DIR="$(mktemp -d)"
echo "Results will be saved to: $OUTPUT_DIR"

# Gitleaks scan
echo "[1/4] Running Gitleaks..."
if command -v gitleaks &> /dev/null; then
    gitleaks detect -v --source "$REPO_PATH" 2>&1 | tee "$OUTPUT_DIR/gitleaks.txt" || true
else
    echo "  Gitleaks not installed, skipping..."
fi

# TruffleHog scan
echo ""
echo "[2/4] Running TruffleHog..."
if command -v trufflehog &> /dev/null; then
    trufflehog git file://"$REPO_PATH" --only-verified 2>&1 | tee "$OUTPUT_DIR/trufflehog.txt" || true
else
    echo "  TruffleHog not installed, skipping..."
fi

# ggshield scan
echo ""
echo "[3/4] Running ggshield..."
if command -v ggshield &> /dev/null; then
    ggshield secret scan path -r "$REPO_PATH" 2>&1 | tee "$OUTPUT_DIR/ggshield.txt" || true
else
    echo "  ggshield not installed, skipping..."
fi

# Nosey Parker scan
echo ""
echo "[4/4] Running Nosey Parker..."
if command -v noseyparker &> /dev/null; then
    noseyparker scan --datastore "$OUTPUT_DIR/np.db" "$REPO_PATH" 2>&1 | tee "$OUTPUT_DIR/noseyparker-scan.txt" || true
    noseyparker report --datastore "$OUTPUT_DIR/np.db" 2>&1 | tee "$OUTPUT_DIR/noseyparker-report.txt" || true
else
    echo "  Nosey Parker not installed, skipping..."
fi

echo ""
echo "=== Scan complete ==="
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "Summary:"
for f in "$OUTPUT_DIR"/*.txt; do
    if [[ -f "$f" ]]; then
        count=$(grep -c "Found\|Finding\|secret" "$f" 2>/dev/null || echo "0")
        echo "  $(basename "$f"): $count potential findings"
    fi
done
