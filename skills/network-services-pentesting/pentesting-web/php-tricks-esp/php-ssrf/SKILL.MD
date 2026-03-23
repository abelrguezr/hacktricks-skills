---
name: php-ssrf-testing
description: How to identify and test for PHP Server-Side Request Forgery (SSRF) vulnerabilities. Use this skill whenever the user mentions PHP, SSRF, server-side request forgery, file_get_contents, WordPress remote functions, CRLF injection, or needs to test for vulnerabilities in PHP applications that make HTTP requests. Make sure to use this skill when analyzing PHP code for security issues, reviewing WordPress plugins/themes, or testing web applications for SSRF attack vectors.
---

# PHP SSRF Testing

This skill helps you identify and test for Server-Side Request Forgery vulnerabilities in PHP applications.

## Understanding PHP SSRF

SSRF occurs when a server-side application accepts user-controlled URLs and makes HTTP requests to them. In PHP, several built-in functions accept URLs as input, creating potential SSRF attack vectors when user input isn't properly validated.

## Vulnerable PHP Functions

These PHP functions accept URLs and can lead to SSRF if user input is not sanitized:

- `file_get_contents()`
- `fopen()`
- `file()`
- `md5_file()`

### Example Vulnerable Code

```php
// Vulnerable - user controls the URL
$url = $_GET['url'];
file_get_contents($url);

// Also vulnerable
fopen($url, "r");
file($url);
md5_file($url);
```

### Testing for SSRF

When you identify these functions in code, test with these payloads:

```php
// Test internal network access
file_get_contents("http://127.0.0.1:8081");
file_get_contents("http://localhost:8081");
file_get_contents("http://169.254.169.254/latest/meta-data/"); // AWS metadata

// Test file protocol
file_get_contents("file:///etc/passwd");
file_get_contents("php://filter/convert.base64-encode/resource=/etc/passwd");
```

## WordPress SSRF Vulnerabilities

WordPress has several functions vulnerable to SSRF, particularly through DNS rebinding attacks. Even `wp_safe_remote_get()` can be bypassed.

### Vulnerable WordPress Functions

- `wp_safe_remote_get()`
- `wp_safe_remote_request()`
- `wp_safe_remote_post()`
- `wp_safe_remote_head()`
- `WP_REST_URL_Details_Controller::get_remote_url()`
- `download_url()`
- `wp_remote_fopen()`
- `WP_oEmbed::discover()`

### WordPress Validation Bypass

WordPress validates URLs through `wp_http_validate_url()`, which checks:
- Protocol is `http://` or `https://`
- Port is 80, 443, or 8080

However, this validation is **vulnerable to DNS rebinding** - an attacker can control the DNS response timing to bypass IP validation.

### Testing WordPress SSRF

```php
// DNS rebinding attack - set up DNS to return different IPs
// First request: returns public IP (passes validation)
// Second request: returns internal IP (bypasses validation)

wp_safe_remote_get("http://attacker-controlled-domain.com");
```

## CRLF Injection in PHP

PHP's HTTP functions can be exploited for CRLF injection through `ini_set()` or stream contexts.

### Method 1: Using ini_set()

```php
// Inject arbitrary headers via ini_set
ini_set("from", "Hi\r\nInjected: I HAVE IT");
file_get_contents("http://127.0.0.1:8081");

// This sends:
// GET / HTTP/1.1
// From: Hi
// Injected: I HAVE IT
// Host: 127.0.0.1:8081
// Connection: close
```

### Method 2: Using Stream Context

```php
$url = "http://target.com";

$options = array(
  'http' => array(
    'method' => "GET",
    'header' => "Accept-language: en\r\n" .
                "Cookie: foo=bar\r\n" .
                "User-Agent: Custom-Agent\r\n"
  )
);

$context = stream_context_create($options);
$file = file_get_contents($url, false, $context);
```

## Testing Checklist

When testing for PHP SSRF:

1. **Identify vulnerable functions** - Search for `file_get_contents`, `fopen`, `file`, `md5_file` with URL parameters
2. **Check input validation** - Verify if user input is properly sanitized before use
3. **Test internal access** - Try accessing `127.0.0.1`, `localhost`, `169.254.169.254` (AWS)
4. **Test protocol handlers** - Try `file://`, `php://`, `data://` protocols
5. **Test WordPress functions** - If WordPress, test the vulnerable functions listed above
6. **Test CRLF injection** - Try injecting headers via `ini_set()` or stream contexts
7. **Test DNS rebinding** - For WordPress, set up DNS rebinding to bypass IP validation

## Mitigation Strategies

- **Whitelist allowed URLs** - Only allow specific domains/URLs
- **Block private IP ranges** - Reject requests to `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`
- **Disable dangerous protocols** - Set `disable_functions` in php.ini
- **Use allowlists for protocols** - Only allow `http://` and `https://`
- **Validate and sanitize input** - Never trust user-supplied URLs
- **Use security libraries** - Consider using well-maintained HTTP client libraries with built-in SSRF protection

## References

- [PHP SSRF Bug Report](https://bugs.php.net/bug.php?id=81680)
- [WordPress SSRF via DNS Rebinding](https://patchstack.com/articles/exploring-the-unpatched-wordpress-ssrf)
- [PHP stream_context_create Documentation](https://php.net/manual/en/function.stream-context-create.php)
