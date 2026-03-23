---
name: windows-acl-analysis
description: Analyze and explain Windows Access Control Lists (ACLs), DACLs, SACLs, and ACEs for security auditing, privilege escalation research, permission troubleshooting, or hardening. Use this skill whenever the user mentions Windows permissions, access control, ACLs, DACLs, SACLs, ACEs, file/folder permissions, security descriptors, privilege escalation, or anything related to Windows access control mechanisms. Trigger even if the user doesn't explicitly use these terms but is asking about who can access what on Windows systems.
---

# Windows ACL Analysis

This skill helps you understand, analyze, and work with Windows Access Control Lists (ACLs) for security auditing, privilege escalation research, permission troubleshooting, and system hardening.

## Core Concepts

### What is an ACL?

An **Access Control List (ACL)** is an ordered set of Access Control Entries (ACEs) that dictate protections for an object and its properties. It defines which actions by which security principals (users or groups) are permitted or denied on a given object.

### Two Types of ACLs

| Type | Purpose | Location |
|------|---------|----------|
| **DACL** (Discretionary Access Control List) | Specifies which users/groups have or do not have access | Security tab → Permissions |
| **SACL** (System Access Control List) | Governs auditing of access attempts | Security tab → Auditing |

### How Access Decisions Work

1. User session has an **access token** containing user/group identities and privileges
2. **LSASS** (Local Security Authority) processes access requests
3. System examines the object's **DACL** for matching ACEs
4. Access is granted/denied based on ACE evaluation order
5. **SACLs** log access attempts to Security Event Log

## Access Control Entries (ACEs)

### Three Main ACE Types

| Type | Purpose | ACL Location |
|------|---------|-------------|
| **Access Denied ACE** | Explicitly denies access | DACL |
| **Access Allowed ACE** | Explicitly grants access | DACL |
| **System Audit ACE** | Generates audit logs | SACL |

### Four Critical ACE Components

1. **SID** - Security Identifier of the user or group
2. **Flag** - Identifies ACE type (deny, allow, or audit)
3. **Inheritance flags** - Determines if child objects inherit the ACE
4. **Access mask** - 32-bit value specifying granted rights

### ACE Evaluation Order

Access determination examines each ACE **sequentially** until:

1. An **Access-Denied ACE** explicitly denies requested rights → **Access denied**
2. **Access-Allowed ACE(s)** grant all requested rights → **Access granted**
3. All ACEs checked with no explicit allow → **Implicitly denied**

### Canonical Order (Best Practice)

For Windows 2000+ systems, organize ACEs in this order:

1. **Explicit ACEs** (specific to this object) before inherited ACEs
2. Within explicit ACEs: **Deny** before **Allow**
3. For inherited ACEs: Start with **closest parent**, work backward
4. Within inherited: **Deny** before **Allow**

**Why this matters:**
- Specific "deny" rules are respected regardless of other "allow" rules
- Object owners have final say before parent folder rules apply

## Access Mask Structure

| Bit Range | Meaning | Examples |
|-----------|---------|----------|
| 0-15 | Object Specific Rights | Read data, Execute, Append data |
| 16-22 | Standard Rights | Delete, Write ACL, Write Owner |
| 23 | Can access security ACL | - |
| 24-27 | Reserved | - |
| 28 | Generic ALL | Read + Write + Execute |
| 29 | Generic Execute | Execute program |
| 30 | Generic Write | Write to file |
| 31 | Generic Read | Read file |

## ACE Types Explained

### Generic ACEs
- Apply broadly to all object types
- Distinguish only between containers (folders) and non-containers (files)
- Example: Allow users to see folder contents but not access files within

### Object-Specific ACEs
- Provide precise control for specific object types
- Can control access to individual properties
- Common in Active Directory environments
- Example: Allow user to update phone number but not login hours

## Practical Scenarios

### Scenario 1: Deny Access to a Specific Group

**Goal:** Everyone can access a folder except the marketing team.

**Solution:**
1. Add **Deny ACE** for Marketing group
2. Add **Allow ACE** for Everyone/Domain Users
3. Place Deny ACE **before** Allow ACE in the list

### Scenario 2: Allow Specific Member of Denied Group

**Goal:** Bob (marketing director) needs access despite marketing team being denied.

**Solution:**
1. Add **Allow ACE** for Bob (specific user)
2. Add **Deny ACE** for Marketing group
3. Place Bob's Allow ACE **before** the group Deny ACE

**Key principle:** More specific ACEs should come before less specific ones.

## GUI Navigation

### Viewing ACLs in Windows

1. **Right-click** folder/file → **Properties** → **Security** tab
2. Shows current **DACL** with users/groups and their permissions
3. Click **Advanced** for:
   - Full ACE list with order
   - Inheritance settings
   - Owner and group information
4. **Auditing** tab shows **SACL** configuration

## Common Use Cases

### Security Auditing
- Review DACLs for overly permissive settings
- Check SACLs to ensure access attempts are logged
- Identify accounts with excessive privileges

### Privilege Escalation Research
- Find misconfigured permissions that allow unauthorized access
- Identify objects where you can modify ACLs (Write ACL permission)
- Look for inheritance issues that grant unexpected access

### Permission Troubleshooting
- Diagnose why a user can't access a resource
- Understand conflicting ACEs
- Verify inheritance is working as expected

### System Hardening
- Remove unnecessary permissions
- Ensure least privilege principle
- Configure proper auditing via SACLs

## Key Takeaways

- **DACLs** control access; **SACLs** control auditing
- **ACE order matters** - first matching rule wins
- **Deny beats Allow** when both apply
- **Specific beats General** - user ACEs before group ACEs
- **Explicit beats Inherited** - object-specific rules before parent rules
- Access is **implicitly denied** if no ACE explicitly allows it

## When to Use This Skill

Use this skill when you need to:
- Understand Windows permission structures
- Analyze access control configurations
- Troubleshoot permission issues
- Research privilege escalation vectors
- Audit security settings
- Harden Windows systems
- Explain ACL concepts to others

## References

- [NTFS Permissions and ACL Use](https://www.ntfs.com/ntfs-permissions-acl-use.htm)
- [ACL, DACL, SACL and the ACE](https://secureidentity.se/acl-dacl-sacl-and-the-ace/)
- [NTFS ACL Documentation](https://www.coopware.in2.info/_ntfsacl_ht.htm)
- [Microsoft Access Mask Documentation](https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-dtyp/7a53f60e-e730-4dfe-bbe9-b21b62eb790b)
