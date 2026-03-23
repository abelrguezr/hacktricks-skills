---
name: artifactory-pentesting
description: Security testing and vulnerability assessment for JFrog Artifactory instances. Use this skill whenever the user mentions Artifactory security, wants to test an Artifactory instance, needs to enumerate Artifactory vulnerabilities, or is doing penetration testing on package repositories. This skill covers reconnaissance, vulnerability identification, exploitation techniques, and post-exploitation for Artifactory.
---

# Artifactory Pentesting Skill

A comprehensive guide for security testing JFrog Artifactory instances.

## Overview

This skill helps you assess the security of Artifactory instances through systematic reconnaissance, vulnerability identification, and exploitation techniques. Artifactory is a popular artifact repository manager that can contain critical vulnerabilities if misconfigured.

## When to Use This Skill

- Testing Artifactory instances for security vulnerabilities
- Enumerating exposed repositories and artifacts
- Identifying misconfigurations in Artifactory deployments
- Assessing RCE, SSRF, and path traversal vulnerabilities
- Post-exploitation after gaining initial access

## Reconnaissance

### Initial Enumeration

Start by identifying the Artifactory instance and its configuration:

1. **Identify the instance**: Look for Artifactory banners, login pages, or API endpoints
2. **Check for exposed endpoints**: Common paths include:
   - `/artifactory/` - Main web interface
   - `/artifactory/api/` - API endpoints
   - `/artifactory/api/security/` - Security-related endpoints
   - `/artifactory/api/system/` - System information

3. **Gather version information**: Check the About page or API responses for version details

### Repository Discovery

Enumerate available repositories to understand what's stored:

```bash
# List all repositories
GET /artifactory/api/repositories

# Get details about a specific repository
GET /artifactory/api/repositories/<repo-name>

# List artifacts in a repository
GET /artifactory/api/storage/<repo-name>/
```

### User Enumeration

If authentication is required or you have credentials:

```bash
# List users (requires admin)
GET /artifactory/api/security/users

# List groups
GET /artifactory/api/security/groups

# List permissions
GET /artifactory/api/security/permissions
```

## Common Vulnerabilities

### 1. Remote Code Execution (RCE)

Artifactory has had several RCE vulnerabilities:

- **CVE-2018-20250**: Unauthenticated RCE via Groovy script
- **CVE-2018-20251**: RCE via Groovy script (authenticated)
- **CVE-2020-9480**: RCE via Groovy script
- **CVE-2020-9481**: RCE via Groovy script (authenticated)

**Exploitation pattern**:
```bash
# Check for vulnerable endpoints
POST /artifactory/api/security/users/<username>/_groovy
POST /artifactory/api/system/groovy
```

### 2. Server-Side Request Forgery (SSRF)

Artifactory can be vulnerable to SSRF when:
- Remote repositories are misconfigured
- Webhooks are improperly validated
- Proxy settings are exposed

**Test for SSRF**:
```bash
# Try to access internal resources through remote repositories
GET /artifactory/<remote-repo>/http://internal-service/
```

### 3. Path Traversal

Improper input validation can allow path traversal:

```bash
# Test for path traversal
GET /artifactory/api/storage/<repo>/../../../etc/passwd
GET /artifactory/<repo>/..%2f..%2f..%2fetc%2fpasswd
```

### 4. Authentication Bypass

Check for authentication weaknesses:

- Default credentials (admin/password)
- Weak password policies
- Session fixation
- Missing authentication on API endpoints

### 5. Information Disclosure

Sensitive information may be exposed through:

- API responses containing credentials
- Error messages revealing system details
- Exposed configuration files
- Backup files in repositories

## Exploitation Techniques

### Groovy Script Injection

If Groovy endpoints are accessible:

```groovy
// Basic command execution
Process p = "<command>".execute()
p.waitFor()
return p.text
```

### Artifact Manipulation

If you have write access:

- Upload malicious artifacts
- Replace legitimate artifacts with compromised versions
- Create backdoor repositories

### Credential Harvesting

- Monitor API calls for credentials
- Check for hardcoded secrets in artifacts
- Look for credentials in configuration files

## Post-Exploitation

### Persistence

- Create new admin users
- Modify repository permissions
- Install malicious webhooks
- Backdoor legitimate artifacts

### Lateral Movement

- Use Artifactory as a pivot point
- Access connected systems through remote repositories
- Leverage credentials found in artifacts

### Data Exfiltration

- Download sensitive artifacts
- Export repository contents
- Access connected package managers

## Mitigation Recommendations

1. **Keep Artifactory updated**: Apply security patches promptly
2. **Disable unnecessary features**: Turn off Groovy scripting if not needed
3. **Implement network segmentation**: Restrict access to Artifactory
4. **Use strong authentication**: Enable MFA and strong password policies
5. **Monitor access logs**: Watch for suspicious activity
6. **Principle of least privilege**: Limit user permissions
7. **Regular security assessments**: Periodically test for vulnerabilities

## Tools and Resources

### Manual Testing

- Browser DevTools for API exploration
- curl for API testing
- Custom scripts for automation

### Automated Scanning

- Nuclei templates for Artifactory
- Custom vulnerability scanners
- Configuration assessment tools

### Reference Materials

- [JFrog Security Advisories](https://jfrog.com/security-advisories/)
- [CVE Database](https://cve.mitre.org/)
- [HackTricks Artifactory Guide](https://www.hacktricks.xyz/pentesting-web/artifactory-hacking)

## Safety and Ethics

**Important**: Only test systems you have explicit authorization to assess. Unauthorized access to Artifactory instances may violate laws and policies.

## Workflow Summary

1. **Reconnaissance**: Identify the instance and gather information
2. **Enumeration**: Discover repositories, users, and configurations
3. **Vulnerability Assessment**: Test for known vulnerabilities
4. **Exploitation**: Attempt to exploit identified weaknesses
5. **Post-Exploitation**: Assess impact and potential for lateral movement
6. **Reporting**: Document findings and provide remediation guidance

## Quick Reference

| Vulnerability | CVE | Impact | Auth Required |
|--------------|-----|--------|---------------|
| Groovy RCE | CVE-2018-20250 | Critical | No |
| Groovy RCE | CVE-2018-20251 | Critical | Yes |
| Groovy RCE | CVE-2020-9480 | Critical | No |
| Groovy RCE | CVE-2020-9481 | Critical | Yes |

## Notes

- Always verify the Artifactory version before attempting exploitation
- Some vulnerabilities require specific configurations to be exploitable
- Test in a controlled environment before production assessments
- Document all findings with evidence for reporting
