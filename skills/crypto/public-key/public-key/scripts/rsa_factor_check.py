#!/usr/bin/env python3
"""
RSA Factorization Helper

Quickly checks factordb and runs basic factorization attempts.

Usage:
    python rsa_factor_check.py --n <modulus>
    python rsa_factor_check.py --n <modulus> --e <exponent> --c <ciphertext>

Example:
    python rsa_factor_check.py --n 12345678901234567890
"""

import argparse
import sys
import json
import urllib.request
import urllib.parse
from math import gcd

def check_factordb(n):
    """
    Check factordb.com for factors of n.
    
    Returns:
    - dict with factors if found, None otherwise
    """
    url = f"http://factordb.com/index.php?query={n}"
    
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            html = response.read().decode('utf-8')
            
            # Simple parsing - look for factor information
            # This is a basic check; for production use, consider the API
            if 'No factors found' in html or 'No factors' in html:
                return None
            
            # Extract factors from HTML (basic parsing)
            # Look for patterns like "12345678901234567890 = 12345 * 67890"
            import re
            match = re.search(r'\d+\s*=\s*(\d+)\s*\*\s*(\d+)', html)
            if match:
                p = int(match.group(1))
                q = int(match.group(2))
                return {'p': p, 'q': q, 'source': 'factordb'}
            
            return None
    except Exception as e:
        print(f"Warning: Could not check factordb: {e}", file=sys.stderr)
        return None

def trial_division(n, limit=1000000):
    """
    Basic trial division for small factors.
    
    Returns:
    - dict with factors if found, None otherwise
    """
    if n % 2 == 0:
        return {'p': 2, 'q': n // 2, 'source': 'trial_division'}
    
    for i in range(3, min(limit, int(n**0.5) + 1), 2):
        if n % i == 0:
            return {'p': i, 'q': n // i, 'source': 'trial_division'}
    
    return None

def compute_private_key(n, e, p, q):
    """
    Compute RSA private key d from factors.
    
    Returns:
    - dict with d and phi
    """
    phi = (p - 1) * (q - 1)
    
    # Compute modular inverse of e mod phi
    def extended_gcd(a, b):
        if a == 0:
            return b, 0, 1
        gcd_val, x1, y1 = extended_gcd(b % a, a)
        x = y1 - (b // a) * x1
        y = x1
        return gcd_val, x, y
    
    _, d, _ = extended_gcd(e, phi)
    d = (d % phi + phi) % phi
    
    return {'d': d, 'phi': phi}

def decrypt_message(c, d, n):
    """
    Decrypt RSA ciphertext.
    
    Returns:
    - plaintext as integer
    """
    return pow(c, d, n)

def main():
    parser = argparse.ArgumentParser(
        description='Check RSA modulus for factors'
    )
    parser.add_argument('--n', type=int, required=True,
                        help='RSA modulus n')
    parser.add_argument('--e', type=int, default=65537,
                        help='Public exponent e (default: 65537)')
    parser.add_argument('--c', type=int, default=None,
                        help='Ciphertext c (optional)')
    parser.add_argument('--output', type=str, default=None,
                        help='Output file path (optional)')
    
    args = parser.parse_args()
    
    results = {
        'n': args.n,
        'e': args.e,
        'c': args.c,
        'factors': None,
        'private_key': None,
        'decrypted': None
    }
    
    print(f"Checking RSA modulus: {args.n}")
    print(f"Number of bits: {args.n.bit_length()}")
    print()
    
    # Check factordb first
    print("Checking factordb.com...")
    factors = check_factordb(args.n)
    
    if factors:
        print(f"✓ Found factors on factordb!")
        results['factors'] = factors
    else:
        print("✗ No factors found on factordb")
        
        # Try trial division
        print("Attempting trial division...")
        factors = trial_division(args.n)
        
        if factors:
            print(f"✓ Found factors via trial division!")
            results['factors'] = factors
        else:
            print("✗ No small factors found")
            print("\nRecommendations:")
            print("  - Run RsaCtfTool for automated attacks")
            print("  - Check for common RSA vulnerabilities:")
            print("    * Shared modulus attack")
            print("    * Low exponent attack")
            print("    * Wiener's attack (small d)")
            print("    * Coppersmith's method (partial key exposure)")
    
    # If we have factors, compute private key
    if factors:
        p, q = factors['p'], factors['q']
        print(f"\nFactors:")
        print(f"  p = {p}")
        print(f"  q = {q}")
        
        # Verify
        if p * q == args.n:
            print("\n✓ Factorization verified!")
        else:
            print("\n✗ Factorization verification failed!")
            sys.exit(1)
        
        # Compute private key
        print("\nComputing private key...")
        private_key = compute_private_key(args.n, args.e, p, q)
        results['private_key'] = private_key
        
        print(f"  d = {private_key['d']}")
        print(f"  φ(n) = {private_key['phi']}")
        
        # Decrypt if ciphertext provided
        if args.c is not None:
            print("\nDecrypting ciphertext...")
            plaintext = decrypt_message(args.c, private_key['d'], args.n)
            results['decrypted'] = plaintext
            
            print(f"  Plaintext (int): {plaintext}")
            
            # Try to decode as ASCII
            try:
                plaintext_bytes = plaintext.to_bytes(
                    (plaintext.bit_length() + 7) // 8, 'big'
                )
                # Remove padding if present
                if plaintext_bytes.startswith(b'\x00'):
                    plaintext_bytes = plaintext_bytes.lstrip(b'\x00')
                
                decoded = plaintext_bytes.decode('utf-8', errors='replace')
                print(f"  Plaintext (text): {decoded}")
            except:
                print(f"  (Could not decode as text)")
    
    # Output results
    output_text = f"""RSA Factorization Results
=========================

Modulus (n): {args.n}
Public Exponent (e): {args.e}
Ciphertext (c): {args.c}

"""
    
    if results['factors']:
        output_text += f"Factors Found: {results['factors']}\n\n"
    
    if results['private_key']:
        output_text += f"Private Key: {results['private_key']}\n\n"
    
    if results['decrypted']:
        output_text += f"Decrypted: {results['decrypted']}\n"
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(output_text)
        print(f"\nResults saved to {args.output}")
    else:
        print(f"\n{output_text}")
    
    # Print JSON for programmatic use
    print("JSON Output:")
    print(json.dumps(results, indent=2, default=str))

if __name__ == '__main__':
    main()
