---
name: php-security-audit
description: Audit PHP configurations for security vulnerabilities and hardening opportunities. Use this skill whenever you need to review PHP security settings, check for dangerous enabled functions, assess disable_functions configuration, verify extension_dir security, or harden PHP installations. Trigger this skill for any PHP security assessment, penetration testing (authorized), configuration review, or compliance audit.
---

# PHP Security Audit Skill

A skill for auditing PHP configurations and identifying security vulnerabilities.

## When to Use This Skill

Use this skill when:
- Reviewing PHP configurations for security issues
- Checking if dangerous functions are enabled
- Assessing `disable_functions` settings
- Verifying `extension_dir` security
- Auditing PHP installations for compliance
- Performing authorized penetration testing
- Hardening PHP environments

## Security Audit Checklist

### 1. Check Disabled Functions

Review the `disable_functions` directive to identify which dangerous functions are blocked:

```php
<?php
$disabled = ini_get('disable_functions');
echo "Disabled functions: " . ($disabled ?: 'none') . "\n";
?>
```

**Critical functions that should be disabled:**
- `exec`, `system`, `shell_exec`, `passthru` - Command execution
- `proc_open`, `popen` - Process control
- `eval` - Code execution
- `assert` - Can execute code
- `base64_decode` - Often used in payloads
- `file_get_contents`, `fopen` - File access
- `curl_exec`, `file_put_contents` - Remote file operations

### 2. Check for dl() Function

The `dl()` function can load PHP extensions dynamically and should be disabled:

```php
<?php
if (function_exists('dl')) {
    echo "WARNING: dl() function is enabled!\n";
    echo "This can be used to bypass disable_functions.\n";
} else {
    echo "dl() is properly disabled.\n";
}
?>
```

**Why dl() is dangerous:**
- Can load custom PHP extensions at runtime
- Extensions written in C/C++ can execute arbitrary code
- Can bypass `disable_functions` restrictions
- Requires matching PHP API version
- Extension must be in `extension_dir`

### 3. Check Extension Directory

Verify the `extension_dir` setting and its permissions:

```php
<?php
echo "Extension directory: " . ini_get('extension_dir') . "\n";
echo "Writable: " . (is_writable(ini_get('extension_dir')) ? 'YES - DANGEROUS' : 'No') . "\n";
?>
```

**Security requirements:**
- `extension_dir` should NOT be writable by web server
- Should only contain trusted extensions
- Should not be in web-accessible directories

### 4. Check PHP Version and API

```php
<?php
echo "PHP Version: " . PHP_VERSION . "\n";
echo "PHP API: " . PHP_API_VERSION . "\n";
echo "Zend Extension Build: " . phpversion('Zend') . "\n";
?>
```

### 5. Review php.ini Settings

**Critical security settings:**

| Setting | Recommended Value | Purpose |
|---------|------------------|---------|
| `disable_functions` | `exec,system,shell_exec,passthru,proc_open,popen,dl,eval` | Block dangerous functions |
| `open_basedir` | `/var/www/html` | Restrict file access |
| `allow_url_fopen` | `Off` | Prevent remote file inclusion |
| `allow_url_include` | `Off` | Prevent remote code execution |
| `display_errors` | `Off` | Hide error messages |
| `expose_php` | `Off` | Hide PHP version info |
| `upload_max_filesize` | `2M` | Limit upload size |
| `max_execution_time` | `30` | Prevent long-running scripts |
| `memory_limit` | `128M` | Limit memory usage |

## Audit Report Template

When auditing a PHP installation, produce a report in this format:

```
# PHP Security Audit Report

## Summary
- **PHP Version:** [version]
- **Overall Risk Level:** [Low/Medium/High/Critical]
- **Critical Issues Found:** [count]

## Critical Findings

### 1. [Issue Title]
- **Severity:** Critical/High/Medium/Low
- **Description:** [what's wrong]
- **Current Setting:** [current value]
- **Recommended Setting:** [what it should be]
- **Remediation:** [how to fix]

## Disabled Functions Analysis
- **Total Disabled:** [count]
- **Missing Critical Blocks:** [list]
- **dl() Status:** [enabled/disabled]

## Extension Security
- **Extension Directory:** [path]
- **Directory Writable:** [yes/no]
- **Extensions Loaded:** [list]

## Recommendations
1. [Priority 1 fix]
2. [Priority 2 fix]
3. [Priority 3 fix]
```

## Common Vulnerability Patterns

### Pattern 1: dl() Enabled with Writable extension_dir
**Risk:** Critical - Allows arbitrary code execution
**Check:**
```php
function_exists('dl') && is_writable(ini_get('extension_dir'))
```

### Pattern 2: Command Execution Functions Enabled
**Risk:** High - Allows remote code execution
**Check:**
```php
function_exists('exec') || function_exists('system') || function_exists('shell_exec')
```

### Pattern 3: open_basedir Not Set
**Risk:** Medium - Allows file system traversal
**Check:**
```php
ini_get('open_basedir') === ''
```

### Pattern 4: Error Display Enabled in Production
**Risk:** Medium - Information disclosure
**Check:**
```php
ini_get('display_errors') === '1'
```

## Hardening Recommendations

### Immediate Actions
1. **Disable dl()** - Add to `disable_functions`
2. **Set open_basedir** - Restrict to application directory
3. **Disable error display** - Set `display_errors = Off`
4. **Hide PHP version** - Set `expose_php = Off`

### Additional Hardening
1. **Limit file uploads** - Set appropriate size limits
2. **Disable URL includes** - Set `allow_url_include = Off`
3. **Set execution limits** - Prevent resource exhaustion
4. **Use latest PHP version** - Patch known vulnerabilities

## Testing Commands

### Check PHP Configuration
```bash
php -i | grep -E "(disable_functions|extension_dir|open_basedir)"
```

### List Enabled Functions
```bash
php -r "print_r(get_defined_functions()['internal']);" | grep -E "(exec|system|shell_exec|dl)"
```

### Check Extension Directory Permissions
```bash
ls -la $(php -r "echo ini_get('extension_dir');")
```

## References

- [PHP Security Checklist](https://www.php.net/manual/en/security.php)
- [PHP disable_functions](https://www.php.net/manual/en/ini.core.php#ini.disable-functions)
- [PHP dl() function](https://www.php.net/manual/en/function.dl.php)
- [OWASP PHP Security](https://owasp.org/www-project-php-security-cheat-sheet/)

## Notes

- Always test changes in a staging environment first
- Some applications may require certain functions to be enabled
- Document any exceptions to security recommendations
- Regular audits should be performed after PHP updates
- Consider using PHP security scanners for automated checks
