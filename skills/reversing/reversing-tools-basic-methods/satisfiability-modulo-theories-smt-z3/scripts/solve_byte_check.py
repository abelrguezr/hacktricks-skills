#!/usr/bin/env python3
"""
Helper script for solving byte-based validation checks from crackmes.

Usage:
    python solve_byte_check.py --flag-len 8 --constraints "flag[0]+flag[5]==0x90,flag[1]^flag[2]^flag[3]==0x5a"
    python solve_byte_check.py --flag-len 16 --hex-input "4142434445464748494a4b4c4d4e4f50"
    python solve_byte_check.py --interactive
"""

import argparse
import sys
from z3 import *


def parse_constraints(constraint_str, flag_vars):
    """Parse comma-separated constraints into Z3 expressions."""
    constraints = []
    for c in constraint_str.split(','):
        c = c.strip()
        if not c:
            continue
        
        # Replace flag[N] with variable names
        expr = c
        for i, var in enumerate(flag_vars):
            expr = expr.replace(f'flag[{i}]', f'flag_{i}')
        
        # Handle hex values
        expr = expr.replace('0x', '0x')
        
        # Create Z3 expression
        try:
            # This is a simplified parser - for complex expressions, write directly in Z3
            constraints.append(eval(expr, {**globals(), **{f'flag_{i}': v for i, v in enumerate(flag_vars)}}))
        except Exception as e:
            print(f"Warning: Could not parse constraint '{c}': {e}")
    
    return constraints


def solve_basic(flag_len, constraints_str=None, hex_input=None, alphabet='printable'):
    """Solve a basic byte-based check."""
    
    # Create flag variables
    flag = [BitVec(f'flag_{i}', 8) for i in range(flag_len)]
    s = Solver()
    
    # Add alphabet constraints
    if alphabet == 'printable':
        for c in flag:
            s.add(c >= 0x20, c <= 0x7e)
    elif alphabet == 'alphanumeric':
        for c in flag:
            s.add(Or(
                And(c >= ord('0'), c <= ord('9')),
                And(c >= ord('A'), c <= ord('Z')),
                And(c >= ord('a'), c <= ord('z'))
            ))
    elif alphabet == 'ascii':
        for c in flag:
            s.add(c >= 0x00, c <= 0x7f)
    elif alphabet == 'digits':
        for c in flag:
            s.add(c >= ord('0'), c <= ord('9'))
    
    # Add user constraints
    if constraints_str:
        constraints = parse_constraints(constraints_str, flag)
        for c in constraints:
            s.add(c)
    
    # Add hex input constraints (for partial known values)
    if hex_input:
        hex_input = hex_input.replace(' ', '').replace(':', '')
        for i, hex_char in enumerate(hex_input[::2]):
            if i < flag_len:
                s.add(flag[i] == int(hex_input[i*2:i*2+2], 16))
    
    # Solve
    if s.check() == sat:
        m = s.model()
        result = bytes(m[c].as_long() for c in flag)
        return result
    else:
        return None


def solve_with_word_ops(flag_len, constraints_func):
    """Solve with word-level operations (Concat, Extract, etc.)."""
    
    flag = [BitVec(f'flag_{i}', 8) for i in range(flag_len)]
    s = Solver()
    
    # Printable ASCII
    for c in flag:
        s.add(c >= 0x20, c <= 0x7e)
    
    # Add custom constraints
    constraints_func(s, flag)
    
    if s.check() == sat:
        m = s.model()
        return bytes(m[c].as_long() for c in flag)
    return None


def enumerate_solutions(flag_len, constraints_func, max_solutions=10):
    """Enumerate multiple valid solutions."""
    
    flag = [BitVec(f'flag_{i}', 8) for i in range(flag_len)]
    s = Solver()
    
    # Printable ASCII
    for c in flag:
        s.add(c >= 0x20, c <= 0x7e)
    
    # Add custom constraints
    constraints_func(s, flag)
    
    solutions = []
    count = 0
    
    while s.check() == sat and count < max_solutions:
        m = s.model()
        result = bytes(m[c].as_long() for c in flag)
        solutions.append(result)
        count += 1
        
        # Block this solution
        s.add(Or([c != m.eval(c, model_completion=True) for c in flag]))
    
    return solutions


