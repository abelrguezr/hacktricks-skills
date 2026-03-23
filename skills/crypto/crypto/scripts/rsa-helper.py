#!/usr/bin/env python3
"""RSA helper functions for CTF challenges."""

import sys
import json
from Crypto.Util.number import *
import gmpy2


def rsa_encrypt(message, e, n):
    """Encrypt message with RSA."""
    m = bytes_to_long(message.encode() if isinstance(message, str) else message)
    c = pow(m, e, n)
    return c


def rsa_decrypt(ciphertext, d, n):
    """Decrypt RSA ciphertext."""
    m = pow(ciphertext, d, n)
    return long_to_bytes(m)


def rsa_decrypt_with_factors(ciphertext, e, p, q):
    """Decrypt RSA given prime factors."""
    n = p * q
    phi = (p - 1) * (q - 1)
    d = gmpy2.invert(e, phi)
    return rsa_decrypt(ciphertext, d, n)


def small_e_attack(ciphertext, n, e=3):
    """Attempt cube root attack for small e."""
    if e != 3:
        print(f"Warning: Small e attack typically works for e=3, got e={e}")
    
    # Try integer cube root
    try:
        m = round(ciphertext ** (1/e))
        if pow(m, e, n) == ciphertext:
            return long_to_bytes(m)
    except:
        pass
    
    return None


def common_factor_attack(n1, n2):
    """Find common factor between two moduli."""
    common = gmpy2.gcd(n1, n2)
    if common > 1:
        return common
    return None


def wiener_attack(n, e):
    """Attempt Wiener's attack for small d."""
    # Continued fraction expansion of e/n
    from fractions import Fraction
    
    def continued_fraction(x):
        a = []
        while x.denominator != 0:
            a.append(x.numerator // x.denominator)
            x = Fraction(x.denominator, x.numerator % x.denominator)
        return a
    
    def convergents(cf):
        h, k = 1, 0
        h1, k1 = cf[0], 1
        yield h1, k1
        for i in range(1, len(cf)):
            h, k = h1, k1
            h1 = cf[i] * h1 + h
            k1 = cf[i] * k1 + k
            yield h1, k1
    
    cf = continued_fraction(Fraction(e, n))
    
    for k, d in convergents(cf):
        if d == 0:
            continue
        phi = (e - 1) // d
        if (e - 1) % d != 0:
            continue
        
        # Check if this gives valid factors
        delta = phi - n + 1
        discriminant = delta * delta - 4 * n
        
        if discriminant >= 0:
            sqrt_disc = gmpy2.isqrt(discriminant)
            if sqrt_disc * sqrt_disc == discriminant:
                p = (delta + sqrt_disc) // 2
                q = (delta - sqrt_disc) // 2
                if p * q == n:
                    return p, q
    
    return None


def factor_with_pollard_rho(n, max_iterations=100000):
    """Attempt to factor n using Pollard's rho algorithm."""
    if n % 2 == 0:
        return 2
    
    x = gmpy2.mpz(2)
    y = gmpy2.mpz(2)
    d = gmpy2.mpz(1)
    
    f = lambda x: (x * x + 1) % n
    
    for _ in range(max_iterations):
        x = f(x)
        y = f(f(y))
        d = gmpy2.gcd(abs(x - y), n)
        
        if d > 1 and d < n:
            return int(d)
    
    return None


def parse_pem_key(pem_string):
    """Parse PEM format RSA key."""
    from Crypto.PublicKey import RSA
    
    try:
        key = RSA.import_key(pem_string)
        return {
            'n': key.n,
            'e': key.e,
            'd': key.d,
            'p': key.p,
            'q': key.q,
        }
    except Exception as ex:
        print(f"Error parsing PEM: {ex}")
        return None


def main():
    print("RSA Helper for CTF Challenges")
    print("=" * 40)
    print()
    print("Usage:")
    print("  python rsa-helper.py encrypt <message> <e> <n>")
    print("  python rsa-helper.py decrypt <ciphertext> <d> <n>")
    print("  python rsa-helper.py small-e <ciphertext> <n> [e]")
    print("  python rsa-helper.py common-factor <n1> <n2>")
    print("  python rsa-helper.py wiener <n> <e>")
    print("  python rsa-helper.py pollard-rho <n>")
    print("  python rsa-helper.py parse-pem <pem_file>")
    print()
    print("Examples:")
    print("  python rsa-helper.py encrypt 'Hello' 65537 12345678901234567890")
    print("  python rsa-helper.py small-e 123456789 987654321 3")


if __name__ == '__main__':
    main()
