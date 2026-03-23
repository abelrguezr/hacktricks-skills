---
name: crypto-ctf-helper
description: Help with cryptography challenges for CTFs, security research, and hacking. Use this skill whenever the user mentions crypto, encryption, decryption, hashes, RSA, AES, CTF challenges, cryptographic attacks, or anything related to breaking or analyzing cryptographic systems. This includes recognizing cipher types, identifying vulnerabilities, applying known attacks, and working with crypto primitives.
---

# Crypto CTF Helper

A skill for practical cryptography in hacking and CTF contexts. Focus on speed: classify the primitive, identify what you control (oracle/leak/nonce reuse), then apply known attack templates.

## When to use this skill

Use this skill when the user:
- Asks about encryption/decryption challenges
- Needs help with CTF crypto problems
- Wants to analyze cryptographic systems
- Is working with hashes, MACs, or KDFs
- Needs help with RSA, ECC, or other public-key crypto
- Is dealing with TLS/certificate issues
- Wants to understand crypto in malware
- Needs to recognize cipher patterns or vulnerabilities

## Quick Setup

```bash
# Python environment
python3 -m venv .venv && source .venv/bin/activate

# Required libraries
pip install pycryptodome gmpy2 sympy pwntools

# SageMath (essential for lattice/RSA/ECC)
# Download from: https://www.sagemath.org/
```

## CTF Workflow

### Step 1: Classify the Primitive

Identify what you're dealing with:

| Pattern | Likely Primitive |
|---------|------------------|
| Base64, hex strings | Encoded data |
| Fixed-length blocks (16/32 bytes) | Block cipher (AES, DES) |
| Variable-length with padding | Stream cipher or block cipher |
| 32-char hex | MD5 hash |
| 64-char hex | SHA-256 hash |
| 128-char hex | SHA-512 hash |
| `-----BEGIN RSA` | RSA public key |
| `-----BEGIN EC` | ECC key |
| `-----BEGIN CERTIFICATE` | X.509 certificate |
| `0x3082` prefix | ASN.1/DER encoded |

### Step 2: Identify What You Control

Look for:
- **Oracle access**: Can you encrypt/decrypt arbitrary data?
- **Leakage**: Timing, side-channels, error messages?
- **Nonce/IV reuse**: Same key with same nonce?
- **Known plaintext**: Do you know part of the message?
- **Chosen plaintext/ciphertext**: Can you influence input/output?
- **Key weaknesses**: Small exponents, weak primes, predictable randomness?

### Step 3: Apply Attack Template

Match your situation to known attacks:

#### Symmetric Crypto Attacks
- **ECB mode**: Look for repeated blocks → pattern leakage
- **CBC padding oracle**: Manipulate ciphertext, observe padding errors
- **Nonce reuse (CTR/GCM)**: XOR two ciphertexts to recover plaintext
- **Stream cipher reuse**: XOR keystreams to recover messages
- **Meet-in-the-middle**: For double encryption

#### Hash Attacks
- **Length extension**: Append data to hash (MD5, SHA-1, SHA-256)
- **Collision attacks**: MD5, SHA-1 (use hashclash, shashcoll)
- **Rainbow tables**: Precomputed hash lookups
- **Brute force**: Weak passwords, small keyspaces

#### RSA Attacks
- **Small exponent (e=3)**: Cube root attack if m^e < n
- **Common factor**: gcd(n1, n2) reveals shared prime
- **Wiener's attack**: Small d, continued fractions
- **Bleichenbacher**: Padding oracle
- **Lattice attacks**: Coppersmith for partial key knowledge
- **Factoring**: Pollard's p-1, ECM, GNFS (use yafu, msieve)

#### ECC Attacks
- **Weak curves**: Small order, anomalous curves
- **Side-channel**: Timing, power analysis
- **Invalid curve**: Point on different curve
- **Small subgroup**: Force point into small subgroup

## Tools Reference

### Python Libraries

```python
from Crypto.Cipher import AES, DES, PKCS1_OAEP
from Crypto.Util.number import *
from Crypto.Hash import SHA256, MD5
import gmpy2
import sympy
from pwn import *
```

### Common Utilities

