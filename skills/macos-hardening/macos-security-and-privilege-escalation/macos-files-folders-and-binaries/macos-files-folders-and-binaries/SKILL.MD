---
name: macos-file-system-security
description: macOS file system, permissions, binaries, and security reference. Use this skill whenever the user asks about macOS file structures, directory layouts, file permissions, plist files, bundles, dyld shared cache, file flags, ACLs, extended attributes, resource forks, or any macOS security concepts. This includes questions about where to find configuration files, how to read plist files, understanding file permissions and flags, analyzing binaries, or investigating macOS security mechanisms. Make sure to use this skill for any macOS security research, pentesting, or system administration tasks involving files, permissions, or binaries.
---

# macOS File System & Security Reference

This skill provides comprehensive guidance on macOS file systems, permissions, binaries, and security mechanisms for security researchers, pentesters, and system administrators.

## File Hierarchy Layout

### Root Directory Structure

| Path | Purpose |
|------|--------|
| `/Applications` | Installed apps accessible to all users |
| `/bin` | Command line binaries |
| `/cores` | Core dumps (if exists) |
| `/dev` | Hardware devices (treated as files) |
| `/etc` | Configuration files |
| `/Library` | Preferences, caches, logs (root and per-user) |
| `/private` | Undocumented; many folders symlink here |
| `/sbin` | Essential system binaries (administration) |
| `/System` | OS X system files (Apple-specific) |
| `/tmp` | Temporary files (deleted after 3 days, symlink to `/private/tmp`) |
| `/Users` | User home directories |
| `/usr` | Config and system binaries |
| `/var` | Log files |
| `/Volumes` | Mounted drives |
| `/.vol` | Access files by volume/inode: `cat /.vol/<volume_id>/<inode>` |

### Applications Folders

- **System applications**: `/System/Applications`
- **Installed applications**: `/Applications` or `~/Applications`
- **Application data (root)**: `/Library/Application Support`
- **Application data (user)**: `~/Library/Application Support`
- **Privileged helper tools**: `/Library/PrivilegedHelperTools/` (root daemons)
- **Sandboxed apps**: `~/Library/Containers/` (named by bundle ID, e.g., `com.apple.Safari`)
- **Kernel**: `/System/Library/Kernels/kernel`
- **Apple kernel extensions**: `/System/Library/Extensions`
- **Third-party kernel extensions**: `/Library/Extensions`

## macOS-Specific File Extensions

| Extension | Description |
|-----------|-------------|
| `.dmg` | Apple Disk Image (common for installers) |
| `.kext` | Kernel extension bundle (driver) |
| `.plist` | Property list (XML or binary format) |
| `.app` | Application bundle (directory structure) |
| `.dylib` | Dynamic library (like Windows DLL) |
| `.pkg` | Installer package (XAR format) |
| `.DS_Store` | Directory attributes/customizations |
| `.Spotlight-V100` | Spotlight index folder (root of volumes) |
| `.metadata_never_index` | Prevents Spotlight indexing of volume |
| `.noindex` | Prevents Spotlight indexing of file/folder |
| `.sdef` | AppleScript interaction specification |

### Reading Plist Files

```bash
# Read binary plist
defaults read config.plist

# PlistBuddy
/usr/libexec/PlistBuddy -c print config.plist

# plutil (print as XML)
plutil -p ~/Library/Preferences/com.apple.screensaver.plist

# Convert to XML
plutil -convert xml1 ~/Library/Preferences/com.apple.screensaver.plist -o -

# Convert to JSON
plutil -convert json ~/Library/Preferences/com.apple.screensaver.plist -o -
```

## File Permissions & Flags

### Folder Permissions

- **Read**: List directory contents
- **Write**: Delete and create files
- **Execute**: Traverse directory

> Note: A user with read permission on a file inside a directory where they lack execute permission cannot read the file.

### File Flags

Check flags with: `ls -lO /path/directory`

| Flag | Description | Command |
|------|-------------|--------|
| `uchg` (uchange) | Prevents modification/deletion | `chflags uchg file.txt` |
| `restricted` | Protected by SIP (cannot be added manually) | - |
| `Sticky bit` | Only owner/root can rename/delete files (e.g., `/tmp`) | - |

### Complete Flag Reference

From `sys/stat.h`:

