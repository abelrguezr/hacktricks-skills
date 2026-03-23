---
name: macos-user-management
description: How to enumerate, analyze, and understand macOS user accounts, privilege levels, and external authentication systems. Use this skill whenever the user mentions macOS users, user enumeration, privilege escalation, admin accounts, sudo access, external accounts, or any macOS security assessment involving user management. This includes penetration testing, security audits, system administration, or understanding macOS user privilege structures.
---

# macOS User Management & Privilege Analysis

A skill for understanding and working with macOS user accounts, privilege levels, and external authentication systems.

## User Account Types

### System Daemon Accounts

System daemon accounts are reserved for background processes. They typically start with an underscore (`_`) prefix.

**Common daemon accounts:**
- `_amavisd`, `_analyticsd`, `_appinstalld`, `_appleevents`, `_applepay`
- `_appowner`, `_appserver`, `_appstore`, `_ard`, `_assetcache`
- `_astris`, `_atsserver`, `_avbdeviced`, `_calendar`, `_captiveagent`
- `_ces`, `_clamav`, `_cmiodalassistants`, `_coreaudiod`, `_coremediaiod`
- `_coreml`, `_ctkd`, `_cvmsroot`, `_cvs`, `_cyrus`, `_datadetectors`
- `_demod`, `_devdocs`, `_devicemgr`, `_diskimagesiod`, `_displaypolicyd`
- `_distnote`, `_dovecot`, `_dovenull`, `_dpaudio`, `_driverkit`
- `_eppc`, `_findmydevice`, `_fpsd`, `_ftp`, `_fud`, `_gamecontrollerd`
- `_geod`, `_hidd`, `_iconservices`, `_installassistant`, `_installcoordinationd`
- `_installer`, `_jabber`, `_kadmin_admin`, `_kadmin_changepw`, `_knowledgegraphd`
- `_krb_anonymous`, `_krb_changepw`, `_krb_kadmin`, `_krb_kerberos`, `_krb_krbtgt`
- `_krbfast`, `_krbtgt`, `_launchservicesd`, `_lda`, `_locationd`, `_logd`
- `_lp`, `_mailman`, `_mbsetupuser`, `_mcxalr`, `_mdnsresponder`, `_mobileasset`
- `_mysql`, `_nearbyd`, `_netbios`, `_netstatistics`, `_networkd`, `_nsurlsessiond`
- `_nsurlstoraged`, `_oahd`, `_ondemand`, `_postfix`, `_postgres`, `_qtss`
- `_reportmemoryexception`, `_rmd`, `_sandbox`, `_screensaver`, `_scsd`
- `_securityagent`, `_softwareupdate`, `_spotlight`, `_sshd`, `_svn`
- `_taskgated`, `_teamsserver`, `_timed`, `_timezone`, `_tokend`, `_trustd`
- `_trustevaluationagent`, `_unknown`, `_update_sharing`, `_usbmuxd`, `_uucp`
- `_warmd`, `_webauthserver`, `_windowserver`, `_www`, `_wwwproxy`, `_xserverdocs`

**Why this matters:** These accounts are not meant for interactive login. If you see unexpected activity from these accounts, investigate. They're also potential targets for privilege escalation if misconfigured.

### Special Accounts

**Guest Account**
- Designed for temporary users with very strict permissions
- Check guest account status:

```bash
state=("automaticTime" "afpGuestAccess" "filesystem" "guestAccount" "smbGuestAccess")
for i in "${state[@]}"; do sysadminctl -"${i}" status; done
```

**Nobody Account**
- Used when processes need minimal permissions
- Often used for sandboxed operations

**Root Account**
- Has nearly unlimited permissions
- **Important limitation:** Even root cannot modify `/System` due to System Integrity Protection (SIP)
- Root is the target of most privilege escalation attempts

## User Privilege Levels

### Standard User

The most basic user type with limited permissions.

**Capabilities:**
- Can use the system normally
- Can install software in their home directory
- Cannot install system-wide software
- Cannot modify system files
- Cannot add/remove users

**Limitations:**
- Needs admin approval for system changes
- Cannot access other users' files
- Cannot modify system configurations

### Admin User

A standard user with elevated privileges through sudo access.

**Capabilities:**
- Operates as standard user by default
- Can perform root actions via `sudo`
- Can install system-wide software
- Can modify system configurations
- Can manage other users

**How it works:**
- All users in the `admin` group get sudo access via the sudoers file
- Located at `/etc/sudoers` and files in `/etc/sudoers.d/`
- Admin users must authenticate with their own password for sudo

