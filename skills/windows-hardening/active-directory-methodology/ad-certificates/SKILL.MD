---
name: ad-cs-hardening
description: Active Directory Certificate Services (AD CS) security assessment and hardening. Use this skill whenever the user mentions AD certificates, certificate authorities, PKI, ESC vulnerabilities, certificate enumeration, or needs to assess/harden AD CS infrastructure. Make sure to use this skill for any AD CS security work, vulnerability assessments, or certificate-related hardening tasks.
---

# AD Certificate Services Hardening

A comprehensive guide for assessing and hardening Active Directory Certificate Services (AD CS) environments.

## Quick Start

```bash
# Enumerate CAs and templates
certipy find -vulnerable -dc-only -u user@domain.local -p password -target dc.domain.local

# Check for vulnerable templates with Certify
Certify.exe find /vulnerable

# List all certificate templates
certutil -v -dstemplate
```

## Certificate Fundamentals

### Key Components

| Component | Purpose |
|-----------|----------|
| **Subject** | Certificate owner identity |
| **Public Key** | Paired with private key for authentication |
| **Validity Period** | NotBefore/NotAfter dates define effective duration |
| **Serial Number** | Unique identifier from CA |
| **Issuer** | Certificate Authority that issued the certificate |
| **SAN** | Subject Alternative Names for multiple identities |
| **Basic Constraints** | CA vs end-entity designation |
| **EKU** | Extended Key Usages define specific purposes |
| **Signature** | Issuer's private key signature for authenticity |

### Critical Security Considerations

**Subject Alternative Names (SANs)** are crucial for servers with multiple domains. Secure issuance processes are vital to prevent attackers from manipulating SAN specifications for impersonation.

**Template Version Matters:**
- **v1 templates** (e.g., default WebServer) lack modern enforcement controls
- **ESC15/EKUwu vulnerability**: On v1 templates, requesters can embed Application Policies/EKUs in CSRs that override template EKUs
- **Recommendation**: Use v2/v3 templates, remove or supersede v1 defaults, tightly scope EKUs

## AD CS Architecture

### Certificate Authority Containers

```
CN=Certification Authorities          # Trusted root CA certificates
CN=Enrolment Services                 # Enterprise CAs and templates
CN=NTAuthCertificates                 # CA certificates for AD authentication
CN=AIA (Authority Information Access) # Chain validation certificates
```

### NTAuthCertificates Location

```
CN=NTAuthCertificates,CN=Public Key Services,CN=Services,CN=Configuration,DC=<domain>,DC=<com>
```

## Enumeration & Assessment

### Tools Overview

| Tool | Purpose | Key Commands |
|------|---------|--------------|
| **Certify** | Enumeration & vulnerability assessment | `Certify.exe cas`, `Certify.exe find /vulnerable` |
| **Certipy** | Modern enumeration (v4+) | `certipy find -vulnerable`, `certipy req -web` |
| **certutil** | Built-in Windows tool | `certutil -TCAInfo`, `certutil -v -dstemplate` |

### Enumeration Commands

```bash
# Enumerate trusted root CAs and Enterprise CAs
Certify.exe cas

# Identify vulnerable certificate templates
Certify.exe find /vulnerable

# Certipy enumeration (v4+)
certipy find -vulnerable -dc-only -u john@corp.local -p Passw0rd -target dc.corp.local

# Request certificate via web enrollment
certipy req -web -target ca.corp.local -template WebServer -upn john@corp.local -dns www.corp.local

# Native Windows enumeration
certutil.exe -TCAInfo
certutil -v -dstemplate
```

### Certificate Request Methods

1. **MS-WCCE** - Windows Client Certificate Enrollment Protocol (DCOM)
2. **MS-ICPR** - ICertPassage Remote Protocol (named pipes/TCP)
3. **Web Enrollment** - Certificate Authority Web Enrollment role
4. **CES/CEP** - Certificate Enrollment Service
5. **NDES** - Network Device Enrollment Service (SCEP)
6. **GUI** - certmgr.msc or certlm.msc
7. **CLI** - certreq.exe or PowerShell Get-Certificate

## ESC Vulnerabilities (Enterprise Security Certificates)

### Critical Vulnerabilities Timeline

