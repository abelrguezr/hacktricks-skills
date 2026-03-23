---
name: crypto-ctf-solver
description: Solve public-key cryptography CTF challenges involving RSA, ECC, and ECDSA. Use this skill whenever the user mentions crypto challenges, RSA keys, ECDSA signatures, nonce reuse, lattice attacks, or any public-key cryptography problem. This includes CTF writeups, security research, or analyzing cryptographic implementations. Trigger on keywords like: RSA, ECC, ECDSA, nonce, private key recovery, lattice, LLL, factordb, SageMath, or any mention of cryptographic attacks.
---

# Public-Key Crypto CTF Solver

A skill for solving public-key cryptography challenges in CTFs and security research. Focuses on RSA, ECC/ECDSA, and lattice-based attacks.

## When to use this skill

Use this skill when:
- You have RSA parameters (n, e, c) and need to decrypt or factor
- You're analyzing ECDSA signatures for nonce reuse or bias
- You encounter lattice-based crypto problems
- You need to recover private keys from cryptographic artifacts
- You're working on CTF crypto challenges involving public-key algorithms

## Recommended Tooling

- **SageMath**: For LLL/lattice attacks and modular arithmetic
- **RsaCtfTool**: Swiss-army knife for RSA attacks
- **factordb.com**: Quick factorization checks

## RSA Attacks

Start here when you have `n, e, c` and additional hints.

### Common Attack Patterns

1. **Shared Modulus Attack**: Same `n` used with different `e` values
2. **Low Exponent Attack**: Small `e` (e.g., e=3) with small messages
3. **Partial Key Exposure**: Some bits of `d` or `p`/`q` known
4. **Related Messages**: Same message encrypted with different padding
5. **Small Factors**: `n` has small prime factors (check factordb first)

### Attack Workflow

1. Check factordb.com for `n` - instant factorization if available
2. Run RsaCtfTool for automated attack detection
3. Use SageMath for custom lattice attacks if needed

## ECDSA Nonce Recovery

If two signatures reuse the same nonce `k`, the private key can be recovered.

### Recovery Formulas

Given:
- Two messages `m1, m2` with signatures `(r, s1)` and `(r, s2)`
- Same `r` indicates nonce reuse
- Group order `n`

Recovery:
```
k = (h(m1) - h(m2)) * (s1 - s2)^{-1} mod n
d = (s1*k - h(m1)) * r^{-1} mod n
```

Where:
- `h(m)` = hash of message
- `d` = private key
- `k` = nonce

### Nonce Bias/Leakage

Even if `k` isn't identical, **bias or leakage of nonce bits** across signatures can enable lattice recovery. This is a common CTF theme.

## Invalid-Curve Attacks

If a protocol fails to validate that points are on the expected curve (or subgroup), an attacker may force operations in a weak group.

### Defense Checklist

- Validate points are on-curve
- Validate points are in the correct subgroup
- Check for small subgroup attacks

### Attack Pattern

Many CTF tasks model this as: "server multiplies attacker-chosen point by secret scalar and returns something."

## Scripts

### ECDSA Nonce Recovery

Use `scripts/ecdsa_nonce_recovery.py` when you have two signatures with the same `r` value.

### RSA Factorization Helper

Use `scripts/rsa_factor_check.py` to quickly check factordb and run basic factorization.

## SageMath Patterns

For lattice attacks, use SageMath with LLL:

```python
from sage.all import *

# Example: Lattice basis construction
n = 2  # dimension
basis = Matrix(ZZ, [[n, 0], [0, n]])
reduced = basis.LLL()
```

## Common CTF Patterns

1. **Nonce reuse in ECDSA** → Direct private key recovery
2. **Small RSA factors** → Check factordb first
3. **Invalid curve points** → Force weak group operations
4. **Lattice problems** → Use SageMath LLL
5. **Partial key exposure** → Coppersmith's method

## Next Steps

After identifying the attack pattern:
1. Extract relevant parameters from the challenge
2. Run the appropriate script or SageMath code
3. Verify the recovered key works
4. Document the attack for writeup