**Owner-settable flags (UF_SETTABLE 0x0000ffff):**
- `UF_NODUMP` (0x00000001): Do not dump file
- `UF_IMMUTABLE` (0x00000002): File may not be changed
- `UF_APPEND` (0x00000004): Writes may only append
- `UF_OPAQUE` (0x00000008): Directory opaque wrt union
- `UF_COMPRESSED` (0x00000020): File is compressed
- `UF_TRACKED` (0x00000040): No notifications for deletes/renames
- `UF_DATAVAULT` (0x00000080): Entitlement required for read/write
- `UF_HIDDEN` (0x00008000): Hint to hide from GUI

**Superuser flags (SF_SETTABLE 0x3fff0000):**
- `SF_ARCHIVED` (0x00010000): File is archived
- `SF_IMMUTABLE` (0x00020000): File may not be changed
- `SF_APPEND` (0x00040000): Writes may only append
- `SF_RESTRICTED` (0x00080000): Entitlement required for writing
- `SF_NOUNLINK` (0x00100000): Item may not be removed/renamed
- `SF_FIRMLINK` (0x00800000): File is a firmlink
- `SF_DATALESS` (0x40000000): File is dataless object

## File ACLs (Access Control Lists)

Files with ACLs show a `+` in permissions: `drwx------+`

### Directory ACEs
- `list`, `search`, `add_file`, `add_subdirectory`, `delete_child`

### File ACEs
- `read`, `write`, `append`, `execute`

### ACL Commands

```bash
# Read ACLs
ls -lde Movies

# Find all files with ACLs (slow)
ls -RAle / 2>/dev/null | grep -E -B1 "\d: "
```

## Extended Attributes

View with: `ls -@` or `xattr -l <file>`

### Common Extended Attributes

| Attribute | Purpose |
|-----------|--------|
| `com.apple.resourceFork` | Resource fork (Alternate Data Streams) |
| `com.apple.quarantine` | Gatekeeper quarantine mechanism |
| `metadata:*` | Various metadata (`_backup_excludeItem`, `kMD*`) |
| `com.apple.lastuseddate` | Last file use date |
| `com.apple.FinderInfo` | Finder information (color tags, etc.) |
| `com.apple.TextEncoding` | Text encoding for ASCII files |
| `com.apple.logd.metadata` | Used by logd in `/var/db/diagnostics` |
| `com.apple.genstore.*` | Generational storage metadata |
| `com.apple.rootless` | System Integrity Protection label |
| `com.apple.uuidb.boot-uuid` | Boot epoch UUID markings |
| `com.apple.decmpfs` | Transparent file compression |
| `com.apple.cprotect` | Per-file encryption data |
| `com.apple.installd.*` | Installer metadata (`installType`, `uniqueInstallID`) |

### Resource Forks (macOS ADS)

```bash
# Create resource fork
echo "Hello" > a.txt
echo "Hello Mac ADS" > a.txt/..namedfork/rsrc

# Read extended attributes
xattr -l a.txt

# Find files with resource forks
find / -type f -exec ls -ld {} \; 2>/dev/null | grep -E "[x\-]@ " | awk '{printf $9; printf "\n"}' | xargs -I {} xattr -lv {} | grep "com.apple.ResourceFork"
```

### decmpfs (Compressed Files)

Files with `com.apple.decmpfs` attribute:
- `ls -l` reports size of 0
- Data stored in extended attribute
- Decrypted in memory on access
- Flagged with `UF_COMPRESSED` (visible via `ls -lO`)

```bash
# Remove compressed flag (breaks decompression)
chflags nocompressed </path/to/file>

# Force decompress
afscexpand <file>
```

## Dyld Shared Library Cache (SLC)

All system shared libraries combined into a single file for performance.

### Locations

- **macOS**: `/System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/`
- **Older macOS**: `/System/Library/dyld/`
- **iOS**: `/System/Library/Caches/com.apple.dyld/`

### Extraction Tools

```bash
# dyld_shared_cache_util
dyld_shared_cache_util -extract ~/shared_cache/ /System/Volumes/Preboot/Cryptexes/OS/System/Library/dyld/dyld_shared_cache_arm64e

# dyldextractor
dyldex -l [dyld_shared_cache_path]  # List libraries
dyldex_all [dyld_shared_cache_path]  # Extract all
```

### Override SLCs

```bash
# Load custom shared library cache
DYLD_SHARED_REGION=private DYLD_SHARED_CACHE_DIR=</path/dir> DYLD_SHARED_CACHE_DONT_VALIDATE=1

# Avoid shared cache (use individual libraries)
DYLD_SHARED_CACHE_DIR=avoid
```

### SLC Mapping

- `shared_region_check_np`: Check if SLC mapped (returns address)
- `shared_region_map_and_slide_np`: Map the SLC
- All processes use the same copy (ASLR implications)