| Year | ID | Name | Impact | Patch Date |
|------|-----|------|--------|------------|
| 2022 | CVE-2022-26923 | Certifried / ESC6 | Privilege escalation via PKINIT spoofing | May 10, 2022 |
| 2023 | CVE-2023-35350/35351 | Web Enrollment RCE | Remote code execution in certsrv/CES | July 2023 |
| 2024 | CVE-2024-49019 | EKUwu / ESC15 | v1 template EKU override | Nov 12, 2024 |

### ESC Vulnerability Categories

| ESC | Description | Mitigation |
|-----|-------------|------------|
| **ESC1** | Enrollment Agent abuse | Restrict Enrollment Agent templates |
| **ESC2** | Any Purpose / No EKU | Remove from templates |
| **ESC3** | PKINIT abuse | Strong certificate binding |
| **ESC4** | ESC1 + ESC2 combo | Address both |
| **ESC5** | ESC1 + ESC3 combo | Address both |
| **ESC6** | Machine account spoofing | Patch KB5014754 |
| **ESC7** | ESC1 + ESC6 combo | Address both |
| **ESC8** | DC certificate issuance | Restrict DC template enrollment |
| **ESC11** | RPC relay | Enforce encryption |
| **ESC15** | v1 template EKU override | Use v2/v3 templates |

## Hardening Recommendations

### Immediate Actions

1. **Patch all systems**
   - Apply May 2022 or later security updates
   - Install KB5014754 for strong certificate binding

2. **Template hardening**
   ```bash
   # Disable "Supply in the request" option
   # Remove Any Purpose / No EKU from templates
   # Require manager approval for sensitive templates
   ```

3. **Enrollment controls**
   - Restrict web enrollment (certsrv) to trusted networks
   - Require HTTPS + Extended Protection
   - Disable NTLM where possible

4. **RPC enrollment encryption**
   ```bash
   certutil -setreg CA\InterfaceFlags +IF_ENFORCEENCRYPTICERTREQUEST
   ```

### Microsoft Strong Certificate Binding (KB5014754)

Microsoft's three-phase rollout:

1. **Compatibility** - Legacy behavior maintained
2. **Audit** - Event ID 39/41 for weak mappings
3. **Enforcement** - Full enforcement (automatic Feb 11, 2025)

**Action items:**
- Patch all DCs & AD CS servers
- Monitor Event ID 39/41 during Audit phase
- Re-issue client-auth certificates with SID extension
- Configure strong manual mappings before Feb 2025

### Defender for Identity Integration

Deploy AD CS sensors to all AD CS servers for:
- Posture assessments (ESC1-ESC8, ESC11, ESC15)
- Real-time alerts:
  - "Domain-controller certificate issuance for a non-DC" (ESC8)
  - "Prevent Certificate Enrollment with arbitrary Application Policies" (ESC15)

## Certificate Authentication

### Kerberos PKINIT Process

1. User requests TGT signed with certificate private key
2. Domain controller validates:
   - Certificate validity
   - Certificate path
   - Revocation status
   - Trusted source
   - Issuer in NTAUTH certificate store
3. TGT issued on successful validation

### Schannel Authentication

- TLS/SSL handshake with certificate presentation
- Certificate-to-account mapping via:
  - Kerberos S4U2Self
  - Subject Alternative Name (SAN)

## Scripts

See the `scripts/` directory for:
- `enumerate-cs.py` - AD CS enumeration helper
- `check-esc-vulns.py` - ESC vulnerability checker
- `hardening-checklist.sh` - Hardening validation script

## References

- [TrustedSec EKUwu Analysis](https://trustedsec.com/blog/ekuwu-not-just-another-ad-cs-esc)
- [Microsoft Defender for Identity](https://learn.microsoft.com/en-us/defender-for-identity/security-posture-assessments/certificates)
- [SpecterOps Certified Pre-Owned](https://www.specterops.io/assets/resources/Certified_Pre-Owned.pdf)
- [Microsoft KB5014754](https://support.microsoft.com/en-us/topic/kb5014754-certificate-based-authentication-changes-on-windows-domain-controllers)
- [Eventus Security Advisory](https://advisory.eventussecurity.com/advisory/critical-vulnerability-in-ad-cs-allows-privilege-escalation/)
