#!/bin/bash
# scan-org.sh - Scan all repositories in a GitHub organization for secrets
# Usage: ./scan-org.sh --org <org-name> [--output <dir>] [--tool <gitleaks|trufflehog>]

set -e

ORG=""
OUTPUT_DIR="./org-scan-results"
TOOL="gitleaks"
LIMIT=100

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --org)
            ORG="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --tool)
            TOOL="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$ORG" ]]; then
    echo "Usage: $0 --org <org-name> [--output <dir>] [--tool <gitleaks|trufflehog>]"
    exit 1
fi

# Check for required tools
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is required but not installed"
    echo "Install with: brew install gh (macOS) or see https://cli.github.com/"
    exit 1
fi

if [[ "$TOOL" == "gitleaks" ]] && ! command -v gitleaks &> /dev/null; then
    echo "Error: gitleaks is required but not installed"
    echo "Install with: go install github.com/gitleaks/gitleaks@latest"
    exit 1
fi

if [[ "$TOOL" == "trufflehog" ]] && ! command -v trufflehog &> /dev/null; then
    echo "Error: trufflehog is required but not installed"
    echo "Install with: go install github.com/trufflesecurity/trufflehog/v3@latest"
    exit 1
fi

echo "=== Scanning organization: $ORG ==="
echo "Tool: $TOOL"
echo "Limit: $LIMIT repos"
echo "Output: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Get list of repos
echo "Fetching repository list..."
REPOS=$(gh repo list "$ORG" --limit "$LIMIT" --json nameWithOwner,url --template '{{range .}}{{.nameWithOwner}}|{{.url}}{{"\n"}}{{end}}')

REPO_COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')
echo "Found $REPO_COUNT repositories"
echo ""

# Initialize summary file
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
echo "Organization: $ORG" > "$SUMMARY_FILE"
echo "Scan date: $(date)" >> "$SUMMARY_FILE"
echo "Tool: $TOOL" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Scan each repo
TMP_DIR=$(mktemp -d)
FAILED=0
SUCCESS=0

while IFS='|' read -r NAME URL; do
    [[ -z "$NAME" ]] && continue
    
    echo "Scanning: $NAME"
    
    REPO_DIR="$TMP_DIR/$NAME"
    mkdir -p "$REPO_DIR"
    
    # Clone repo (shallow for speed)
    if git clone --depth 1 "$URL" "$REPO_DIR" 2>/dev/null; then
        # Run scanner
        RESULT_FILE="$OUTPUT_DIR/${NAME}.txt"
        
        if [[ "$TOOL" == "gitleaks" ]]; then
            gitleaks detect --source "$REPO_DIR" -v 2>&1 | tee "$RESULT_FILE" || true
        else
            trufflehog git file://"$REPO_DIR" --only-verified 2>&1 | tee "$RESULT_FILE" || true
        fi
        
        # Check for findings
        FINDINGS=$(grep -c "Found\|Finding" "$RESULT_FILE" 2>/dev/null || echo "0")
        echo "  $NAME: $FINDINGS findings" >> "$SUMMARY_FILE"
        
        if [[ "$FINDINGS" -gt 0 ]]; then
            echo "  ⚠️  $NAME: $FINDINGS potential secrets found!"
        else
            echo "  ✓ $NAME: clean"
        fi
        
        ((SUCCESS++))
    else
        echo "  ✗ $NAME: failed to clone"
        echo "  $NAME: FAILED TO CLONE" >> "$SUMMARY_FILE"
        ((FAILED++))
    fi
    
    # Cleanup
    rm -rf "$REPO_DIR"
done <<< "$REPOS"

# Cleanup temp directory
rm -rf "$TMP_DIR"

echo ""
echo "=== Scan complete ==="
echo "Successful: $SUCCESS"
echo "Failed: $FAILED"
echo ""
echo "Results saved to: $OUTPUT_DIR"
echo "Summary: $SUMMARY_FILE"

# Show repos with findings
echo ""
echo "=== Repositories with findings ==="
grep -v "0 findings" "$SUMMARY_FILE" | grep -v "^Organization\|^Scan date\|^Tool\|^$" || echo "None"