## Universal Binaries & Mach-O Format

Universal binaries support multiple architectures in one file. Use `lipo` to inspect:

```bash
# Show architectures
lipo -info binary

# Extract specific architecture
lipo -thin x86_64 -output binary_x86 binary
```

## Important Configuration Locations

| Path | Purpose | Security Considerations |
|------|---------|------------------------|
| `/System/Library/FeatureFlags/Domain/` | Feature flag plists | Tampering could enable hidden code paths |
| `/System/Library/CoreServices/systemVersion.plist` | OS version metadata | May trick apps into accepting unsupported versions |
| `/Library/Preferences/com.apple.*.plist` | System preferences | Writable prefs can inject settings |
| `/Library/LaunchDaemons/` | Background daemon plists | Malicious plist = persistence |
| `/Library/LaunchAgents/` | User agent plists | Persistence mechanism |
| `/etc/hosts` | Hostname ↔ IP mappings | Traffic interception/spoofing |
| `/etc/sudoers` | Sudo configuration | Corrupted file = privilege escalation |
| `/private/var/db/dslocal/nodes/Default/users/` | User account plists | Account creation/modification |
| `/System/Library/Extensions/` | Kernel extensions | Kernel-level control (SIP protected) |
| `/Library/Extensions/` | Third-party kexts | Kernel-level control |
| `/private/var/db/SystemPolicyConfiguration/` | Policy enforcement config | Circumvent Gatekeeper/notarization |
| `/etc/ssh/ssh_config` | SSH configuration | Weak SSH security |
| `/System/Library/Sandbox/Profiles` | Sandbox profiles (SBPL) | Sandbox escape vectors |

> **Note**: Many paths under `/System` are SIP-protected and require SIP bypass to modify.

## Log Files

| Path | Contents |
|------|--------|
| `$HOME/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2` | Downloaded files with URLs |
| `/var/log/system.log` | Main system log |
| `/private/var/log/asl/*.asl` | Apple System Logs |
| `$HOME/Library/Preferences/com.apple.recentitems.plist` | Recently accessed files/apps |
| `$HOME/Library/Preferences/com.apple.loginitems.plist` | Startup items |
| `$HOME/Library/Logs/DiskUtility.log` | Disk Utility logs (USB/drive info) |
| `/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist` | Wireless access point data |
| `/private/var/db/launchd.db/com.apple.launchd/overrides.plist` | Deactivated daemons |

## Risk Category Files

Location: `/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/System`

| Category | Behavior |
|----------|--------|
| `LSRiskCategorySafe` | Automatically opened after download |
| `LSRiskCategoryNeutral` | No warning, not auto-opened |
| `LSRiskCategoryUnsafeExecutable` | Warning: file is an application |
| `LSRiskCategoryMayContainUnsafeExecutable` | Warning for archives (unless verified safe) |

## Common Commands Reference

```bash
# Find stat.h for flag definitions
mdfind stat.h | grep stat.h

# Check if syslogd is running
launchctl list | grep "com.apple.syslogd"

# Read plist
plutil -p <file.plist> -o -

# List extended attributes
xattr -l <file>

# Remove extended attribute
xattr -d <attribute> <file>

# Set file flag
chflags uchg <file>

# Remove file flag
chflags nouchg <file>

# List ACLs
ls -lde <file>

# Find files with ACLs
ls -RAle / 2>/dev/null | grep -E -B1 "\d: "
```

## Security Considerations

1. **SIP (System Integrity Protection)**: Protects `/System` and other critical directories. Many operations require SIP bypass.

2. **Gatekeeper**: Uses `com.apple.quarantine` extended attribute to track downloaded files.

3. **Sandboxing**: Apps in `~/Library/Containers/` are sandboxed with restricted access.

4. **Kernel Extensions**: Require signature validation and SIP considerations.

5. **File Flags**: `uchg` and `restricted` flags can prevent modification even by root (in some cases).

6. **Shared Cache**: All processes share the same SLC copy, which has ASLR implications.

## When to Use This Skill

Use this skill when:
- Investigating macOS file systems for security research
- Understanding macOS permissions and ACLs
- Analyzing plist files and configuration
- Working with macOS binaries and Mach-O format
- Researching macOS security mechanisms (SIP, Gatekeeper, sandboxing)
- Finding sensitive configuration files
- Understanding extended attributes and resource forks
- Working with dyld shared cache
- Pentesting macOS systems
- System administration tasks involving macOS file structures
