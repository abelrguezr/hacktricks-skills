#!/usr/bin/env python3
"""Identify hash types and attempt basic cracking."""

import hashlib
import re
import sys
import json


HASH_ALGORITHMS = {
    'md5': {'length': 32, 'pattern': r'^[a-f0-9]{32}$'},
    'sha1': {'length': 40, 'pattern': r'^[a-f0-9]{40}$'},
    'sha256': {'length': 64, 'pattern': r'^[a-f0-9]{64}$'},
    'sha512': {'length': 128, 'pattern': r'^[a-f0-9]{128}$'},
    'blake2b': {'length': 128, 'pattern': r'^[a-f0-9]{128}$'},
    'blake2s': {'length': 64, 'pattern': r'^[a-f0-9]{64}$'},
}


def identify_hash(hash_string):
    """Identify the likely hash algorithm."""
    hash_string = hash_string.strip()
    
    # Remove common prefixes
    for prefix in ['$', '0x', 'hash:', 'Hash:']:
        if hash_string.startswith(prefix):
            hash_string = hash_string[len(prefix):].strip()
    
    # Check against known patterns
    matches = []
    for algo, info in HASH_ALGORITHMS.items():
        if re.match(info['pattern'], hash_string):
            matches.append(algo)
    
    return matches


def compute_hash(text, algorithm):
    """Compute hash of text using specified algorithm."""
    text = text.encode('utf-8')
    
    if algorithm == 'md5':
        return hashlib.md5(text).hexdigest()
    elif algorithm == 'sha1':
        return hashlib.sha1(text).hexdigest()
    elif algorithm == 'sha256':
        return hashlib.sha256(text).hexdigest()
    elif algorithm == 'sha512':
        return hashlib.sha512(text).hexdigest()
    elif algorithm == 'blake2b':
        return hashlib.blake2b(text).hexdigest()
    elif algorithm == 'blake2s':
        return hashlib.blake2s(text).hexdigest()
    else:
        raise ValueError(f"Unknown algorithm: {algorithm}")


def brute_force(hash_string, algorithm, wordlist=None, max_attempts=10000):
    """Attempt to crack hash with brute force."""
    # Common wordlist if not provided
    if wordlist is None:
        wordlist = [
            'password', 'admin', 'root', 'test', '123456', 'letmein',
            'welcome', 'qwerty', 'monkey', 'dragon', 'master', 'login',
            'hello', 'world', 'flag', 'ctf', 'secret', 'password123',
            '12345678', '123456789', 'abc123', 'passw0rd', 'iloveyou',
        ]
    
    for word in wordlist:
        if compute_hash(word, algorithm) == hash_string:
            return word
    
    return None


def main():
    if len(sys.argv) < 2:
        print("Usage: hash-identify.py <hash_string> [algorithm]")
        print("\nAlgorithms: md5, sha1, sha256, sha512, blake2b, blake2s")
        print("\nIf algorithm not specified, attempts to identify automatically.")
        sys.exit(1)
    
    hash_string = sys.argv[1]
    specified_algo = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Identify hash type
    if specified_algo:
        algorithms = [specified_algo]
    else:
        algorithms = identify_hash(hash_string)
    
    if not algorithms:
        print(f"Could not identify hash type for: {hash_string}")
        print("\nKnown hash lengths:")
        for algo, info in HASH_ALGORITHMS.items():
            print(f"  {algo}: {info['length']} hex chars")
        sys.exit(1)
    
    print(f"Input: {hash_string}")
    print(f"\nIdentified as: {', '.join(algorithms)}")
    
    # Try to crack
    print("\nAttempting to crack...")
    for algo in algorithms:
        result = brute_force(hash_string, algo)
        if result:
            print(f"\n✓ Found! Algorithm: {algo}, Plaintext: {result}")
            sys.exit(0)
    
    print("\n✗ Could not crack with common words.")
    print("\nSuggestions:")
    print("  - Use hashcat or john for more powerful cracking")
    print("  - Check hash-identifier.com for hash type")
    print("  - Try crackstation.net for known hashes")
    print("  - Consider if this might be a salted hash")


if __name__ == '__main__':
    main()
