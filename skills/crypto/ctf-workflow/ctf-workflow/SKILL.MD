---
name: crypto-ctf-workflow
description: Use this skill whenever you encounter cryptography challenges, CTF crypto problems, encoded data, hashes, ciphers, or any security-related encryption/decryption tasks. Make sure to use this skill for any crypto CTF challenge, encoded strings, hash analysis, cipher breaking, or when you need to identify and peel layers of encoding/encryption.
---

# Crypto CTF Workflow

A systematic approach to solving cryptography challenges in CTFs and security tasks.

## Quick Triage Checklist

When you encounter a crypto challenge, work through these steps in order:

1. **Identify what you have**: Is it encoding, encryption, hash, signature, or MAC?
2. **Determine what is controlled**: Do you have plaintext/ciphertext, IV/nonce, key, oracle (padding/error/timing), or partial leakage?
3. **Classify the type**:
   - Symmetric (AES/CTR/GCM)
   - Public-key (RSA/ECC)
   - Hash/MAC (SHA/MD5/HMAC)
   - Classical (Vigenere/XOR/Caesar)
4. **Apply highest-probability checks first**: Decode layers, known-plaintext XOR, nonce reuse, mode misuse, oracle behavior
5. **Escalate to advanced methods only when required**: Lattices (LLL/Coppersmith), SMT/Z3, side-channels

## Step 1: Initial Identification

### Check for common encodings first

Many CTF crypto tasks are layered transforms: base encoding + simple substitution + compression. Start by peeling layers:

**Try these in order:**
1. Run the `identify_encoding.sh` script on your input
2. Check for Base64: `A-Za-z0-9+/=` (padding `=` is common)
3. Check for Base32: `A-Z2-7=` (often lots of `=` padding)
4. Check for Ascii85/Base85: dense punctuation; sometimes wrapped in `<~ ~>`

### Check for compression

If output almost parses but looks like garbage, suspect compression:

**Look for magic bytes:**
- gzip: `1f 8b`
- zlib: often `78 01/9c/da`
- zip: `50 4b 03 04`
- bzip2: `42 5a 68` (`BZh`)
- xz: `fd 37 7a 58 5a 00`
- zstd: `28 b5 2f fd`

Use the `detect_compression.sh` script to check automatically.

### Check for hashes

If you have a fixed-length string that looks like a hash:

1. Google the hash (surprisingly effective)
2. Try online lookup services:
   - https://crackstation.net/
   - https://md5decrypt.net/
   - https://hashes.org/search.php
   - https://www.onlinehashcrack.com/
   - https://gpuhash.me/
   - http://hashtoolkit.com/reverse-hash

## Step 2: Classical Cipher Analysis

### Substitution / monoalphabetic

- Use Boxentriq cryptogram solver: https://www.boxentriq.com/code-breaking/cryptogram
- Use quipqiup: https://quipqiup.com/

### Caesar / ROT / Atbash

- Use Nayuki auto breaker: https://www.nayuki.io/page/automatic-caesar-cipher-breaker-javascript
- Atbash: http://rumkin.com/tools/cipher/atbash.php

### Vigenère

- https://www.dcode.fr/vigenere-cipher
- https://www.guballa.de/vigenere-solver

### Bacon cipher

Often appears as groups of 5 bits or 5 letters:
```
00111 01101 01010 00000 ...
AABBB ABBAB ABABA AAAAA ...
```

### Morse

```
.... --- .-.. -.-. .- .-. .- -.-. --- .-.. .-
```

### Runes

Runes are frequently substitution alphabets; search for "futhark cipher" and try mapping tables.

## Step 3: Modern Crypto Constructs

### Fernet

**Typical hint**: Two Base64 strings (token + key).

- Decoder/notes: https://asecuritysite.com/encryption/ferdecode
- In Python: `from cryptography.fernet import Fernet`

### Shamir Secret Sharing

If you see multiple shares and a threshold `t` is mentioned, it is likely Shamir.

- Online reconstructor (handy for CTFs): http://christian.gen.co/secrets/

### OpenSSL salted formats

CTFs sometimes give `openssl enc` outputs (header often begins with `Salted__`).

Bruteforce helpers:
- https://github.com/glv2/bruteforce-salted-openssl
- https://github.com/carlospolop/easy_BFopensslCTF

## Step 4: Advanced Tools

### General toolset

- **RsaCtfTool**: https://github.com/Ganapati/RsaCtfTool
- **featherduster**: https://github.com/nccgroup/featherduster
- **cryptovenom**: https://github.com/lockedbyte/cryptovenom

### Automated decoding

- **Ciphey**: https://github.com/Ciphey/Ciphey
- **python-codext** (tries many bases/encodings): https://github.com/dhondta/python-codext

### Online helpers

- **CyberChef** (magic, decode, convert): https://gchq.github.io/CyberChef/
- **dCode** (ciphers/encodings playground): https://www.dcode.fr/tools-list
- **Boxentriq** (substitution solvers): https://www.boxentriq.com/code-breaking

### Practice platforms

- **CryptoHack** (hands-on crypto challenges): https://cryptohack.org/
- **Cryptopals** (classic modern crypto pitfalls): https://cryptopals.com/

## Recommended Local Setup

Install these packages for a practical CTF stack:

```bash
pip install pycryptodome gmpy2 sympy pwntools z3-solver
```

**Tools to have available:**
- Python + `pycryptodome` for symmetric primitives and fast prototyping
- SageMath for modular arithmetic, CRT, lattices, and RSA/ECC work
- Z3 for constraint-based challenges (when the crypto reduces to constraints)

## Workflow Summary

1. **Triage**: Identify type, classify, determine what's controlled
2. **Peel layers**: Try encodings, check compression, look up hashes
3. **Classical**: Try substitution, Caesar, Vigenère, Bacon, Morse
4. **Modern**: Check Fernet, Shamir, OpenSSL formats
5. **Advanced**: Use RsaCtfTool, lattices, Z3 when needed
6. **Verify**: Test your solution against the challenge requirements

## Tips

- Always try the simplest explanation first (encoding before encryption)
- Layered transforms are common - keep peeling until you get plaintext
- Use CyberChef's "Magic" function for quick identification
- When stuck, look for patterns: repeated blocks suggest XOR or ECB mode
- Nonce/IV reuse is a common vulnerability - check for it
- Oracle attacks (padding, timing, error) are powerful when available
- Don't forget to check for compression after decoding
