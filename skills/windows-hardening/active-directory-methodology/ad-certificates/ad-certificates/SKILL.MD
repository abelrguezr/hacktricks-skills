---
name: ad-certificate-enumeration
description: Active Directory Certificate Services (AD CS) enumeration and vulnerability assessment. Use this skill whenever the user mentions AD certificates, PKI, certificate templates, AD CS, certificate authorities, or wants to enumerate/assess certificate infrastructure in Active Directory environments. Also trigger for requests about Certify, Certipy, certificate exploitation, ESC vulnerabilities, or any AD PKI security assessment.
---

# AD Certificate Services Enumeration

A skill for enumerating and assessing Active Directory Certificate Services (AD CS) infrastructure for security vulnerabilities.

## When to Use This Skill

Use this skill when:
- Enumerating AD CS infrastructure in a penetration test or security assessment
- Identifying vulnerable certificate templates
- Assessing certificate authority configurations
- Investigating certificate-based authentication issues
- Looking for ESC (Enterprise Security Certificate) vulnerabilities
- Working with tools like Certify, Certipy, or certutil

## Core Concepts

### Certificate Components

Certificates contain these critical fields:

| Component | Purpose |
|-----------|----------|
| **Subject** | Certificate owner identity |
| **Public Key** | Paired with private key for authentication |
| **Validity Period** | NotBefore/NotAfter dates define effective duration |
| **Serial Number** | Unique identifier from CA |
| **Issuer** | Certificate Authority that issued it |
| **SubjectAlternativeName (SAN)** | Additional identities (critical for servers with multiple domains) |
| **Basic Constraints** | CA vs end-entity designation |
| **Extended Key Usages (EKUs)** | Specific purposes via OIDs (code signing, email encryption, client auth) |
| **Signature Algorithm** | Method used for signing |
| **Signature** | Guarantees authenticity (created with issuer's private key) |

### AD CS Architecture

AD CS uses these containers in Active Directory:

```
CN=Certification Authorities          # Trusted root CA certificates
CN=Enrolment Services                 # Enterprise CAs and certificate templates
CN=NTAuthCertificates                 # CA certificates authorized for AD authentication
CN=AIA (Authority Information Access) # Intermediate and cross CA certificates
```

**NTAuthCertificates** location:
```
CN=NTAuthCertificates,CN=Public Key Services,CN=Services,CN=Configuration,DC=<domain>,DC=<com>
```

### Certificate Enrollment Flow

1. Client finds an Enterprise CA
2. Client generates public-private key pair and creates CSR
3. CA assesses CSR against certificate templates and permissions
4. CA signs certificate with private key and returns to client

### Enrollment Rights

Two locations must grant permissions:

**Certificate Template Rights:**
- `Certificate-Enrollment` - Request certificates
- `Certificate-AutoEnrollment` - Automatic enrollment
- `FullControl/GenericAll` - Complete control

**Enterprise CA Rights:**
- Configured in CA security descriptor
- Accessible via Certificate Authority management console

## Enumeration Commands

### Using Certify

Certify is the primary tool for AD CS enumeration:

```powershell
# Enumerate CAs and enrollment endpoints
Certify.exe cas /domain:domain.local /showAllPermissions

# Find vulnerable templates
Certify.exe find /vulnerable
Certify.exe find /vulnerable /currentuser

# Find specific vulnerability classes
Certify.exe find /enrolleeSuppliesSubject   # ESC1 candidates
Certify.exe find /clientauth                # Client authentication templates
Certify.exe find /showAllPermissions        # Include ACLs

# Export to JSON for analysis
Certify.exe find /json /outfile:C:\Temp\adcs.json

# Enumerate PKI object ACLs (ESC4/ESC7 discovery)
Certify.exe pkiobjects /domain:domain.local /showAdmins
```

### Using Certipy

```bash
# Find vulnerable templates
certipy find -vulnerable -u user@domain.local -p password -dc-ip 10.0.0.1

# Enumerate CAs
certipy casenum -u user@domain.local -p password -dc-ip 10.0.0.1

# Request certificate
certipy req -u user@domain.local -p password -template User -dc-ip 10.0.0.1
```

### Using certutil

```powershell
# List CAs
certutil.exe -TCAInfo

# List certificate templates
certutil -v -dstemplate
```

## Vulnerability Classes (ESC)

### ESC1: Enrollee Supplies Subject

Templates where `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` is set allow attackers to specify the certificate subject, potentially impersonating any user.

**Detection:**
```powershell
Certify.exe find /enrolleeSuppliesSubject
```

### ESC2: RCE via Enrollment Agent

Templates with enrollment agent EKU that allow unauthenticated enrollment can lead to remote code execution.

### ESC3: Certificate Template Misconfiguration

Templates with weak permissions allowing modification of critical fields.

### ESC4: ACL Misconfiguration

Overly permissive ACLs on PKI objects allowing unauthorized modifications.

**Detection:**
```powershell
Certify.exe pkiobjects /showAdmins
```

### ESC5: Certificate Template Write Access

Write access to certificate templates allowing modification of permissions.

### ESC6: Certificate Template Write Access (Admin)

Write access to templates with admin privileges.

### ESC7: ACL Misconfiguration (PKI Objects)

Similar to ESC4 but affecting different PKI objects.

## Assessment Workflow

### Step 1: Initial Enumeration

```powershell
# Start with CA enumeration
Certify.exe cas /domain:TARGET.local /showAllPermissions

# Find all vulnerable templates
Certify.exe find /vulnerable /showAllPermissions
```

### Step 2: Analyze Results

Look for:
- Templates with `enrolleeSuppliesSubject` flag
- Templates with client authentication EKU
- Templates with weak ACLs (low-privilege users with write access)
- Templates with auto-enrollment enabled
- Templates requiring manager approval (may be bypassable)

### Step 3: Test Exploitation

For each vulnerable template:

```powershell
# Request certificate with vulnerable template
Certify.exe request /template:VULNERABLE_TEMPLATE /domain:TARGET.local

# Or with Certipy
certipy req -u user@domain.local -p password -template VULNERABLE_TEMPLATE
```

### Step 4: Validate Access

```powershell
# Test certificate authentication
Certify.exe auth /certificate:C:\Temp\cert.pfx /password:password

# Or with Rubeus
Rubeus.exe kerberos /ptt /certificate:C:\Temp\cert.pfx
```

## Common Findings

| Finding | Risk | Remediation |
|---------|------|-------------|
| `enrolleeSuppliesSubject` enabled | High | Disable flag, use SAN validation |
| Client auth EKU + weak ACLs | High | Restrict enrollment permissions |
| Auto-enrollment to privileged templates | Critical | Remove auto-enrollment |
| Enrollment agent EKU abuse | High | Restrict enrollment agent templates |
| Manager approval bypass | Medium | Review approval workflow |

## Best Practices

1. **Always enumerate first** - Understand the PKI landscape before testing
2. **Check both template and CA permissions** - Both must allow enrollment
3. **Export results to JSON** - For documentation and analysis
4. **Test with current user context** - Use `/currentuser` flag to see what you can actually exploit
5. **Document findings** - Include template names, vulnerability classes, and exploitation paths

## Tools Reference

| Tool | Purpose | Download |
|------|---------|----------|
| **Certify** | AD CS enumeration and exploitation | https://github.com/GhostPack/Certify |
| **Certipy** | Python-based AD CS tool | https://github.com/ly4k/Certipy |
| **Rubeus** | Kerberos attack tool | https://github.com/GhostPack/Rubeus |
| **certutil** | Built-in Windows tool | Pre-installed |

## References

- [Certified Pre-Owned (SpecterOps)](https://www.specterops.io/assets/resources/Certified_Pre-Owned.pdf)
- [GhostPack/Certify](https://github.com/GhostPack/Certify)
- [GhostPack/Rubeus](https://github.com/GhostPack/Rubeus)
- [ly4k/Certipy](https://github.com/ly4k/Certipy)
- [MS-ADCS: Active Directory Certificate Services](https://learn.microsoft.com/en-us/windows-server/identity/ad-cs/)
