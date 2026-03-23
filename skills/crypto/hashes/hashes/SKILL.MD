---
name: crypto-hash-cracking
description: How to crack hashes, perform length extension attacks, and break weak password hashing in CTFs. Use this skill whenever the user mentions hash cracking, password recovery, signature forgery, HMAC, MD5, SHA, bcrypt, hashcat, John the Ripper, or any CTF challenge involving cryptographic hashes. Make sure to use this skill for any challenge that involves identifying hash types, cracking password hashes, or exploiting hash length extension vulnerabilities.
---

# Crypto Hash Cracking

A skill for cracking hashes, performing length extension attacks, and breaking weak password hashing in CTF challenges.

## Common CTF Patterns

Watch for these telltale signs:

- **"Signature" is actually `hash(secret || message)`** → length extension attack possible
- **Unsalted password hashes** → trivial cracking via lookup tables
- **Confusing hash with MAC** → hash provides no authentication guarantee
- **Fast hashes (MD5/SHA1/SHA256) for passwords** → vulnerable to brute force
- **Same password reused across users** → crack one, pivot to others

## Hash Length Extension Attack

### When to use this

You can exploit length extension when a server computes signatures like:

```
sig = HASH(secret || message)
```

using Merkle–Damgård hashes (MD5, SHA-1, SHA-256, SHA-384, SHA-512).

### What you need

- The original `message`
- The original `sig` (hash output)
- The hash function used
- The length of the secret (or ability to brute-force it)

### What you get

A valid signature for:
```
message || padding || appended_data
```

without knowing the secret.

### Important: HMAC is NOT affected

Length extension attacks do NOT work on HMAC (e.g., HMAC-SHA256). HMAC is specifically designed to prevent this attack. If you see `HMAC-SHA256` or similar, this technique won't work.

### Tools

**hash_extender** (Python, most common):
```bash
pip install hash_extender
hash_extender -h sha256 -s <original_sig> -m "<original_message>" -p "<appended_data>" -l <secret_length>
```

**hashpump** (Node.js):
```bash
npm install -g hashpump
hashpump -h sha256 -s <original_sig> -m "<original_message>" -a "<appended_data>" -l <secret_length>
```

### Workflow

1. **Confirm the vulnerability**: Check if the signature is `HASH(secret || message)` not `HMAC(secret, message)`
2. **Identify the hash**: Use `hashid` or pattern matching
3. **Estimate secret length**: Try common lengths (1-64 bytes) or brute-force
4. **Run the tool**: Use hash_extender or hashpump
5. **Test the forged signature**: Submit to the target

## Password Hashing and Cracking

### Step 1: Identify the hash

First, figure out what you're dealing with:

```bash
# Quick identification
hashid <hash>

# Or search hashcat examples for patterns
hashcat --example-hashes | rg -n "<pattern>"

# Manual inspection - look for format hints:
# $6$ = SHA-512 crypt
# $2a$ = bcrypt
# $5$ = SHA-256 crypt
# $2y$ = bcrypt (alternative)
# $2b$ = bcrypt (alternative)
# $3$ = MD5 crypt
# $4$ = SHA-256 crypt
# $7$ = SHA-512 crypt
# $8$ = SHA-512 crypt (newer)
# $9$ = SHA-512 crypt (newer)
```

### Step 2: Check for salt

Look for salt indicators:
- `salt$hash` format
- `$` delimiters with multiple sections
- Long hashes with embedded salt

**Unsalted hashes** are trivial to crack via rainbow tables.

### Step 3: Choose your tool

**Hashcat** (GPU-accelerated, fastest for most cases):
```bash
# Find the mode number
hashcat --help | rg "mode"

# Run the attack
hashcat -m <mode> -a 0 hashes.txt wordlist.txt

# Common modes:
# 0 = MD5
# 10 = MD5($apr1$) - MD5 CRYPT
# 1100 = SHA-256
# 1400 = SHA-512
# 3200 = bcrypt
# 1800 = PBKDF2-SHA256
# 1700 = PBKDF2-SHA512
```

**John the Ripper** (simpler, good for crypt formats):
```bash
# Auto-detect format
john --wordlist=wordlist.txt hashes.txt

# Specify format
john --wordlist=wordlist.txt --format=<fmt> hashes.txt

# Show cracked passwords
john --show hashes.txt
```

### Step 4: Choose attack mode

**Dictionary attack** (mode 0) - try wordlist:
```bash
hashcat -m <mode> -a 0 hashes.txt wordlist.txt
```

**Rule-based attack** (mode 0 + rules) - mutate wordlist:
```bash
hashcat -m <mode> -a 0 hashes.txt wordlist.txt -r rules/best64.rule
```

**Brute force** (mode 3) - try all combinations:
```bash
hashcat -m <mode> -a 3 hashes.txt ?a?a?a?a?a?a
```

**Combinator attack** (mode 1) - combine two wordlists:
```bash
hashcat -m <mode> -a 1 hashes.txt wordlist1.txt wordlist2.txt
```

### Step 5: Optimize for speed

```bash
# Use all GPUs
hashcat -m <mode> -a 0 hashes.txt wordlist.txt --force

# Set work factor (higher = more memory, slower but more thorough)
hashcat -m <mode> -a 0 hashes.txt wordlist.txt --work-load=high

# Session management
hashcat -m <mode> -a 0 hashes.txt wordlist.txt -s <session_name>
hashcat -m <mode> -a 0 hashes.txt wordlist.txt -r <session_name>
```

## Common Exploitable Mistakes

### Weak KDF parameters

Some systems use KDFs with weak parameters:
- **PBKDF2 with low iterations** (< 10000) → still crackable
- **bcrypt with low cost** (< 10) → faster to crack
- **scrypt with low N** → vulnerable

### Truncated hashes

If you see truncated hashes (e.g., only first 8 chars):
1. Normalize the format
2. Adjust your cracking tool accordingly
3. Expect more collisions

### Custom transforms

Watch for:
- Double hashing: `hash(hash(password))`
- Salted but predictable: `hash(password + "static_salt")`
- Reversed: `hash(reverse(password))`

## Quick Reference

### Hashcat mode numbers

| Hash Type | Mode |
|-----------|------|
| MD5 | 0 |
| MD4 | 1 |
| SHA1 | 100 |
| SHA256 | 1400 |
| SHA512 | 1700 |
| bcrypt | 3200 |
| PBKDF2-SHA256 | 1800 |
| PBKDF2-SHA512 | 1700 |
| NTLM | 1000 |
| LM | 3000 |

### John formats

| Hash Type | Format |
|-----------|--------|
| MD5 | md5 |
| SHA1 | sha1 |
| SHA256 | sha256crypt |
| SHA512 | sha512crypt |
| bcrypt | bcrypt |
| NTLM | netntlm |

## Tools to Install

```bash
# Hash identification
pip install hashid

# Hash cracking
sudo apt install hashcat john

# Length extension
pip install hash_extender
npm install -g hashpump

# Wordlists
sudo apt install wordlists
# Or download: rockyou.txt, common-passwords.txt
```

## Debugging Tips

1. **Hash not cracking?** Try different wordlists or rule sets
2. **Wrong format?** Double-check with `hashid` or manual inspection
3. **Too slow?** Use GPU acceleration, reduce search space
4. **Length extension failing?** Verify it's not HMAC, check secret length
5. **Session management?** Use `-s` flag to save/restore hashcat sessions