def interactive_mode():
    """Interactive mode for building constraints."""
    print("Z3 Byte Check Solver - Interactive Mode")
    print("=" * 40)
    
    flag_len = int(input("Flag length: "))
    alphabet = input("Alphabet (printable/alphanumeric/digits): ").strip() or 'printable'
    
    flag = [BitVec(f'flag_{i}', 8) for i in range(flag_len)]
    s = Solver()
    
    # Add alphabet constraints
    if alphabet == 'printable':
        for c in flag:
            s.add(c >= 0x20, c <= 0x7e)
    elif alphabet == 'alphanumeric':
        for c in flag:
            s.add(Or(
                And(c >= ord('0'), c <= ord('9')),
                And(c >= ord('A'), c <= ord('Z')),
                And(c >= ord('a'), c <= ord('z'))
            ))
    elif alphabet == 'digits':
        for c in flag:
            s.add(c >= ord('0'), c <= ord('9'))
    
    print("\nEnter constraints (one per line, empty line to finish):")
    print("Examples:")
    print("  flag[0] + flag[5] == 0x90")
    print("  flag[1] ^ flag[2] == 0x5a")
    print("  flag[0] > 0x40")
    
    while True:
        constraint = input("  ").strip()
        if not constraint:
            break
        
        # Parse constraint
        expr = constraint
        for i, var in enumerate(flag):
            expr = expr.replace(f'flag[{i}]', f'flag_{i}')
        
        try:
            z3_expr = eval(expr, {**globals(), **{f'flag_{i}': v for i, v in enumerate(flag)}})
            s.add(z3_expr)
            print("  Added constraint")
        except Exception as e:
            print(f"  Error: {e}")
    
    # Solve
    print("\nSolving...")
    if s.check() == sat:
        m = s.model()
        result = bytes(m[c].as_long() for c in flag)
        print(f"\nSolution: {result}")
        print(f"Hex: {result.hex()}")
    else:
        print("\nNo solution found (unsat)")


def main():
    parser = argparse.ArgumentParser(description='Solve byte-based validation checks')
    parser.add_argument('--flag-len', type=int, default=8, help='Flag length in bytes')
    parser.add_argument('--constraints', type=str, help='Comma-separated constraints')
    parser.add_argument('--hex-input', type=str, help='Known bytes in hex')
    parser.add_argument('--alphabet', type=str, default='printable', 
                        choices=['printable', 'alphanumeric', 'digits', 'ascii'])
    parser.add_argument('--interactive', action='store_true', help='Interactive mode')
    parser.add_argument('--enumerate', type=int, default=0, help='Enumerate N solutions')
    
    args = parser.parse_args()
    
    if args.interactive:
        interactive_mode()
        return
    
    if args.enumerate > 0:
        # Simple enumeration example
        def constraints_func(s, flag):
            if args.constraints:
                for c in args.constraints.split(','):
                    c = c.strip()
                    if c:
                        expr = c
                        for i, var in enumerate(flag):
                            expr = expr.replace(f'flag[{i}]', f'flag_{i}')
                        try:
                            z3_expr = eval(expr, {**globals(), **{f'flag_{i}': v for i, v in enumerate(flag)}})
                            s.add(z3_expr)
                        except:
                            pass
        
        solutions = enumerate_solutions(args.flag_len, constraints_func, args.enumerate)
        for i, sol in enumerate(solutions, 1):
            print(f"Solution {i}: {sol}")
    else:
        result = solve_basic(args.flag_len, args.constraints, args.hex_input, args.alphabet)
        if result:
            print(f"Solution: {result}")
            print(f"Hex: {result.hex()}")
        else:
            print("No solution found")
            sys.exit(1)


if __name__ == '__main__':
    main()
