---
name: macos-xattr-acls
description: macOS extended attributes (xattr) and Access Control Lists (ACLs) for file security. Use this skill whenever working with macOS file permissions, security hardening, privilege escalation research, or when you need to understand/modify ACLs and extended attributes beyond standard chmod. Trigger for any macOS file permission tasks, security analysis, or when dealing with com.apple.* attributes.
---

# macOS Extended Attributes and ACLs

This skill covers macOS-specific file security mechanisms: extended attributes (xattr) and Access Control Lists (ACLs). These go beyond standard Unix permissions and are critical for macOS security analysis and hardening.

## When to Use This Skill

Use this skill when:
- Analyzing macOS file permissions and security
- Researching privilege escalation vectors on macOS
- Working with `com.apple.*` extended attributes
- Creating or analyzing protected files/directories
- Understanding AppleDouble format (._* files)
- Dealing with ACLs that deny permissions despite chmod

## Core Concepts

### Extended Attributes (xattr)

Extended attributes are metadata stored alongside file content. On macOS, they're commonly used for:
- ACL data (`com.apple.acl.text`)
- Resource forks
- Spotlight metadata
- Security entitlements

### Access Control Lists (ACLs)

ACLs provide fine-grained permission control beyond owner/group/other. They can:
- Deny specific permissions to users/groups
- Override standard chmod permissions
- Be stored as extended attributes

## Quick Reference Commands

### List Extended Attributes
```bash
xattr -l <filepath>
xattr -p <attr-name> <filepath>
```

### Set Extended Attributes
```bash
xattr -w <attr-name> <value> <filepath>
```

### Remove Extended Attributes
```bash
xattr -d <attr-name> <filepath>
xattr -c <filepath>  # Clear all
```

### Set ACLs
```bash
chmod +a "<acl-string>" <filepath>
chmod -a "<acl-string>" <filepath>  # Remove
```

### View ACLs
```bash
ls -le <filepath>
```

## Practical Examples

### Example 1: Create a Protected File with ACL Deny

This creates a file that denies write permissions to everyone:

```bash
# Create test file
echo "test" > /tmp/protected-file

# Add ACL denying write operations
chmod +a "everyone deny write,writeattr,writeextattr,writesecurity,chown" /tmp/protected-file

# Verify the ACL
ls -le /tmp/protected-file
```

### Example 2: Embed ACL in Extended Attribute

ACLs can be stored as extended attributes. This is useful for:
- Preserving permissions across transfers
- Creating self-documenting protected files
- Security research and testing

```bash
# Set an ACL on a directory
mkdir -p /tmp/protected-dir
chmod +a "everyone deny write,writeattr,writeextattr,writesecurity,chown" /tmp/protected-dir

# Read the ACL as extended attribute
xattr -p com.apple.acl.text /tmp/protected-dir 2>/dev/null || echo "No ACL xattr found"
```

### Example 3: AppleDouble Format for Preserving Attributes

AppleDouble format (._* files) preserves macOS metadata when archiving:

```bash
# Create directory with protected content
mkdir -p start/protected
echo "sensitive data" > start/protected/data.txt
chmod +a "everyone deny write" start/protected

# Archive with ditto (preserves xattrs)
ditto -c -k start protected.zip

# Extract and inspect
unzip protected.zip
ls -la  # See ._protected (AppleDouble resource fork)
```

### Example 4: Modify AppleDouble to Change Attribute Names

For security research, you can modify the attribute names in AppleDouble files:

```bash
# After extracting with ditto/unzip
python3 -c "
with open('._protected', 'rb+') as f:
    content = f.read()
    # Replace attribute name
    content = content.replace(b'com.apple.xxx.xxxx', b'com.apple.acl.text')
    f.seek(0)
    f.write(content)
    f.truncate()
"

# Re-package
zip -r protected.zip protected ._protected
```

## Using the Helper Scripts

### get_acls - Read ACLs in Text and Hex Format

```bash
# Compile
cc -o get_acls scripts/get_acls.c

# Usage
./get_acls <filepath>
```

This shows both human-readable ACL format and hex encoding, useful for understanding the raw ACL structure.

### set_xattr - Set Extended Attributes with ACL Data

```bash
# Compile
cc -o set_xattr scripts/set_xattr.c

# Usage
./set_xattr <filepath>
```

This sets a custom extended attribute containing ACL data and lists all current extended attributes on the file.

## Security Considerations

### ACL Precedence

ACLs can override standard Unix permissions. A deny ACL will block access even if chmod grants it.

### Extended Attribute Persistence

- xattrs are preserved with `ditto -c -k` (AppleDouble format)
- Standard `tar` may not preserve them
- `rsync -X` preserves extended attributes

### Common Attribute Names

- `com.apple.acl.text` - ACL data
- `com.apple.ResourceFork` - Resource fork data
- `com.apple.FinderInfo` - Finder metadata
- `com.apple.quarantine` - Gatekeeper quarantine info

## Troubleshooting

### ACL Not Taking Effect

```bash
# Check if ACLs are enabled on the filesystem
mount | grep -E "(acl|noacl)"

# View all permissions
ls -le <filepath>
```

### Extended Attributes Not Persisting

```bash
# Check filesystem supports xattrs
xattr -l /  # Should work on APFS/HFS+

# Verify after copy
xattr -l <copied-file>  # May be empty if copy method didn't preserve
```

## Related Skills

- macOS privilege escalation research
- File system forensics
- Security hardening and compliance
- AppleDouble and resource fork analysis
