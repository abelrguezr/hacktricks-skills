---
name: bruteforce-hash-few-chars
description: How to bruteforce MD5 hashes with partial matching (suffix or prefix attacks). Use this skill whenever the user mentions hash cracking, MD5 bruteforcing, partial hash matching, hash suffix attacks, loose comparison vulnerabilities, or CTF challenges involving hash manipulation. This is for security research, CTF competitions, and understanding hash collision attacks.
---

# Bruteforce Hash Few Chars

A skill for bruteforcing MD5 hashes with partial matching techniques. This covers suffix attacks (hash ends with target) and loose comparison attacks (0e prefix with no hex characters after).

## When to Use This Skill

Use this skill when:
- You need to find a plaintext that produces an MD5 hash ending with specific characters
- You're working on CTF challenges involving hash manipulation
- You need to exploit loose comparison vulnerabilities (0e prefix attacks)
- You want to understand hash collision techniques for security research
- The user mentions "hash bruteforce", "partial hash", "MD5 suffix", "0e attack", or similar concepts

## Core Concepts

### Suffix Attack
Find a plaintext where the MD5 hash ends with a specific target string. This is useful when you only need to match the last N characters of a hash.

### Loose Comparison Attack
Exploit PHP's loose comparison behavior where hashes starting with `0e` followed by only digits are treated as scientific notation (0). This requires:
1. Hash starts with `0e`
2. No hex characters (a-f) appear after the `0e` prefix

## Available Scripts

### 1. Suffix Bruteforce (`scripts/bruteforce-suffix.py`)

Bruteforces MD5 hashes to find plaintexts where the hash ends with a target suffix.

**Usage:**
```bash
python scripts/bruteforce-suffix.py --target <suffix> [--start <number>] [--max <iterations>]
```

**Example:**
```bash
# Find a number whose MD5 hash ends with '2f2e2e'
python scripts/bruteforce-suffix.py --target 2f2e2e
```

### 2. Loose Comparison Bruteforce (`scripts/bruteforce-loose-comparison.py`)

Multiprocessing bruteforce for loose comparison attacks. Finds plaintexts where MD5 hash starts with `0e` and contains no hex characters after.

**Usage:**
```bash
python scripts/bruteforce-loose-comparison.py --prefix <prefix> --suffix <suffix> [--threads <count>]
```

**Example:**
```bash
# Find a value where hash starts with '0e' and has no a-f characters
python scripts/bruteforce-loose-comparison.py --prefix "a_prefix" --suffix "a_suffix"
```

## How It Works

### Suffix Attack Algorithm
1. Start with a candidate value (number or string)
2. Compute MD5 hash of the candidate
3. Check if hash ends with target suffix
4. If match, output result; otherwise increment and repeat

### Loose Comparison Attack Algorithm
1. Use multiprocessing to parallelize the search
2. For each candidate, compute MD5 hash
3. Check if hash starts with target prefix (e.g., `0e`)
4. Verify no hex characters (a-f) appear after the prefix
5. If both conditions met, output result and exit all workers

## Test Cases

### Test Case 1: Simple Suffix Attack
```bash
# Should find a number whose MD5 ends with '2f2e2e'
python scripts/bruteforce-suffix.py --target 2f2e2e
```

### Test Case 2: Loose Comparison Attack
```bash
# Should find a value where MD5 starts with '0e' and has no a-f after
python scripts/bruteforce-loose-comparison.py --prefix "test" --suffix "val"
```

## Important Notes

1. **Performance**: Suffix attacks are generally faster than loose comparison attacks because the probability is higher (1/16^N for suffix vs 1/16^N * (10/16)^(remaining) for loose comparison)

2. **Multiprocessing**: The loose comparison script uses all available CPU cores by default. Adjust with `--threads` if needed.

3. **Search Space**: For suffix attacks, you can start from any number. For loose comparison, the search space is typically much larger.

4. **CTF Context**: These techniques are commonly used in CTF challenges involving:
   - Hash verification bypasses
   - Session token manipulation
   - Password hash weaknesses
   - PHP loose comparison exploits

## Example Output

### Suffix Attack
```
plaintext:"12345", md5:a1b2c3d4e5f67890123456782f2e2e
```

### Loose Comparison Attack
```
plaintext: a_prefix9876543210a_suffix, md5:0e123456789012345678901234567890
```

## Security Research Context

This skill is intended for:
- CTF competitions and security challenges
- Understanding hash function properties
- Security research and education
- Learning about cryptographic weaknesses

Do not use these techniques against systems you don't own or have explicit permission to test.
