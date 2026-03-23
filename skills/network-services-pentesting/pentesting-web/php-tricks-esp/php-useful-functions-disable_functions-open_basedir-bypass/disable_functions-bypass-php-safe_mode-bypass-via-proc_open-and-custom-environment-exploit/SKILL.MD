---
name: php-bypass-techniques
description: Security research skill for understanding and documenting PHP function bypass techniques including disable_functions, safe_mode, and open_basedir restrictions. Use this skill when users ask about PHP security testing, penetration testing PHP applications, researching PHP vulnerabilities, documenting bypass methods for authorized security assessments, or analyzing PHP configuration weaknesses. Trigger on mentions of PHP security, disabled functions, safe_mode bypass, proc_open exploitation, LD_PRELOAD attacks, or PHP pentesting.
---

# PHP Bypass Techniques Research Skill

## Purpose

This skill helps security professionals understand, document, and analyze PHP bypass techniques for **authorized penetration testing and security research only**. It covers methods to bypass PHP restrictions like `disable_functions`, `safe_mode`, and `open_basedir`.

## ⚠️ Legal and Ethical Requirements

**Before using any technique from this skill:**

1. **Written authorization** - You must have explicit written permission from the system owner
2. **Scope definition** - Know exactly which systems you're authorized to test
3. **Legal compliance** - Ensure your testing complies with local laws (CFAA, Computer Misuse Act, etc.)
4. **Responsible disclosure** - Report findings to the appropriate parties
5. **No production abuse** - Never use these techniques on systems you don't own or have permission to test

**Unauthorized use of these techniques is illegal and can result in criminal charges.**

## Core Technique: proc_open with LD_PRELOAD

### Overview

When PHP has `disable_functions` enabled (blocking functions like `system()`, `exec()`, `shell_exec()`), attackers may bypass restrictions using `proc_open()` with custom environment variables to load malicious shared libraries.

### How It Works

1. **proc_open()** is often not disabled even when other execution functions are
2. **LD_PRELOAD** environment variable can force the dynamic linker to load a custom shared library before any other
3. **Custom .so file** can contain code that executes arbitrary commands
4. **File descriptors** redirect output to readable files

### Technical Details

```php
// Basic structure of the bypass
$descriptorspec = array(
    0 => array("pipe", "r"),           // stdin
    1 => array("file", "output.txt", "w"),  // stdout
    2 => array("file", "errors.txt", "a")   // stderr
);

$cwd = '.';
$env = array('LD_PRELOAD' => '/path/to/malicious.so');

$process = proc_open('id', $descriptorspec, $pipes, $cwd, $env);
```

### Key Components

| Component | Purpose |
|-----------|--------|
| `descriptorspec` | Defines input/output streams for the process |
| `LD_PRELOAD` | Environment variable that loads custom shared library |
| `.so file` | Compiled shared object containing exploit code |
| `proc_open()` | PHP function that spawns the process with custom environment |

## When This Technique Applies

### Conditions Required

1. **proc_open() is NOT disabled** - Check with `function_exists('proc_open')`
2. **Write access** - You can write files to the server filesystem
3. **Compilation capability** - You can compile a .so file (or upload pre-compiled)
4. **Linux system** - LD_PRELOAD works on Linux (not Windows/macOS)
5. **Dynamic linking** - PHP is compiled with dynamic linking support

### Detection Methods

```php
// Check if proc_open is available
if (function_exists('proc_open')) {
    echo "proc_open is available";
}

// Check disabled functions
$disabled = ini_get('disable_functions');
echo "Disabled: " . $disabled;

// Check safe_mode (deprecated in PHP 5.4, removed in 7.0)
$safe_mode = ini_get('safe_mode');
echo "Safe mode: " . ($safe_mode ? 'enabled' : 'disabled');
```

## Related Bypass Techniques

### 1. open_basedir Bypass

When `open_basedir` restricts file access:

- **Symlink attacks** - Create symlinks to restricted directories
- **Phar stream wrapper** - Use `phar://` to read files
- **Zip stream wrapper** - Use `zip://` for archive access
- **Filter wrappers** - Use `php://filter` for encoding/decoding

### 2. Alternative Execution Methods

If `proc_open()` is also disabled:

- **popen()** - May still be available
- **pcntl_exec()** - Process control extension
- **curl_file_get_contents()** - With custom protocols
- **mail()** - With crafted parameters
- **fsockopen()** - Network-based command execution

## Documentation Template

When documenting findings in a security report:

```markdown
## Finding: PHP Function Bypass via proc_open

### Severity: High

### Description
PHP configuration allows command execution through proc_open() with LD_PRELOAD
environment variable manipulation, bypassing disable_functions restrictions.

### Technical Details
- Affected function: proc_open()
- Bypass method: LD_PRELOAD shared library injection
- Required conditions: Write access, Linux system, dynamic linking

### Proof of Concept
[Include sanitized code example]

### Impact
- Arbitrary command execution
- Full system compromise possible
- Data exfiltration capability

### Remediation
1. Disable proc_open() in disable_functions
2. Use PHP-FPM with proper user isolation
3. Implement chroot jails
4. Keep PHP updated (safe_mode removed in 7.0)
5. Use modern PHP security extensions

### References
- [Original research](http://blog.safebuff.com/2016/05/06/disable-functions-bypass/)
- PHP Security Checklist
- OWASP PHP Security Cheat Sheet
```

## Testing Workflow

### Step 1: Reconnaissance

```bash
# Check PHP version
php -v

# Check disabled functions
php -r "echo ini_get('disable_functions');"

# Check open_basedir
php -r "echo ini_get('open_basedir');"
```

### Step 2: Capability Testing

```php
<?php
// Test proc_open availability
if (function_exists('proc_open')) {
    echo "proc_open: AVAILABLE\n";
} else {
    echo "proc_open: DISABLED\n";
}

// Test file write capability
$test_file = '/tmp/test_write_' . uniqid();
if (file_put_contents($test_file, 'test')) {
    echo "File write: AVAILABLE\n";
    unlink($test_file);
} else {
    echo "File write: RESTRICTED\n";
}
?>
```

### Step 3: Documentation

Document all findings with:
- System configuration
- Available bypass vectors
- Proof of concept (sanitized)
- Remediation recommendations

## Security Recommendations

### For System Administrators

1. **Disable dangerous functions** - Include `proc_open`, `popen`, `system`, `exec`, `shell_exec`
2. **Use PHP-FPM** - Run PHP with proper user isolation
3. **Implement chroot** - Restrict filesystem access
4. **Keep updated** - PHP 7.0+ removed safe_mode (use modern alternatives)
5. **Use security extensions** - Consider ModSecurity, RIPS, or similar

### For Developers

1. **Never trust user input** - Validate and sanitize all inputs
2. **Use prepared statements** - Prevent SQL injection
3. **Implement proper error handling** - Don't expose stack traces
4. **Follow principle of least privilege** - Run with minimal permissions
5. **Regular security audits** - Use static analysis tools

## References

- [Original Safebuff Research](http://blog.safebuff.com/2016/05/06/disable-functions-bypass/)
- [PHP Security Checklist](https://github.com/mikeerickson/php-security-checklist)
- [OWASP PHP Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/PHP_Configuration_Cheat_Sheet.html)
- [HackTricks PHP Pentesting](https://book.hacktricks.xyz/pentesting-web/php-tricks)

## Disclaimer

This skill is for **educational and authorized security testing purposes only**. The author and Anthropic are not responsible for misuse of this information. Always obtain proper authorization before testing any system.
