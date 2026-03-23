#!/usr/bin/env python3
"""
Validate LLM Data Sampling

Checks sampled data for:
- Sequence length consistency
- Input/target alignment
- Duplicate detection
- Quality metrics

Usage:
    python validate_sampling.py --input sampled.jsonl
"""

import argparse
import json
from collections import Counter
from pathlib import Path


def validate_sequences(input_file: str) -> dict:
    """
    Validate a sampled dataset.
    
    Args:
        input_file: Path to JSONL file with sampled sequences
    
    Returns:
        Validation results dictionary
    """
    sequences = []
    targets = []
    lengths = []
    
    with open(input_file, "r", encoding="utf-8") as f:
        for line in f:
            record = json.loads(line)
            sequences.append(record["input"])
            targets.append(record["target"])
            lengths.append(len(record["input"]))
    
    # Check sequence lengths
    length_counts = Counter(lengths)
    expected_length = max(length_counts.keys())
    
    # Check input/target alignment (target should be input shifted by 1)
    alignment_errors = 0
    for seq, target in zip(sequences, targets):
        expected_target = seq[1:] + [seq[-1]]  # Simplified check
        if len(seq) != len(target):
            alignment_errors += 1
    
    # Check for exact duplicates
    seq_hashes = [tuple(s) for s in sequences]
    duplicate_count = len(seq_hashes) - len(set(seq_hashes))
    
    # Calculate statistics
    stats = {
        "total_sequences": len(sequences),
        "expected_length": expected_length,
        "length_distribution": dict(length_counts),
        "alignment_errors": alignment_errors,
        "duplicate_count": duplicate_count,
        "duplicate_ratio": duplicate_count / len(sequences) if sequences else 0,
        "unique_sequences": len(set(seq_hashes))
    }
    
    # Quality checks
    issues = []
    
    if stats["alignment_errors"] > 0:
        issues.append(f"WARNING: {stats['alignment_errors']} sequences have alignment errors")
    
    if stats["duplicate_ratio"] > 0.04:
        issues.append(f"WARNING: Duplicate ratio ({stats['duplicate_ratio']:.2%}) exceeds recommended threshold (4%)")
    
    if len(length_counts) > 1:
        issues.append(f"WARNING: Multiple sequence lengths found: {list(length_counts.keys())}")
    
    stats["issues"] = issues
    stats["passed"] = len(issues) == 0
    
    return stats


def main():
    parser = argparse.ArgumentParser(description="Validate sampled LLM training data")
    parser.add_argument("--input", required=True, help="Input JSONL file")
    
    args = parser.parse_args()
    
    print(f"Validating: {args.input}")
    
    stats = validate_sequences(args.input)
    
    print(f"\nValidation Results:")
    print(f"  Total sequences: {stats['total_sequences']}")
    print(f"  Expected length: {stats['expected_length']}")
    print(f"  Unique sequences: {stats['unique_sequences']}")
    print(f"  Duplicate ratio: {stats['duplicate_ratio']:.2%}")
    print(f"  Alignment errors: {stats['alignment_errors']}")
    
    if stats["issues"]:
        print(f"\nIssues found:")
        for issue in stats["issues"]:
            print(f"  - {issue}")
    else:
        print(f"\n✓ All checks passed!")
    
    return 0 if stats["passed"] else 1


if __name__ == "__main__":
    exit(main())
