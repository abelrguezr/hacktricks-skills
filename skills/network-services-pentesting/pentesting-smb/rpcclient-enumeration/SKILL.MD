---
name: rpcclient-enumeration
description: Use rpcclient to enumerate Windows systems via SMB/RPC. Use this skill whenever the user needs to enumerate users, groups, domains, or shares on a Windows target, or when they mention rpcclient, SMB enumeration, RID cycling, SID enumeration, or Windows domain reconnaissance. This skill provides commands and scripts for SAMR, LSARPC, and LSARPC-DS interfaces.
---

# RPCClient Enumeration

A skill for enumerating Windows systems using rpcclient from Samba. This covers user, group, domain, and share enumeration through SMB/RPC interfaces.

## When to Use This Skill

Use this skill when:
- You need to enumerate users, groups, or domains on a Windows target
- You have SMB access and want to extract information via RPC
- You're doing Windows domain reconnaissance
- You need to cycle through RIDs to find valid users
- You're working with SAMR, LSARPC, or LSARPC-DS interfaces

## Prerequisites

- SMB session established to target
- Credentials (or null session with `-N -U ""`)
- rpcclient from Samba installed

## Core Concepts

### SIDs and RIDs

- **SID (Security Identifier)**: Unique identifier for a domain
- **RID (Relative Identifier)**: Appended to SID to identify objects within the domain
- **Full SID format**: `S-1-5-21-<domain-rid>-<user-rid>`
- **Example**: `S-1-5-21-1074507654-1937615267-42093643874-1111` (user pepe with RID 1111)

## Quick Start

```bash
# Basic connection (null session)
rpcclient -N -U "" [TARGET_IP]

# With credentials
rpcclient -U [username] [TARGET_IP]
```

## User Enumeration

### List All Users

```bash
querydispinfo
enumdomusers
```

### Get User Details

```bash
queryuser <0xrid>
```

### Get User Groups

```bash
queryusergroups <0xrid>
```

### Get User SID

```bash
lookupnames <username>
```

### Get User Aliases

```bash
queryuseraliases [builtin|domain] <sid>
```

### RID Cycling Script

Use the bundled script to enumerate users by cycling through RIDs:

```bash
./scripts/rpcclient-rid-cycler.sh [TARGET_IP] [START_RID] [END_RID]
```

Default range is 500-1100 (common user RIDs).

## Group Enumeration

### List All Groups

```bash
enumdomgroups
```

### Get Group Details

```bash
querygroup <0xrid>
```

### Get Group Members

```bash
querygroupmem <0xrid>
```

### Alias Groups

```bash
enumalsgroups [builtin|domain]
queryaliasmem [builtin|domain] <0xrid>
```

## Domain Enumeration

### List Domains

```bash
enumdomains
```

### Get Domain SID

```bash
lsaquery
```

### Get Domain Info

```bash
querydominfo
```

### Trusted Domains

```bash
dsenumdomtrusts
```

### Primary Domain Info

```bash
dsroledominfo
```

## Share Enumeration

### List All Shares

```bash
netshareenumall
```

### Get Share Info

```bash
netsharegetinfo <share>
```

## Server Information

```bash
srvinfo
```

## Command Reference

| Command | Interface | Description |
|---------|-----------|-------------|
| queryuser | SAMR | Retrieve user information |
| querygroup | SAMR | Retrieve group information |
| querydominfo | SAMR | Retrieve domain information |
| enumdomusers | SAMR | Enumerate domain users |
| enumdomgroups | SAMR | Enumerate domain groups |
| createdomuser | SAMR | Create a domain user |
| deletedomuser | SAMR | Delete a domain user |
| lookupnames | LSARPC | Look up usernames to SID values |
| lookupsids | LSARPC | Look up SIDs to usernames (RID cycling) |
| lsaaddacctrights | LSARPC | Add rights to a user account |
| lsaremoveacctrights | LSARPC | Remove rights from a user account |
| dsroledominfo | LSARPC-DS | Get primary domain information |
| dsenumdomtrusts | LSARPC-DS | Enumerate trusted domains within an AD forest |

## Tips

1. **RID ranges**: Common user RIDs start at 500. Admin accounts often have RIDs 500-515.
2. **Null sessions**: Try `-N -U ""` first before using credentials.
3. **Error handling**: Some commands may fail if permissions are insufficient.
4. **Combine with other tools**: Use samrdump.py for additional enumeration.
5. **Document findings**: Save output for later analysis.

## Related Skills

- SMB enumeration
- Windows domain reconnaissance
- MSRPC pentesting