| Task | Tool |
|------|------|
| Base64/hex decode | `scripts/crypto-decode.py` |
| Hash identification | `hashid`, `scripts/hash-identify.py` |
| RSA factoring | `yafu`, `msieve`, `factordb.com` |
| Hash cracking | `hashcat`, `john` |
| SSL/TLS analysis | `nmap --script ssl-enum-ciphers` |
| Certificate inspection | `openssl x509 -text -in cert.pem` |
| Lattice attacks | SageMath, `fplll` |

## Common Patterns

### Base64 Detection
```python
import base64
import re

# Standard base64
if re.match(r'^[A-Za-z0-9+/=]+$', data):
    try:
        decoded = base64.b64decode(data)
    except:
        pass

# URL-safe base64
if re.match(r'^[A-Za-z0-9_-]+$', data):
    try:
        decoded = base64.urlsafe_b64decode(data + '==')
    except:
        pass
```

### Hash Identification
```python
import hashlib
import re

hash_patterns = {
    'MD5': (32, r'^[a-f0-9]{32}$'),
    'SHA-1': (40, r'^[a-f0-9]{40}$'),
    'SHA-256': (64, r'^[a-f0-9]{64}$'),
    'SHA-512': (128, r'^[a-f0-9]{128}$'),
}

for name, (length, pattern) in hash_patterns.items():
    if re.match(pattern, data):
        print(f"Likely {name}")
```

### RSA Helper Functions
```python
from Crypto.Util.number import *

def rsa_decrypt(c, d, n):
    """Decrypt RSA ciphertext"""
    m = pow(c, d, n)
    return long_to_bytes(m)

def rsa_encrypt(m, e, n):
    """Encrypt with RSA"""
    c = pow(bytes_to_long(m), e, n)
    return c

def factor_rsa(n, e, c):
    """Factor n and decrypt (use factordb or yafu for large n)"""
    # Use external tools for large numbers
    pass
```

## Attack Templates

### CBC Padding Oracle
```python
def cbc_padding_oracle(oracle, ciphertext):
    """Exploit CBC padding oracle"""
    block_size = 16
    plaintext = b''
    
    for block_idx in range(len(ciphertext) // block_size - 1, -1, -1):
        block = ciphertext[block_idx*block_size:(block_idx+1)*block_size]
        prev_block = ciphertext[(block_idx-1)*block_size:block_idx*block_size] if block_idx > 0 else b'\x00' * block_size
        
        for byte_idx in range(block_size - 1, -1, -1):
            # ... padding oracle logic
            pass
    
    return plaintext
```

### Hash Length Extension
```python
def length_extension(hash_value, original_data, appended_data):
    """Perform hash length extension attack"""
    # Works on MD5, SHA-1, SHA-256 (Merkle-Damgard)
    from hash_extender import HashExtender
    
    extender = HashExtender(hash_value, original_data)
    extended_hash = extender.extend_hash(appended_data)
    return extended_hash
```

### RSA Small Exponent Attack
```python
def rsa_small_e_attack(c, n, e=3):
    """Cube root attack for small e"""
    if e == 3:
        # Try cube root
        m = round(c ** (1/e))
        if pow(m, e, n) == c:
            return long_to_bytes(m)
    return None
```

## Best Practices

1. **Always check for weak randomness**: Many crypto challenges fail due to predictable PRNGs
2. **Look for implementation bugs**: Padding errors, timing leaks, side-channels
3. **Use the right tool**: Don't brute force when a mathematical attack exists
4. **Document your approach**: Write down what you tried and why
5. **Verify your solution**: Double-check decrypted output makes sense

## Next Steps

For detailed coverage of specific topics, see:
- **Symmetric crypto**: Block ciphers, stream ciphers, modes of operation
- **Hashes, MACs, KDFs**: Collision attacks, length extension, HMAC
- **Public-key crypto**: RSA, ECC, Diffie-Hellman attacks
- **TLS and certificates**: Protocol vulnerabilities, certificate validation
- **Crypto in malware**: Obfuscation, key extraction, runtime analysis
- **CTF misc**: Encoding schemes, custom ciphers, steganography

## Scripts

Use the bundled scripts for common tasks:
- `scripts/crypto-decode.py` - Decode various encodings (base64, hex, rot13, etc.)
- `scripts/hash-identify.py` - Identify hash types and attempt cracking
- `scripts/rsa-helper.py` - RSA encryption, decryption, and basic attacks

Run with `--help` for usage details.
