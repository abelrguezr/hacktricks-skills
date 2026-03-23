---
name: tls-certificates
description: Parse, analyze, and convert X.509 certificates and TLS-related files. Use this skill whenever the user mentions certificates, TLS, SSL, X.509, PEM, DER, PKCS#12, PKCS#7, certificate parsing, certificate validation, or anything related to cryptographic certificates and trust chains. Also use when users need to inspect certificate fields, convert between formats, or understand certificate security issues.
---

# TLS & Certificates Skill

A skill for working with X.509 certificates, parsing certificate data, converting between formats, and identifying common security issues.

## When to use this skill

Use this skill when the user:
- Needs to parse or inspect a certificate file
- Wants to convert between certificate formats (PEM, DER, PKCS#7, PKCS#12)
- Is investigating certificate-related security issues
- Needs to understand certificate fields and their meaning
- Is working with TLS/SSL configurations
- Wants to check certificate validity or trust chains

## Quick certificate parsing

To inspect a certificate, use these commands:

```bash
# Full certificate details
openssl x509 -in cert.pem -noout -text

# ASN.1 structure parsing
openssl asn1parse -in cert.pem
```

### Key fields to inspect

When analyzing a certificate, always check these fields:

| Field | What to look for |
|-------|------------------|
| **Subject / Issuer** | Who issued it? Is it self-signed? |
| **SAN (Subject Alternative Names)** | What domains/IPs does it cover? |
| **Key Usage / EKU** | What operations is it allowed to perform? |
| **Basic Constraints** | Is it a CA certificate? (CA:TRUE) |
| **Validity window** | NotBefore/NotAfter - is it expired or not yet valid? |
| **Signature algorithm** | MD5/SHA1 are weak and deprecated |

## Certificate formats

### PEM
- Base64-encoded with `-----BEGIN CERTIFICATE-----` headers
- Text format, human-readable
- Common extensions: `.pem`, `.crt`, `.cer`

### DER
- Binary ASN.1 encoding
- Smaller than PEM, not human-readable
- Common extension: `.der`

### PKCS#7 (`.p7b`)
- Certificate chain (multiple certificates)
- Does NOT include private key
- Used for distributing certificate chains

### PKCS#12 (`.pfx`, `.p12`)
- Certificate + private key + chain
- Password-protected
- Used for importing/exporting certificates with keys

## Format conversions

### PEM to DER
```bash
openssl x509 -in cert.pem -outform DER -out cert.der
```

### DER to PEM
```bash
openssl x509 -in cert.der -inform DER -outform PEM -out cert.pem
```

### PKCS#12 to PEM (extract cert and key)
```bash
openssl pkcs12 -in file.pfx -out out.pem -nodes
```

### PKCS#7 to PEM (extract certificates)
```bash
openssl pkcs7 -in file.p7b -print_certs -out certs.pem
```

### Convert .cer to PEM
```bash
openssl x509 -in cert.cer -outform PEM -out cert.pem
```

## Common security issues to check

When reviewing certificates, look for these red flags:

### 1. Weak signature algorithms
- **MD5**: Completely broken, never use
- **SHA1**: Deprecated, avoid
- **SHA256+**: Current standard

### 2. Missing chain validation
- Certificate should chain to a trusted root
- Self-signed certificates need explicit trust
- Check if intermediate CAs are present

### 3. Name constraint violations
- SAN should match the intended domain
- Wildcard certificates (`*.example.com`) only match one subdomain level
- Implementation-specific parsing bugs may exist

### 4. Confused deputy issues
- Client certificate authentication may be misbound
- Ensure the certificate is actually being used for authentication
- Check for proper binding between certificate and session

### 5. Basic constraints issues
- End-entity certificates should have `CA:FALSE`
- CA certificates should have `CA:TRUE` and proper path length constraints

## Certificate transparency

Check if a certificate has been logged in CT logs:
- Visit [crt.sh](https://crt.sh/) and search by domain
- This shows all certificates ever issued for a domain
- Useful for detecting unauthorized certificate issuance

## Example workflow

**User**: "I have this certificate file and need to understand what it's for"

**You should**:
1. Parse the certificate with `openssl x509 -in cert.pem -noout -text`
2. Extract and explain the key fields (Subject, Issuer, SAN, Validity, Key Usage)
3. Check for any security concerns (weak algorithms, expired, self-signed)
4. Suggest next steps based on the findings

**User**: "Convert this .pfx file to something I can use"

**You should**:
1. Ask if they need the private key extracted
2. Use `openssl pkcs12 -in file.pfx -out out.pem -nodes` to extract
3. Explain the output (separate cert and key files)
4. Remind them to protect the private key

## Tools you'll need

- `openssl` - Required for all certificate operations
- `openssl` version 1.1.1 or 3.x recommended for full feature support

## Common pitfalls

1. **File format confusion**: If a command fails, try specifying `-inform DER` or `-inform PEM` explicitly
2. **PKCS#12 passwords**: You'll be prompted for the import password
3. **Private key protection**: Never share private keys; use `-nodes` only when you need the unencrypted key
4. **Chain order**: When building chains, order matters (leaf cert first, then intermediates, then root)
