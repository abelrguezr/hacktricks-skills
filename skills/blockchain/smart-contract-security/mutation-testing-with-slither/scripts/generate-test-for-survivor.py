#!/usr/bin/env python3
"""Generate test case suggestions for surviving mutants."""

import json
import sys
from pathlib import Path

def suggest_test_for_survivor(survivor: dict) -> str:
    """Generate test suggestions based on survivor type."""
    
    mutator = survivor.get("mutator", "")
    original = survivor.get("original", "")
    contract = survivor.get("contract", "")
    line = survivor.get("line", "")
    
    suggestions = []
    
    # Comment Replacement - entire line was removed
    if mutator == "CR":
        suggestions.append(f"""// Survivor: {contract}:{line} [CR]
// The line '{original}' was commented out but tests still passed.
// This suggests missing post-state assertions.

// Test suggestion: Add assertions that verify the effect of this line
// For example, if this line assigns a value, assert that value changed:
function test_{contract}_line{line}_assertsState() public {{
    // Capture state before
    uint256 before = /* capture relevant state */;
    
    // Execute the function
    /* call the function that contains line {line} */;
    
    // Assert state changed as expected
    uint256 after = /* capture same state */;
    assertNotEq(before, after, "State should have changed");
    
    // Also assert the specific value is correct
    assertEq(after, /* expected value */, "Value should be correct");
}}
""")
    
    # Operator replacement
    elif mutator in ["AR", "OR", "UR"]:  # Arithmetic, Operator, Unary replacement
        suggestions.append(f"""// Survivor: {contract}:{line} [{mutator}]
// Operator was replaced but tests still passed.
// Add boundary tests for the operator.

// Test suggestion: Test boundary conditions
function test_{contract}_line{line}_boundary() public {{
    // Test the exact boundary value
    /* test with value that makes the condition exactly true/false */
    
    // Test just above and below the boundary
    /* test with value - 1 and value + 1 */
    
    // Test edge cases: 0, max uint256, etc.
}}
""")
    
    # Constant replacement
    elif mutator in ["CR", "TR"]:  # Constant, Type replacement
        suggestions.append(f"""// Survivor: {contract}:{line} [{mutator}]
// Constant was replaced but tests still passed.
// Add tests that specifically check this constant value.

// Test suggestion: Test with the specific constant
function test_{contract}_line{line}_constant() public {{
    // Test with the exact constant value
    /* test with the constant that was mutated */
    
    // Test with 0 and 1 (common mutation targets)
    /* test with 0 */
    /* test with 1 */
}}
""")
    
    # Revert replacement
    elif mutator == "RR":
        suggestions.append(f"""// Survivor: {contract}:{line} [RR]
// Line was replaced with revert() but tests still passed.
// This suggests the function's effects aren't properly asserted.

// Test suggestion: Assert that the function actually does something
function test_{contract}_line{line}_hasEffect() public {{
    // Capture state before
    /* capture relevant state */
    
    // Execute the function
    /* call the function */
    
    // Assert state changed
    /* assert that something changed */
    
    // Assert events were emitted if applicable
    /* assert events */
}}
""")
    
    # Default suggestion
    else:
        suggestions.append(f"""// Survivor: {contract}:{line} [{mutator}]
// Mutation survived - tests need strengthening.

// General approach:
// 1. Identify what this line is supposed to do
// 2. Add assertions that verify the post-state
// 3. Test boundary conditions
// 4. Add invariant checks if applicable

function test_{contract}_line{line}_strengthened() public {{
    // TODO: Add specific assertions for this mutation
}}
""")
    
    return "\n".join(suggestions)

def main():
    if len(sys.argv) < 2:
        print("Usage: python generate-test-for-survivor.py <survivor-json>")
        print("Example: python generate-test-for-survivor.py survivor.json")
        sys.exit(1)
    
    input_path = sys.argv[1]
    
    if not Path(input_path).exists():
        print(f"Error: File not found: {input_path}")
        sys.exit(1)
    
    with open(input_path, 'r') as f:
        data = json.load(f)
    
    # Handle both single survivor and list of survivors
    survivors = data if isinstance(data, list) else [data]
    
    for i, survivor in enumerate(survivors, 1):
        print(f"\n{'='*60}")
        print(f"Survivor {i}: {survivor.get('contract', 'unknown')}:{survivor.get('line', 'unknown')}")
        print('='*60)
        print(suggest_test_for_survivor(survivor))

if __name__ == "__main__":
    main()
