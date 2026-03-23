---
name: crypto-symmetric-ctf
description: How to exploit symmetric cryptography vulnerabilities in CTF challenges. Use this skill whenever you encounter encryption, tokens, cookies, crypto challenges, or any CTF task involving AES, CBC, ECB, CTR, GCM, padding oracles, MACs, or stream ciphers. Trigger this for any challenge mentioning encryption modes, ciphertext, IVs, nonces, or authentication tags.
---

# Symmetric Crypto Exploitation

This skill helps you identify and exploit symmetric cryptography vulnerabilities in CTF challenges. Focus on **mode misuse**, **oracle attacks**, and **keystream reuse**.

## Quick Detection Checklist

When you see encryption in a CTF, immediately check:

1. **Is the ciphertext deterministic?** Same input → same output suggests ECB or fixed IV
2. **Can you control plaintext?** If yes, try block alignment attacks
3. **Does the server give different errors?** Different responses for bad padding = padding oracle
4. **Are IVs/Nonces visible or predictable?** Reuse breaks CTR and GCM catastrophically
5. **Is there a MAC?** Check for CBC-MAC on variable-length messages

## AES Mode Exploitation

### ECB (Electronic Codebook)

**Why it breaks**: ECB encrypts each block independently. Equal plaintext blocks produce equal ciphertext blocks, leaking structure.

**Detection**:
- Login multiple times with identical credentials → same cookie = deterministic encryption
- Create users with repeated characters (e.g., `AAAAAAAA...`) → look for repeated ciphertext blocks at same offsets

**Exploitation patterns**:

**Block removal**: If token format is `<username>|<password>` and block boundaries align:
1. Craft a user where `admin` appears at a block boundary
2. Remove preceding blocks to get a valid `admin` token

**Block reordering**: If the backend tolerates padding:
1. Align a block containing `admin   ` (with spaces)
2. Swap that ciphertext block into another token

**Example**: Cookie = `C1||C2||C3` where `C2` = `admin   `. Replace `C2` in a normal user's cookie with your `admin` block.

### CBC (Cipher Block Chaining)

**Why it's malleable**: `P[i] = D(C[i]) XOR C[i-1]`. Flipping bits in `C[i-1]` flips predictable bits in `P[i]`.

**Bit-flipping attack** (no oracle needed):
1. Token format: `IV || C1 || C2 || ...`
2. You control bytes in `C[i]`
3. Target plaintext in `P[i+1]` because `P[i+1] = D(C[i+1]) XOR C[i]`
4. XOR the byte you want to change with the current byte in `C[i]`

**Use case**: Change `role=user` to `role=admin` by flipping specific bits in the previous ciphertext block.

**Padding Oracle** (if server reveals padding validity):

The oracle can be:
- Different error messages
- Different HTTP status codes
- Different response sizes
- Timing differences

**Exploitation with PadBuster**:
```bash
perl ./padBuster.pl http://target.com/page "CIPHERTEXT" 16 \
  -encoding 0 -cookies "session=CIPHERTEXT"
```

Parameters:
- Block size: `16` for AES
- `-encoding 0`: Base64
- `-error "string"`: If oracle is a specific error message

**Why it works**: By modifying bytes in `C[i-1]` and observing padding validity, you recover `P[i]` byte-by-byte. Each byte requires 16-256 requests.

### CTR (Counter Mode)

**Why it breaks**: CTR turns AES into a stream cipher: `C = P XOR keystream`.

**Nonce/IV reuse is catastrophic**:
- `C1 XOR C2 = P1 XOR P2` (keystream reuse)
- With known plaintext, recover keystream: `keystream = ciphertext XOR known_plaintext`
- Apply keystream to decrypt any other ciphertext at same offsets

**Exploitation patterns**:

**Known plaintext attack**:
1. Identify predictable data (file headers, JSON keys, ASN.1 structures)
2. XOR ciphertext with known plaintext to recover keystream
3. Apply keystream to decrypt secrets at same offsets

**Example with certificates**:
- X.509 certificates have predictable ASN.1 structure
- XOR certificate ciphertext with expected certificate body
- Recover keystream, decrypt other secrets encrypted under same IV

**Same-format secrets**:
- PKCS#8 RSA keys of same modulus size have aligned prime factors
- XOR two ciphertexts: isolates `p ⊕ p'` / `q ⊕ q'`
- Brute-force recover in seconds (99.6% alignment for 2048-bit)

**Default IVs**: Libraries often use constant IVs like `000...01`. Every encryption repeats the same keystream.

**CTR malleability**:
- CTR provides confidentiality only, no integrity
- Flipping ciphertext bits flips plaintext bits at same position
- Without authentication tag, tampering goes undetected
- **Fix**: Use AEAD (GCM, GCM-SIV, ChaCha20-Poly1305) with tag verification

### GCM (Galois/Counter Mode)

