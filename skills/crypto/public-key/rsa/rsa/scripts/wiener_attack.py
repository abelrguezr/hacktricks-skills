#!/usr/bin/env python3
"""
Wiener Attack

Recovers private exponent d when d is small (d < n^0.25 / 3).
Uses continued fractions of e/n.

Usage:
    python wiener_attack.py --n <modulus> --e <exponent> --c <ciphertext>
"""

import argparse
import sys
from math import gcd


def continued_fraction(e, n):
    """
    Compute continued fraction expansion of e/n.
    Returns list of convergents as (k, d) pairs.
    """
    convergents = []
    a = []
    
    # Continued fraction expansion
    x, y = e, n
    while y:
        a.append(x // y)
        x, y = y, x % y
    
    # Compute convergents
    p_prev, p_curr = 0, 1
    q_prev, q_curr = 1, 0
    
    for ai in a:
        p_next = ai * p_curr + p_prev
        q_next = ai * q_curr + q_prev
        
        if q_next > 0:
            convergents.append((p_next, q_next))
        
        p_prev, p_curr = p_curr, p_next
        q_prev, q_curr = q_curr, q_next
    
    return convergents


def wiener_attack(n, e):
    """
    Wiener attack on small d.
    
    Returns d if found, None otherwise.
    """
    convergents = continued_fraction(e, n)
    
    for k, d in convergents:
        if d <= 0:
            continue
        
        # Check if this convergent gives valid RSA parameters
        # We have: e*d - k*phi = 1, so phi = (e*d - 1) / k
        if (e * d - 1) % k != 0:
            continue
        
        phi = (e * d - 1) // k
        
        # From phi = (p-1)(q-1) = pq - p - q + 1 = n - (p+q) + 1
        # So p+q = n - phi + 1
        s = n - phi + 1
        
        # p and q are roots of x^2 - s*x + n = 0
        # Discriminant: s^2 - 4n
        disc = s * s - 4 * n
        
        if disc < 0:
            continue
        
        # Check if discriminant is a perfect square
        sqrt_disc = int(disc ** 0.5)
        if sqrt_disc * sqrt_disc != disc:
            continue
        
        # Compute p and q
        p = (s + sqrt_disc) // 2
        q = (s - sqrt_disc) // 2
        
        # Verify
        if p * q == n and (p - 1) * (q - 1) == phi:
            return d, p, q
    
    return None, None, None


def decrypt_rsa(c, d, n):
    """Decrypt RSA ciphertext"""
    return pow(c, d, n)


def int_to_bytes(n):
    """Convert integer to bytes"""
    if n == 0:
        return b'\x00'
    hex_str = hex(n)[2:]
    if len(hex_str) % 2:
        hex_str = '0' + hex_str
    return bytes.fromhex(hex_str)


def try_decode(m):
    """Try to decode as ASCII/UTF-8"""
    try:
        return m.decode('utf-8')
    except:
        return None


def main():
    parser = argparse.ArgumentParser(description='Wiener Attack on Small RSA Private Exponent')
    parser.add_argument('--n', required=True, help='Modulus')
    parser.add_argument('--e', required=True, help='Public exponent')
    parser.add_argument('--c', default=None, help='Ciphertext to decrypt')
    
    args = parser.parse_args()
    
    def parse_val(v):
        if v.startswith('0x') or v.startswith('0X'):
            return int(v, 16)
        return int(v)
    
    n = parse_val(args.n)
    e = parse_val(args.e)
    
    print(f"n = {n}")
    print(f"e = {e}")
    print(f"n^0.25 ≈ {n**0.25}")
    print(f"Threshold for Wiener: n^0.25 / 3 ≈ {n**0.25 / 3}")
    print()
    
    d, p, q = wiener_attack(n, e)
    
    if d is None:
        print("Wiener attack failed - d is not small enough or not vulnerable.")
        return
    
    print(f"*** WIENER ATTACK SUCCESSFUL ***")
    print(f"Recovered d = {d}")
    print(f"Factored n: p = {p}, q = {q}")
    
    if args.c:
        c = parse_val(args.c)
        print(f"\nDecrypting ciphertext c = {c}")
        
        m = decrypt_rsa(c, d, n)
        print(f"Decrypted plaintext (int): {m}")
        
        text = try_decode(int_to_bytes(m))
        if text:
            print(f"Decrypted plaintext (text): {text}")
        else:
            print(f"Decrypted plaintext (hex): {hex(m)}")


if __name__ == '__main__':
    main()
