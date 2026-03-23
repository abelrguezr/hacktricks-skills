#!/usr/bin/env python3
"""
Signal histogram analysis helper.

This script helps analyze signal characteristics from extracted data.
Useful for identifying modulation types and signal patterns.
"""

import sys
import json
from collections import Counter

def analyze_amplitude_levels(values, num_levels=2):
    """
    Analyze amplitude levels in a signal.
    
    Args:
        values: List of amplitude values
        num_levels: Expected number of levels (2 for binary, 4 for 2-bit/symbol)
    
    Returns:
        Dictionary with level analysis
    """
    if not values:
        return {"error": "No values provided"}
    
    # Sort and find clusters
    sorted_values = sorted(values)
    
    # Simple clustering: find gaps
    gaps = []
    for i in range(1, len(sorted_values)):
        gap = sorted_values[i] - sorted_values[i-1]
        gaps.append((gap, i))
    
    # Find largest gaps to identify level boundaries
    gaps.sort(reverse=True)
    
    levels = []
    if len(gaps) >= num_levels - 1:
        split_points = [gaps[i][1] for i in range(num_levels - 1)]
        split_points.sort()
        
        current_start = 0
        for split in split_points:
            level_values = sorted_values[current_start:split]
            if level_values:
                levels.append({
                    "min": min(level_values),
                    "max": max(level_values),
                    "mean": sum(level_values) / len(level_values),
                    "count": len(level_values)
                })
            current_start = split
        
        # Last level
        level_values = sorted_values[current_start:]
        if level_values:
            levels.append({
                "min": min(level_values),
                "max": max(level_values),
                "mean": sum(level_values) / len(level_values),
                "count": len(level_values)
            })
    
    return {
        "num_levels_detected": len(levels),
        "levels": levels,
        "total_samples": len(values),
        "global_min": min(values),
        "global_max": max(values),
        "global_mean": sum(values) / len(values)
    }

def analyze_bit_patterns(bits, window_size=8):
    """
    Analyze bit patterns for common sequences.
    
    Args:
        bits: String of 0s and 1s
        window_size: Size of pattern window
    
    Returns:
        Dictionary with pattern analysis
    """
    bits = bits.replace(' ', '').replace('\n', '')
    
    # Count individual bits
    bit_counts = Counter(bits)
    
    # Count patterns
    patterns = Counter()
    for i in range(len(bits) - window_size + 1):
        pattern = bits[i:i+window_size]
        patterns[pattern] += 1
    
    # Look for common sync patterns
    sync_patterns = {
        "0x55 (10101010)": bits.count('10101010'),
        "0xAA (01010101)": bits.count('01010101'),
        "0x7E (01111110)": bits.count('01111110'),
        "0xFF (11111111)": bits.count('11111111'),
        "0x00 (00000000)": bits.count('00000000'),
    }
    
    return {
        "total_bits": len(bits),
        "bit_distribution": dict(bit_counts),
        "sync_pattern_counts": sync_patterns,
        "most_common_patterns": dict(patterns.most_common(10)),
        "pattern_entropy": calculate_entropy([p[1] for p in patterns.items()])
    }

def calculate_entropy(counts):
    """
    Calculate entropy of a distribution.
    
    Args:
        counts: List of counts
    
    Returns:
        Entropy value
    """
    total = sum(counts)
    if total == 0:
        return 0
    
    entropy = 0
    for count in counts:
        if count > 0:
            p = count / total
            entropy -= p * (p if p > 0 else 0)
    
    return entropy

def detect_manchester_encoding(bits):
    """
    Check if bits appear to be Manchester encoded.
    
    Args:
        bits: String of 0s and 1s
    
    Returns:
        Dictionary with Manchester analysis
    """
    bits = bits.replace(' ', '').replace('\n', '')
    
    # Count transitions
    transitions = 0
    for i in range(1, len(bits)):
        if bits[i] != bits[i-1]:
            transitions += 1
    
    # Manchester should have high transition rate
    transition_rate = transitions / (len(bits) - 1) if len(bits) > 1 else 0
    
    # Count consecutive bits (should be rare in Manchester)
    consecutive_0s = bits.count('00')
    consecutive_1s = bits.count('11')
    
    # Check for 10 and 01 patterns
    pattern_10 = bits.count('10')
    pattern_01 = bits.count('01')
    
    return {
        "transition_rate": transition_rate,
        "likely_manchester": transition_rate > 0.7 and (consecutive_0s + consecutive_1s) < len(bits) * 0.1,
        "consecutive_00_count": consecutive_0s,
        "consecutive_11_count": consecutive_1s,
        "pattern_10_count": pattern_10,
        "pattern_01_count": pattern_01,
        "notes": "High transition rate with few consecutive bits suggests Manchester encoding"
    }

def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_signal_histogram.py <command> [args]")
        print("")
        print("Commands:")
        print("  amplitude <values> [num_levels]  - Analyze amplitude levels")
        print("  bits <bits>                      - Analyze bit patterns")
        print("  manchester <bits>                - Check for Manchester encoding")
        print("  json <file>                      - Load and analyze from JSON file")
        print("")
        print("Examples:")
        print("  python analyze_signal_histogram.py amplitude '0.1 0.2 0.9 0.8 0.1 0.9' 2")
        print("  python analyze_signal_histogram.py bits '1010101001010101'")
        print("  python analyze_signal_histogram.py manchester '1010101001010101'")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "amplitude":
        if len(sys.argv) < 3:
            print("Error: amplitude command requires values")
            sys.exit(1)
        
        values_str = sys.argv[2]
        num_levels = int(sys.argv[3]) if len(sys.argv) > 3 else 2
        
        # Parse values
        values = [float(v) for v in values_str.replace(',', ' ').split()]
        
        result = analyze_amplitude_levels(values, num_levels)
        print(json.dumps(result, indent=2))
    
    elif command == "bits":
        if len(sys.argv) < 3:
            print("Error: bits command requires bit string")
            sys.exit(1)
        
        bits = sys.argv[2]
        result = analyze_bit_patterns(bits)
        print(json.dumps(result, indent=2))
    
    elif command == "manchester":
        if len(sys.argv) < 3:
            print("Error: manchester command requires bit string")
            sys.exit(1)
        
        bits = sys.argv[2]
        result = detect_manchester_encoding(bits)
        print(json.dumps(result, indent=2))
    
    elif command == "json":
        if len(sys.argv) < 3:
            print("Error: json command requires file path")
            sys.exit(1)
        
        with open(sys.argv[2], 'r') as f:
            data = json.load(f)
        
        if "amplitude_values" in data:
            result = analyze_amplitude_levels(data["amplitude_values"])
        elif "bits" in data:
            result = analyze_bit_patterns(data["bits"])
        else:
            print("Error: JSON must contain 'amplitude_values' or 'bits'")
            sys.exit(1)
        
        print(json.dumps(result, indent=2))
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()
