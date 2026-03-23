---
name: macos-file-extension-apps
description: macOS security skill for enumerating file extension handlers and URL scheme handlers via LaunchServices database. Use this skill whenever analyzing macOS systems for privilege escalation, investigating default app handlers, auditing file associations, or researching application capabilities. Trigger when users mention file extensions, URL schemes, LaunchServices, default apps, or macOS application handlers.
---

# macOS File Extension & URL Scheme App Handlers

A security skill for enumerating and analyzing macOS LaunchServices database to discover file extension handlers, URL scheme handlers, and application capabilities.

## Overview

macOS maintains a LaunchServices database that tracks all installed applications and their capabilities. This database can be queried to discover:
- Which applications handle specific file extensions
- Which applications register URL schemes
- Application MIME type associations
- Default handler configurations

This information is valuable for:
- **Privilege escalation research** - Finding misconfigured handlers
- **Security auditing** - Understanding application attack surface
- **Forensics** - Identifying installed applications and their capabilities
- **Malware analysis** - Understanding persistence mechanisms

## Quick Start

```bash
# Dump the entire LaunchServices database
lsregister -dump

# Find handlers for a specific extension
lsregister -dump | grep -E "path:|bindings:|name:" | grep -A5 "\.pdf"

# Use the bundled script for structured output
./scripts/query-handlers.sh --extension "pdf"
```

## Core Commands

### Dump LaunchServices Database

```bash
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump
```

This outputs the complete database with all application bindings, UTIs, and URL schemes.

### Find File Extension Handlers

```bash
# Find all handlers for a specific extension
lsregister -dump | grep -E "path:|bindings:|name:" | grep -B2 -A5 "\.ext"

# List all unique extensions registered
lsregister -dump | grep "string" | grep -oE "\.[a-zA-Z0-9]+" | sort -u
```

### Find URL Scheme Handlers

```bash
# Find handlers for a specific URL scheme
lsregister -dump | grep -E "path:|bindings:|name:" | grep -B2 -A5 "ftp://"

# List all URL schemes
lsregister -dump | grep "LSHandlerRank" | grep -B10 "URL" | grep "string"
```

### Check Application Capabilities

```bash
# Check what extensions an app handles
cd /Applications/Safari.app/Contents
grep -A3 CFBundleTypeExtensions Info.plist | grep string

# Check URL schemes an app registers
cd /Applications/Safari.app/Contents
grep -A3 CFBundleURLSchemes Info.plist | grep string
```

## Bundled Scripts

### query-handlers.sh

Query file extension and URL scheme handlers with structured output.

```bash
# Find handlers for a file extension
./scripts/query-handlers.sh --extension "pdf"

# Find handlers for a URL scheme
./scripts/query-handlers.sh --scheme "ftp"

# List all registered extensions
./scripts/query-handlers.sh --list-extensions

# List all registered URL schemes
./scripts/query-handlers.sh --list-schemes
```

### analyze-app.sh

Analyze a specific application's file and URL handler capabilities.

```bash
# Analyze Safari's capabilities
./scripts/analyze-app.sh /Applications/Safari.app

# Analyze with verbose output
./scripts/analyze-app.sh /Applications/Chrome.app --verbose
```

### dump-launchservices.sh

Dump and parse the LaunchServices database into structured JSON.

```bash
# Full dump to JSON
./scripts/dump-launchservices.sh --output ls-dump.json

# Dump with filtering
./scripts/dump-launchservices.sh --filter "pdf" --output pdf-handlers.json
```

## LaunchServices Architecture

### Key Components

| Component | Path | Purpose |
|-----------|------|--------|
| `lsregister` | `/System/Library/Frameworks/CoreServices.framework/.../Support/lsregister` | Database registration and dumping |
| `lsd` | `/usr/libexec/lsd` | LaunchServices daemon (XPC services) |
| `launchservicesd` | `/System/Library/CoreServices/launchservicesd` | Running application queries |
| `lsappinfo` | `/usr/bin/lsappinfo` | Query running applications |

### XPC Services

The `lsd` daemon exposes several XPC services:
- `.lsd.installation` - Application installation
- `.lsd.open` - Open files with handlers
- `.lsd.openurl` - Open URLs with handlers
- `.launchservices.changedefaulthandler` - Change default handlers (requires entitlements)
- `.launchservices.changeurlschemehandler` - Change URL scheme handlers (requires entitlements)

**Note:** Modifying handlers requires specific entitlements and elevated privileges.

## Security Considerations

### Privilege Escalation Vectors

1. **Misconfigured Handlers** - Applications with excessive file type associations may be exploited
2. **URL Scheme Handlers** - Custom URL schemes can be used for privilege escalation
3. **Default Handler Changes** - Modifying default handlers can redirect file operations
4. **Entitlement Abuse** - Applications with LaunchServices entitlements have elevated capabilities

### Auditing Checklist

- [ ] Review all file extension handlers for sensitive types (`.key`, `.pem`, `.config`)
- [ ] Check URL scheme handlers for custom schemes
- [ ] Identify applications with LaunchServices entitlements
- [ ] Verify default handlers for critical file types
- [ ] Look for unexpected or suspicious handler registrations

## Example Workflows

### Find All PDF Handlers

```bash
./scripts/query-handlers.sh --extension "pdf"
```

### Audit All Custom URL Schemes

```bash
./scripts/dump-launchservices.sh --output all-schemes.json
./scripts/query-handlers.sh --list-schemes | grep -v "http\|https\|ftp\|mailto"
```

### Compare Handler Changes Over Time

```bash
# Baseline
./scripts/dump-launchservices.sh --output baseline.json

# After changes
./scripts/dump-launchservices.sh --output after-changes.json

# Compare
./scripts/compare-dumps.sh baseline.json after-changes.json
```

## Tools

### External Tools

- **lsdtrip** - [https://newosxbook.com/tools/lsdtrip.html](https://newosxbook.com/tools/lsdtrip.html)
- **SwiftDefaultApps** - [https://github.com/Lord-Kamina/SwiftDefaultApps](https://github.com/Lord-Kamina/SwiftDefaultApps)

### SwiftDefaultApps Commands

```bash
./swda getSchemes    # Get all available schemes
./swda getApps       # Get all apps declared
./swda getUTIs       # Get all UTIs
./swda getHandler --URL ftp  # Get ftp handler
```

## Output Formats

### JSON Output

Scripts output structured JSON for programmatic analysis:

```json
{
  "extension": "pdf",
  "handlers": [
    {
      "name": "Preview",
      "path": "/System/Applications/Preview.app",
      "bundle_id": "com.apple.preview"
    }
  ]
}
```

### Text Output

Human-readable format for quick inspection:

```
Extension: .pdf
Handlers:
  - Preview (/System/Applications/Preview.app)
  - Adobe Acrobat (/Applications/Adobe Acrobat DC/Adobe Acrobat.app)
```

## Troubleshooting

### Permission Denied

```bash
# Some queries may require elevated privileges
sudo lsregister -dump
```

### No Results

- Verify the extension/scheme exists in the system
- Check if the application is properly installed
- Ensure LaunchServices database is not corrupted

### Database Corruption

```bash
# Rebuild LaunchServices database
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -kill -r -domain local -domain system -domain user
```

## References

- [lsdtrip Tool](https://newosxbook.com/tools/lsdtrip.html)
- [SwiftDefaultApps](https://github.com/Lord-Kamina/SwiftDefaultApps)
- [macOS LaunchServices Documentation](https://developer.apple.com/documentation/coreservices/launchservices)
