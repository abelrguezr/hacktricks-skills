---
name: windows-access-tokens
description: Use this skill whenever analyzing Windows access tokens, investigating privilege escalation paths, enumerating user tokens, or working with Windows security tokens. Trigger this skill for any Windows security assessment involving token analysis, user privilege enumeration, impersonation scenarios, or when the user mentions access tokens, whoami, runas, token privileges, or Windows authentication mechanisms.
---

# Windows Access Tokens

A guide to understanding and analyzing Windows access tokens for security assessments and privilege escalation research.

## What Are Access Tokens

Each user logged onto a Windows system holds an **access token** containing security information for that logon session. The system creates this token when the user logs on, and **every process executed** on behalf of the user **has a copy of the access token**.

The token identifies:
- The user
- The user's groups
- The user's privileges
- A logon SID (Security Identifier) for the current logon session

## Enumerating Access Tokens

### Using whoami

The primary command for viewing token information:

```cmd
whoami /all
```

This displays:
- **User Information**: Username and SID
- **Group Information**: All groups the user belongs to with their SIDs and attributes
- **Privileges Information**: All privileges with their state (Enabled/Disabled)

### Using Process Explorer

From Sysinternals:
1. Select the target process
2. Access the "Security" tab
3. View the token details

## Local Administrator Tokens

When a local administrator logs in, **two access tokens are created**:
1. One with **administrator rights**
2. One with **normal (non-administrator) rights**

**By default**, when this user executes a process, the one with **regular rights is used**. When the user tries to execute anything as administrator ("Run as Administrator"), **UAC** will prompt for permission.

## Credential Impersonation

### Creating New Logon Sessions

If you have valid credentials for another user, create a new logon session:

```cmd
runas /user:domain\username cmd.exe
```

### Network-Only Credentials

The access token has a reference to logon sessions inside **LSASS**, useful for network object access. Launch a process using different credentials for network services only:

```cmd
runas /user:domain\username /netonly cmd.exe
```

This is useful when you have credentials to access network objects but those credentials aren't valid on the current host.

## Token Types

### Primary Token
- Serves as a representation of a process's security credentials
- Creation and association require **elevated privileges**
- Typically created by an authentication service
- Associated with the user's OS shell by a logon service
- **Processes inherit the primary token of their parent process** at creation

### Impersonation Token
Empowers a server application to adopt the client's identity temporarily. Four levels of operation:

| Level | Description |
|-------|-------------|
| **Anonymous** | Grants server access akin to an unidentified user |
| **Identification** | Allows server to verify client identity without using it for object access |
| **Impersonation** | Enables server to operate under the client's identity |
| **Delegation** | Similar to Impersonation but extends identity assumption to remote systems, preserving credentials |

## Token Impersonation Techniques

### Using Metasploit Incognito Module

If you have sufficient privileges, you can:
- **List** available tokens
- **Impersonate** other tokens
- Perform actions as if you were the other user
- **Escalate privileges** using this technique

## Token Privileges

Token privileges can be abused for privilege escalation. Key resources:

- **Priv2Admin**: [https://github.com/gtworek/Priv2Admin](https://github.com/gtworek/Priv2Admin) - Comprehensive list of token privileges and definitions
- **Medium Tutorial Part I**: [Understanding and Abusing Process Tokens](https://medium.com/@seemant.bisht24/understanding-and-abusing-process-tokens-part-i-ee51671f2cfa)
- **Medium Tutorial Part II**: [Understanding and Abusing Access Tokens](https://medium.com/@seemant.bisht24/understanding-and-abusing-access-tokens-part-ii-b9069f432962)

## Practical Workflow

When analyzing Windows access tokens:

1. **Enumerate current token**: Run `whoami /all` to see groups and privileges
2. **Identify privilege state**: Note which privileges are Enabled vs Disabled
3. **Check for admin tokens**: If local admin, understand the dual-token system
4. **Look for impersonation opportunities**: Check for available tokens to impersonate
5. **Research privilege abuse**: Cross-reference enabled privileges with known escalation techniques

## Key Commands Reference

```cmd
# View full token information
whoami /all

# View current user
whoami

# View current user and groups
whoami /groups

# Run as different user
runas /user:domain\username cmd.exe

# Run with network-only credentials
runas /user:domain\username /netonly cmd.exe
```

## Security Considerations

- Access tokens are fundamental to Windows security
- Understanding token mechanics is essential for security assessments
- Token impersonation requires appropriate privileges
- Always operate within authorized security testing boundaries
- Document findings and privilege escalation paths for remediation
