#!/bin/bash
# Run slither-mutate on Solidity contracts
# Usage: ./run-mutation-test.sh [contract-path] [test-cmd]

set -e

CONTRACT_PATH="${1:-./src/contracts}"
TEST_CMD="${2:-forge test}"
OUTPUT_DIR="./mutation_campaign"

# Check slither version
if ! command -v slither-mutate &> /dev/null; then
    echo "Error: slither-mutate not found. Install with: pip install slither-analyzer>=0.10.2"
    exit 1
fi

SLITHER_VERSION=$(slither --version 2>/dev/null || echo "unknown")
echo "Using Slither version: $SLITHER_VERSION"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run mutation testing
echo "Running mutation testing on: $CONTRACT_PATH"
echo "Test command: $TEST_CMD"
echo "Output directory: $OUTPUT_DIR"
echo ""

slither-mutate "$CONTRACT_PATH" \
    --test-cmd="$TEST_CMD" \
    --output "$OUTPUT_DIR" \
    2>&1 | tee "$OUTPUT_DIR/mutation.log"

# Generate summary
echo ""
echo "=== Mutation Testing Summary ==="
echo "Total mutants: $(grep -c 'Mutating' "$OUTPUT_DIR/mutation.log" 2>/dev/null || echo 0)"
echo "Killed: $(grep -c 'KILLED' "$OUTPUT_DIR/mutation.log" 2>/dev/null || echo 0)"
echo "Uncaught: $(grep -c 'UNCAUGHT' "$OUTPUT_DIR/mutation.log" 2>/dev/null || echo 0)"
echo ""
echo "Surviving mutants are in: $OUTPUT_DIR/"
echo "Review them with: cat $OUTPUT_DIR/mutation.log | grep UNCAUGHT"
