---
name: macos-authorization-audit
description: Audit and analyze macOS authorization database and authd daemon for security assessments. Use this skill whenever you need to examine macOS privilege escalation vectors, check authorization rules in /var/db/auth.db, understand authd behavior, or test Security.framework APIs. Trigger this skill for any macOS security audit involving authorization rights, privilege checks, or when investigating how macOS controls sensitive operations through the authorization system.
---

# macOS Authorization Audit Skill

This skill helps you audit and analyze macOS authorization systems, including the authorization database (`/var/db/auth.db`) and the `authd` daemon that enforces privilege checks.

## What This Skill Does

- Query and analyze authorization rules in the macOS authorization database
- Understand authorization rule structure and semantics
- Test authorization rights using the `security` command
- Identify potential privilege escalation vectors
- Document authorization configurations for security assessments

## Authorization Database Overview

The authorization database at `/var/db/auth.db` stores permissions for sensitive operations performed in user space, typically by XPC services that need to verify if a calling client is authorized.

### Database Structure

The `rules` table contains authorization rules with these key columns:

| Column | Description |
|--------|-------------|
| `name` | Unique identifier for the rule |
| `type` | Rule type (1 or 2) defining authorization logic |
| `class` | Rule category: `allow`, `deny`, `user`, `rule`, or `evaluate-mechanisms` |
| `group` | User group for group-based authorization |
| `kofn` | K-of-N parameter for subrule satisfaction |
| `timeout` | Duration in seconds before authorization expires |
| `flags` | Behavior modification flags |
| `tries` | Maximum allowed authorization attempts |
| `requirement` | Serialized authorization requirements |
| `comment` | Human-readable description |

### Common Authorization Classes

- **allow**: Grants permission unconditionally
- **deny**: Denies permission unconditionally  
- **user**: Requires user authentication (with optional group membership)
- **rule**: Array of subrules that must be satisfied
- **evaluate-mechanisms**: Uses built-in mechanisms or SecurityAgentPlugins

## Core Commands

### Query the Authorization Database

```bash
# List all rules with names and comments
sudo sqlite3 /var/db/auth.db "SELECT name, comment FROM rules"

# Get specific rule details
security authorizationdb read <rule-name>

# Example: Check TCC admin modification rights
security authorizationdb read com.apple.tcc.util.admin
```

### Test Authorization Execution

```bash
# Test AuthorizationExecuteWithPrivileges API
security execute-with-privileges <command>

# Example: Run ls as root (will prompt for admin password)
security execute-with-privileges /bin/ls
```

### Inspect Authd Logs

```bash
# View authd daemon logs
sudo cat /var/log/authd.log

# Follow logs in real-time
sudo tail -f /var/log/authd.log
```

## Common Authorization Rights

### Admin Authentication Rights

| Right Name | Purpose | Key Properties |
|------------|---------|----------------|
| `authenticate-admin-nonshared` | Authenticate as administrator | `group: admin`, `shared: false`, `timeout: 30` |
| `authenticate-admin` | Shared admin authentication | `group: admin`, `shared: true` |
| `system.privilege.admin` | Admin privilege access | Requires admin authentication |

### System Modification Rights

| Right Name | Purpose |
|------------|----------|
| `com.apple.tcc.util.admin` | Modify TCC (privacy) settings |
| `system.privilege.install` | Install software |
| `system.privilege.network` | Network configuration |
| `system.privilege.security` | Security settings modification |

## Audit Workflow

### Step 1: Enumerate Authorization Rules

```bash
# Get complete rule inventory
sudo sqlite3 /var/db/auth.db "SELECT name, class, comment FROM rules ORDER BY name"

# Export to file for analysis
sudo sqlite3 -header -csv /var/db/auth.db "SELECT * FROM rules" > auth_rules.csv
```

### Step 2: Analyze High-Value Rules

Focus on rules that:
- Grant admin privileges (`authenticate-admin*`)
- Allow system modifications (`system.privilege.*`)
- Have `class: allow` (unconditional access)
- Have long timeouts or high `tries` values

```bash
# Find rules with allow class
sudo sqlite3 /var/db/auth.db "SELECT name, comment FROM rules WHERE class='allow'"

# Find rules with high timeout values
sudo sqlite3 /var/db/auth.db "SELECT name, timeout, comment FROM rules WHERE timeout > 300"
```

### Step 3: Test Authorization Paths

```bash
# Test if a command can be executed with privileges
security execute-with-privileges /bin/ls -la /var/db

# Check specific authorization right
security authorizationdb read system.privilege.admin
```

### Step 4: Document Findings

Create a structured report:

```
## Authorization Audit Findings

### High-Risk Rules
- [Rule Name]: [Comment] - [Risk Assessment]

### Unconditional Allow Rules
- [Rule Name]: Grants access without authentication

### Long Timeout Rules
- [Rule Name]: Timeout of [X] seconds

### Recommendations
- [Specific remediation steps]
```

## Security Considerations

### Privilege Escalation Vectors

1. **Weak Authorization Rules**: Rules with `class: allow` grant access without authentication
2. **Excessive Timeouts**: Long timeout values extend privilege windows
3. **High Tries Values**: Large `tries` values enable brute-force attempts
4. **Group-Based Access**: Rules using `group: admin` depend on group membership integrity

### Defense Recommendations

- Audit authorization rules regularly
- Remove or restrict unnecessary `allow` class rules
- Set appropriate timeout values (30-60 seconds typical)
- Limit `tries` to prevent brute-force attacks
- Monitor `/var/log/authd.log` for suspicious activity

## Reference Files

- `/var/db/auth.db` - Authorization database
- `/System/Library/Security/authorization.plist` - Initial authorization configuration
- `/var/log/authd.log` - Authd daemon logs
- `/System/Library/CoreServices/SecurityAgentPlugins/` - Built-in authentication mechanisms
- `/Library/Security/SecurityAgentPlugins/` - Custom authentication plugins

## Example Analysis

### TCC Admin Modification Rule

```xml
<dict>
    <key>class</key>
    <string>rule</string>
    <key>comment</key>
    <string>For modification of TCC settings.</string>
    <key>rule</key>
    <array>
        <string>authenticate-admin-nonshared</string>
    </array>
</dict>
```

**Analysis**: This rule requires admin authentication to modify TCC (privacy) settings. The `authenticate-admin-nonshared` subrule means:
- User must be in `admin` group
- Authentication is not shared across sessions
- 30-second timeout
- 10000 allowed attempts

### Security Implications

- TCC controls privacy permissions (camera, mic, screen recording, etc.)
- Admin authentication is required, which is appropriate
- High `tries` value (10000) could allow brute-force if password is weak
- Non-shared authentication limits session reuse attacks

## Tools and Scripts

Use the bundled `query-auth-db.sh` script for common authorization database queries:

```bash
# Run the query script
./scripts/query-auth-db.sh

# Query specific rule
./scripts/query-auth-db.sh --rule "authenticate-admin-nonshared"

# Export all rules to CSV
./scripts/query-auth-db.sh --export auth_rules.csv
```

## When to Use This Skill

Use this skill when:
- Conducting macOS security assessments
- Investigating privilege escalation paths
- Auditing system authorization configurations
- Understanding how macOS controls sensitive operations
- Testing authorization enforcement mechanisms
- Documenting macOS security posture
- Preparing for compliance audits (SOC2, ISO27001, etc.)

## Limitations

- Requires root/sudo access to query the authorization database
- Some authorization rights may be system-protected and cannot be modified
- Authd behavior may vary across macOS versions
- SecurityAgentPlugins may have version-specific implementations