**Why nonce reuse breaks GCM**:
- Same keystream reuse as CTR: `C1 XOR C2 = P1 XOR P2`
- Loss of integrity: attackers may forge tags with multiple message/tag pairs

**Operational guidance**:
- Treat nonce reuse in AEAD as critical vulnerability
- Misuse-resistant AEADs (GCM-SIV) reduce fallout but still need unique nonces
- Start with `C1 XOR C2 = P1 XOR P2` analysis when you have multiple ciphertexts under same nonce

## MAC Vulnerabilities

### CBC-MAC

**Why it's dangerous**: CBC-MAC is only secure with **fixed-length messages** and proper domain separation.

**Classic variable-length forgery**:
1. CBC-MAC computes: `tag = last_block(CBC_encrypt(key, message, IV=0))`
2. If you have tags for chosen messages, you can craft tags for concatenations
3. Exploits how CBC chains blocks without knowing the key

**Common CTF pattern**: Cookies/tokens that MAC username or role with CBC-MAC on variable-length input.

**Safer alternatives**:
- HMAC-SHA256/512
- AES-CMAC (with proper implementation)
- Include message length or domain separation

## Stream Ciphers and XOR

### The Mental Model

Most stream cipher situations reduce to:
```
ciphertext = plaintext XOR keystream
```

**Key implications**:
- Know plaintext → recover keystream
- Keystream reuse → `C1 XOR C2 = P1 XOR P2`

### XOR-based Encryption

**Known plaintext attack**:
1. Identify any known plaintext segment at position `i`
2. Recover keystream: `keystream[i] = ciphertext[i] XOR plaintext[i]`
3. Decrypt other ciphertexts at those positions

**Tools**:
- [XOR Cracker](https://wiremask.eu/tools/xor-cracker/) - autosolver for XOR challenges
- CyberChef - quick experiments with XOR operations

### RC4

RC4 is a stream cipher where encrypt/decrypt are the same operation.

**Exploitation**:
1. Get RC4 encryption of known plaintext under same key
2. Recover keystream: `keystream = ciphertext XOR known_plaintext`
3. Decrypt other messages at same length/offset

## Practical Workflow

### Step 1: Reconnaissance

1. **Identify the encryption mode**:
   - ECB: deterministic, block patterns visible
   - CBC: malleable, may have padding oracle
   - CTR/GCM: check for nonce reuse
   - Unknown: try all patterns

2. **Check for oracles**:
   - Send malformed ciphertext
   - Observe error messages, status codes, timing
   - Different responses = potential oracle

3. **Look for IV/nonce patterns**:
   - Are they visible in the ciphertext?
   - Do they change between requests?
   - Are they predictable or constant?

### Step 2: Exploitation

**For ECB**:
- Create repeated plaintext blocks
- Look for repeated ciphertext blocks
- Try block removal/reordering

**For CBC**:
- Test for padding oracle (different errors for bad padding)
- If oracle exists: use PadBuster
- If no oracle: try bit-flipping on structured data

**For CTR/GCM**:
- Check for nonce reuse across multiple ciphertexts
- XOR ciphertexts together: `C1 XOR C2`
- Look for known plaintext patterns in result
- Recover keystream from known data

**For MACs**:
- Check if CBC-MAC on variable-length messages
- Try concatenation attacks
- Look for missing length/domain separation

### Step 3: Tools

**CyberChef** (https://gchq.github.io/CyberChef/):
- Quick XOR operations
- Base64 encoding/decoding
- AES encryption/decryption
- Pattern analysis

**Python with pycryptodome**:
```python
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

# CBC decryption
cipher = AES.new(key, AES.MODE_CBC, iv)
plaintext = unpad(cipher.decrypt(ciphertext), AES.block_size)

# XOR operation
def xor_bytes(a, b):
    return bytes(x ^ y for x, y in zip(a, b))
```

**PadBuster** (https://github.com/AonCyberLabs/PadBuster):
- Automated padding oracle attacks
- Works with HTTP, cookies, custom oracles

## Common CTF Patterns

1. **Cookie/token manipulation**: ECB block swapping, CBC bit-flipping
2. **Session hijacking**: Padding oracle decryption, nonce reuse
3. **Privilege escalation**: Change `role=user` to `role=admin` via bit-flipping
4. **Secret extraction**: XOR keystream reuse with known plaintext
5. **MAC forgery**: CBC-MAC on variable-length messages

## References

- [Trail of Bits – Carelessness versus craftsmanship in cryptography](https://blog.trailofbits.com/2026/02/18/carelessness-versus-craftsmanship-in-cryptography/)
- [PadBuster](https://github.com/AonCyberLabs/PadBuster)
- [XOR Cracker](https://wiremask.eu/tools/xor-cracker/)
- [CyberChef](https://gchq.github.io/CyberChef/)
- [HTB Kryptos Writeup](https://0xrick.github.io/hack-the-box/kryptos/)
