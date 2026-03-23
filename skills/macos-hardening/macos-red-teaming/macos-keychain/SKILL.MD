---
name: macos-keychain
description: Analyze and enumerate macOS Keychain entries for security assessments. Use this skill whenever you need to inspect keychain contents, understand ACL permissions, extract credentials, or perform keychain security analysis on macOS systems. Make sure to use this skill when the user mentions keychain, macOS credentials, password extraction, ACL analysis, or any macOS security assessment involving stored secrets.
---

# macOS Keychain Analysis

A skill for analyzing macOS Keychain entries, understanding access controls, and performing security assessments.

## Keychain Locations

### User Keychain
- **Path**: `~/Library/Keychains/login.keychain-db`
- **Purpose**: User-specific credentials (app passwords, internet passwords, certificates, network passwords, public/private keys)

### System Keychain
- **Path**: `/Library/Keychains/System.keychain`
- **Purpose**: System-wide credentials (WiFi passwords, system root certificates, system private keys, system application passwords)
- **Additional**: Check `/System/Library/Keychains/*` for other components

### iOS Keychain
- **Path**: `/private/var/Keychains/`
- **Contents**: Keychain database, TrustStore, CA issuers cache, OCSP cache
- **Restriction**: Apps limited to their private area based on application identifier

## Understanding Keychain Protections

### Access Control Lists (ACLs)

Each keychain entry has ACLs that control access. These define which applications can read, modify, or delete entries without user interaction.

**Authorization Types:**
- `ACLAuhtorizationExportClear` - Allows retrieving plaintext secrets
- `ACLAuhtorizationExportWrapped` - Allows encrypted export with custom password
- `ACLAuhtorizationAny` - Grants unrestricted access

**Trusted Application Lists:**
- `nil` - No authorization required (everyone trusted)
- Empty list - Nobody trusted
- Specific list - Only listed applications trusted

**PartitionID Requirements:**
- `teamid` - Application must have matching team ID
- `apple` - Application must be signed by Apple
- `cdhash` - Application must have specific code hash

### Entry Creation Rules

**Via Keychain Access.app:**
- All apps can encrypt
- No apps can export/decrypt without prompting
- All apps can see integrity check
- No apps can change ACLs
- PartitionID set to `apple`

**Via Application:**
- All apps can encrypt
- Only creating app (or explicitly added apps) can export/decrypt without prompting
- All apps can see integrity check
- No apps can change ACLs
- PartitionID set to `teamid:[teamID]`

## Accessing the Keychain

### Using the `security` Command

```bash
# List all keychains
security list-keychains

# Dump all metadata and decrypted secrets (generates pop-ups)
security dump-keychain -a -d

# Find generic password for specific account and print secrets
security find-generic-password -a "AccountName" -g

# Change entry's PartitionID
security set-generic-password-partition-list -s "service" -a "account" -S

# Dump specific keychain file
security dump-keychain ~/Library/Keychains/login.keychain-db
```

### Using Security Framework APIs

**SecItemCopyMatching** - Retrieve entry information with attributes:
- `kSecReturnData` - Decrypt data (set false to avoid pop-ups)
- `kSecReturnRef` - Get keychain item reference
- `kSecReturnAttributes` - Get metadata
- `kSecMatchLimit` - Number of results to return
- `kSecClass` - Entry type (generic, internet, certificate, key, etc.)

**SecAccessCopyACLList** - Get ACLs for keychain items:
- Returns authorization types and trusted application lists
- Trusted apps can be: application paths, binaries, or groups

**Export APIs:**
- `SecKeychainItemCopyContent` - Get plaintext
- `SecItemExport` - Export keys/certificates (may require password for encryption)

### Export Requirements (No Prompt)

**If 1+ trusted apps listed:**
- Need appropriate authorizations (nil or in allowed list)
- Code signature must match PartitionID
- Code signature must match trusted app (or be in KeychainAccessGroup)

**If all applications trusted:**
- Need appropriate authorizations
- Code signature must match PartitionID (not needed if no PartitionID)

## Important Considerations

### Code Injection Scenarios
- If only 1 application is listed as trusted, you need to inject code into that application
- If `apple` is in the partitionID, you can access it with `osascript` or Python

### Special Attributes
- **Invisible** - Boolean flag to hide entry from Keychain UI
- **General** - Stores metadata (NOT ENCRYPTED)
  - Example: Microsoft stored refresh tokens in plaintext here

## Tools

- **Chainbreaker** - Decrypt keychain files with user password
- **LockSmith** - Enumerate and dump secrets without generating prompts
- **SecKeyChain.h** - Apple's open source API reference

## References

- [OBTS v5.0: "Lock Picking the macOS Keychain" - Cody Thomas](https://www.youtube.com/watch?v=jKE1ZW33JpY)
- [LockSmith](https://github.com/its-a-feature/LockSmith)
- [Chainbreaker](https://github.com/n0fate/chainbreaker)
- [SecKeyChain.h](https://opensource.apple.com/source/libsecurity_keychain/libsecurity_keychain-55017/lib/SecKeychain.h.auto.html)
- [security.c](https://opensource.apple.com/source/Security/Security-59306.61.1/SecurityTool/macOS/security.c.auto.html)
