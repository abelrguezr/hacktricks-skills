#!/usr/bin/env python3
"""Bruteforce MD5 hashes to find plaintexts where hash ends with target suffix."""

import hashlib
import argparse
import sys


def bruteforce_suffix(target: str, start: int = 0, max_iterations: int = None) -> str:
    """
    Find a number whose MD5 hash ends with the target suffix.
    
    Args:
        target: The suffix to match at the end of the MD5 hash
        start: Starting number for the search
        max_iterations: Maximum number of iterations (None for unlimited)
    
    Returns:
        The plaintext number as a string
    """
    candidate = start
    iteration = 0
    
    while True:
        plaintext = str(candidate)
        hash_value = hashlib.md5(plaintext.encode('ascii')).hexdigest()
        
        if hash_value[-len(target):] == target:
            print(f'plaintext:"{plaintext}", md5:{hash_value}')
            return plaintext
        
        candidate += 1
        iteration += 1
        
        if max_iterations and iteration >= max_iterations:
            print(f"Reached max iterations ({max_iterations}) without finding a match")
            sys.exit(1)
        
        # Progress indicator every 10000 iterations
        if iteration % 10000 == 0:
            print(f"Checked {iteration} candidates...", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description='Bruteforce MD5 hashes to find plaintexts ending with target suffix'
    )
    parser.add_argument(
        '--target', '-t',
        required=True,
        help='Target suffix to match at end of MD5 hash'
    )
    parser.add_argument(
        '--start', '-s',
        type=int,
        default=0,
        help='Starting number for search (default: 0)'
    )
    parser.add_argument(
        '--max', '-m',
        type=int,
        default=None,
        help='Maximum iterations (default: unlimited)'
    )
    
    args = parser.parse_args()
    
    if not args.target:
        parser.error("Target suffix is required")
    
    bruteforce_suffix(args.target, args.start, args.max)


if __name__ == '__main__':
    main()
