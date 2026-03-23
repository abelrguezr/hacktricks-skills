---
name: rsa-attacks
description: How to break RSA encryption in CTFs and crypto challenges. Use this skill whenever the user mentions RSA, public-key cryptography, ciphertexts, moduli, exponents, or any crypto challenge involving n, e, c values. Make sure to use this skill for any RSA-related task even if the user doesn't explicitly say "RSA" - look for patterns like "modulus", "ciphertext", "public key", "private exponent", or hex strings that look like cryptographic values.
---

# RSA Attack Toolkit

A systematic approach to breaking RSA encryption in CTFs and crypto challenges.

## Quick Triage Checklist

When you encounter an RSA challenge, collect these values first:

1. **Core parameters**: `n` (modulus), `e` (public exponent), `c` (ciphertext)
2. **Multiple ciphertexts**: Are there several `c` values? Same or different moduli?
3. **Message relationships**: Same plaintext encrypted differently? Structured plaintext?
4. **Leaks**: Partial `p`/`q`, bits of `d`, `dp`/`dq`, known padding patterns

Then systematically try attacks in this order:

1. **Factorization check** - Try `factordb.com` or `sage: factor(n)` for small moduli
2. **Low exponent patterns** - Check if `e=3` or other small values, look for broadcast
3. **Common modulus / shared primes** - Check GCDs between moduli
4. **Lattice methods** - Use Coppersmith/LLL when partial information exists

## Attack Patterns

### Common Modulus Attack

**When to use**: Two ciphertexts encrypt the **same message** under the **same modulus** `n` but with different exponents `e1, e2` where `gcd(e1, e2) = 1`.

**How it works**: Use the extended Euclidean algorithm to recover `m`:

```
m = c1^a * c2^b mod n
```

where `a*e1 + b*e2 = 1`.

**Steps**:
1. Compute `(a, b) = extended_gcd(e1, e2)` so that `a*e1 + b*e2 = 1`
2. If `a < 0`, compute `inv(c1)^(-a) mod n` (modular inverse)
3. If `b < 0`, compute `inv(c2)^(-b) mod n`
4. Multiply results and reduce modulo `n`

**Script**: Use `scripts/common_modulus_attack.py`

### Shared Primes Across Moduli

**When to use**: Multiple RSA moduli from the same challenge, especially when the problem mentions "many keys generated quickly" or "bad randomness".

**How it works**: If `gcd(n1, n2) != 1`, the moduli share a prime factor - catastrophic key generation failure.

**Steps**:
1. For each pair of moduli, compute `g = gcd(n1, n2)`
2. If `g > 1`, you found a shared prime `p = g`
3. Compute `q = n // p` to factor the modulus
4. Use `p, q` to compute private key and decrypt

**Script**: Use `scripts/shared_prime_check.py`

### Håstad Broadcast Attack

**When to use**: Same plaintext sent to multiple recipients with small `e` (often `e=3`) and no proper padding.

**Technical condition**: You need `e` ciphertexts of the same message under pairwise-coprime moduli `n_i`.

**How it works**:
1. Use Chinese Remainder Theorem (CRT) to recover `M = m^e` over the product `N = Π n_i`
2. If `m^e < N`, then `M` is the true integer power
3. Compute `m = integer_root(M, e)`

**Script**: Use `scripts/hadast_broadcast.py`

### Wiener Attack (Small Private Exponent)

**When to use**: When `d` is too small (typically `d < n^0.25 / 3`).

**How it works**: Continued fractions of `e/n` can recover `d` when it's small enough.

**Steps**:
1. Compute continued fraction expansion of `e/n`
2. For each convergent `k/d`, check if it yields valid RSA parameters
3. If valid, use `d` to decrypt

**Script**: Use `scripts/wiener_attack.py`

### Related-Message Attacks

**When to use**: Two ciphertexts under the same modulus with algebraically related messages (e.g., `m2 = a*m1 + b`).

**Requirements**:
- Same modulus `n`
- Same exponent `e`
- Known relationship between plaintexts

**How it works**: Set up polynomials modulo `n` and compute GCD to find the message.

**Tooling**: Use SageMath with polynomial GCD computation.

### Lattice Methods (Coppersmith/LLL)

**When to use**: You have partial information that makes the unknown "small".

**Typical hints**:
- "We leaked the top/bottom bits of p"
- "The flag is embedded like: `m = bytes_to_long(b"HTB{" + unknown + b"}")`"
- "We used RSA but with a small random padding"

**What it handles**:
- Partially known plaintext (structured message with unknown tail)
- Partially known `p`/`q` (high or low bits leaked)
- Small unknown differences between related values

**Tooling**: Use SageMath with Coppersmith templates.

**Resources**:
- Sage CTF crypto templates: https://github.com/defund/coppersmith
- Survey reference: https://martinralbrecht.wordpress.com/2013/05/06/coppersmiths-method/

## Textbook RSA Pitfalls

If you see these patterns, algebraic attacks become much more likely:

- No OAEP/PSS padding, raw modular exponentiation
- Deterministic encryption (same plaintext → same ciphertext)
- Small public exponents without proper padding

## Tools

- **RsaCtfTool**: https://github.com/Ganapati/RsaCtfTool - Automated RSA attack tool
- **SageMath**: https://www.sagemath.org/ - For CRT, roots, continued fractions, lattice methods

## Workflow

1. **Parse the challenge** - Extract all `n`, `e`, `c` values and note relationships
2. **Run triage** - Check factorization, look for obvious patterns
3. **Match to attack** - Identify which attack pattern fits
4. **Execute** - Use the appropriate script or Sage template
5. **Verify** - Check if the decrypted message makes sense (look for flag patterns)

## Example Challenge Patterns

**Pattern 1 - Common Modulus**:
```
"Here are two ciphertexts of the same message with different exponents"
n = 0x...
e1 = 65537, c1 = 0x...
e2 = 3, c2 = 0x...
```
→ Use common modulus attack

**Pattern 2 - Shared Primes**:
```
"We generated 100 RSA keys quickly"
n1 = 0x..., n2 = 0x..., n3 = 0x...
```
→ Check GCDs between all pairs

**Pattern 3 - Broadcast**:
```
"Same message sent to 3 recipients with e=3"
n1, c1 = ...
n2, c2 = ...
n3, c3 = ...
```
→ Use Håstad broadcast attack

**Pattern 4 - Partial Key**:
```
"We leaked the top 50 bits of p"
n = 0x...
p_high = 0x...
```
→ Use Coppersmith with partial key recovery