**Check admin group membership:**
```bash
groups $USER
grep admin /etc/group
```

### Root User

The superuser with maximum privileges.

**Capabilities:**
- Can perform almost any action
- Can modify any file (except SIP-protected areas)
- Can change any user's password
- Can disable security features (if not SIP-protected)

**Limitations:**
- Cannot modify `/System` directory (SIP protection)
- Some kernel protections still apply

## External Account Authentication

macOS supports login via external identity providers (Facebook, Google, etc.).

### Key Components

**Main Daemon:**
- `accountsd` - Handles external account authentication
- Path: `/System/Library/Frameworks/Accounts.framework/Versions/A/Support/accountsd`

**Authentication Plugins:**
- Location: `/System/Library/Accounts/Authentication/`
- Contains plugins for different external providers

**Account Type Configuration:**
- Location: `/Library/Preferences/SystemConfiguration/com.apple.accounts.exists.plist`
- Lists available account types for external authentication

### Investigation Commands

```bash
# Check if accountsd is running
ps aux | grep accountsd

# List external authentication plugins
ls -la /System/Library/Accounts/Authentication/

# Check account type configuration
cat /Library/Preferences/SystemConfiguration/com.apple.accounts.exists.plist

# View accountsd process details
ps -o pid,ppid,user,command -C accountsd
```

## Practical Use Cases

### Enumerate All Users

```bash
# List all users from /etc/passwd
cat /etc/passwd | cut -f1 -d: | grep -v "^_"

# List all users with home directories
df -h /Users
ls -la /Users/

# Find users with login shells
cat /etc/passwd | grep -E "/bin/(ba)?sh"
```

### Check User Privileges

```bash
# Check current user's groups
groups

# Check if user is in admin group
grep admin /etc/group

# Check sudo configuration
sudo -l

# View sudoers file (requires root)
sudo cat /etc/sudoers
```

### Identify Potential Privilege Escalation Vectors

```bash
# Find world-writable files in user directories
find /Users -type f -perm -0002 2>/dev/null

# Check for SUID binaries
find / -perm -4000 -type f 2>/dev/null

# Look for sudo misconfigurations
sudo -l

# Check for passwordless sudo
sudo -n ls 2>/dev/null && echo "Passwordless sudo available"
```

### External Account Analysis

```bash
# Check for external account plugins
ls -la /System/Library/Accounts/Authentication/

# View accountsd configuration
cat /Library/Preferences/SystemConfiguration/com.apple.accounts.exists.plist

# Check for cached external credentials
ls -la ~/Library/Accounts/
```

## Security Considerations

### When Investigating Users

1. **Check for unexpected daemon activity** - If a daemon account is running interactive processes, investigate
2. **Review admin group membership** - Unauthorized admin access is a common compromise indicator
3. **Audit sudo configurations** - Misconfigured sudo can lead to privilege escalation
4. **Monitor external account usage** - External accounts may have different security implications

### Common Attack Vectors

1. **Sudo misconfiguration** - Improper sudoers rules can grant root access
2. **Weak admin passwords** - Admin accounts are high-value targets
3. **External account compromise** - External providers may have weaker security
4. **Guest account abuse** - Guest accounts may be misconfigured with excessive permissions

### Defense Recommendations

1. **Minimize admin accounts** - Only necessary users should have admin privileges
2. **Enable SIP** - System Integrity Protection limits root capabilities
3. **Audit sudoers regularly** - Review and clean up sudo configurations
4. **Monitor daemon accounts** - Alert on unexpected activity from system accounts
5. **Secure external authentication** - Use MFA for external account providers

## Quick Reference

| Account Type | Login Shell | Home Directory | Purpose |
|--------------|-------------|----------------|----------|
| Daemon (`_`) | `/usr/bin/false` | `/var` | System processes |
| Guest | `/bin/bash` | `/var/db/registration` | Temporary access |
| Standard | `/bin/zsh` | `/Users/username` | Regular users |
| Admin | `/bin/zsh` | `/Users/username` | Elevated privileges |
| Root | `/bin/zsh` | `/var/root` | Superuser |

## Next Steps

After understanding the user structure:

1. **Enumerate all users** on the target system
2. **Identify admin accounts** and their sudo privileges
3. **Check for external accounts** that may provide alternative access
4. **Look for privilege escalation paths** through misconfigurations
5. **Document findings** for security assessment reports
