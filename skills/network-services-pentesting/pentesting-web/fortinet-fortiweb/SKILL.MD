---
name: fortinet-fortiweb-assessment
description: Security assessment skill for Fortinet FortiWeb appliances. Use this skill when users need to test FortiWeb for authentication bypass vulnerabilities (CVE-2025-64446), SQL injection in Fabric Connector (CVE-2025-25257), SSO signature bypass (CVE-2025-59719), or command injection (CVE-2025-58034). Trigger this skill for vulnerability scanning, penetration testing, security audits, or incident response on FortiWeb systems. Always verify authorization before testing.
---

# Fortinet FortiWeb Security Assessment

> **⚠️ AUTHORIZED USE ONLY** — This skill is for security professionals conducting authorized assessments. Unauthorized testing may violate laws and policies.

## Overview

This skill provides procedures for assessing Fortinet FortiWeb appliances for critical 2025 vulnerabilities:

| CVE | Type | Impact | Affected Versions |
|-----|------|--------|-------------------|
| CVE-2025-64446 | Auth bypass | Full admin access | 8.0<8.0.2, 7.6<7.6.5, 7.4<7.4.10, 7.2<7.2.12, 7.0<7.0.12, 6.4≤6.4.3, 6.3≤6.3.23 |
| CVE-2025-25257 | SQLi → RCE | Remote code execution | 7.6.0-7.6.3, 7.4.0-7.4.7, 7.2.0-7.2.10, 7.0.0-7.0.10 |
| CVE-2025-59719 | SSO bypass | Admin access | 8.0.0, 7.6.0-7.6.4, 7.4.0-7.4.9 |
| CVE-2025-58034 | Command injection | RCE | 7.0.0-7.0.11, 7.2.0-7.2.11, 7.4.0-7.4.10, 7.6.0-7.6.5, 8.0.0-8.0.1 |

## Quick Assessment Workflow

1. **Verify authorization** — Confirm you have written permission to test the target
2. **Run non-destructive probes** — Check for vulnerability indicators
3. **Document findings** — Record version, response codes, and evidence
4. **Recommend remediation** — Provide patch versions and mitigations

---

## CVE-2025-64446: Auth Bypass via API Traversal

### Vulnerability Summary

FortiWeb's CGI dispatcher at `/cgi-bin/fwbcgi` can be reached via path traversal from API prefixes. Combined with header-based user impersonation, this allows unauthenticated admin access.

### Attack Chain

1. **Path traversal** — Start URL with valid API prefix (`/api/v2.0/cmdb/`), traverse to `fwbcgi`
2. **Input validation bypass** — Send minimal JSON body `{}` to pass permissive check
3. **User impersonation** — Supply `CGIINFO` header with Base64-encoded identity JSON

### Non-Destructive Probe

```bash
# Check if traversal is exposed (200 = vulnerable, 403 = patched)
curl -ik 'https://<target>/api/v2.0/cmdb/system/admin/../../../../../cgi-bin/fwbcgi'
```

**Interpretation:**
- `HTTP 200` — Likely vulnerable, fwbcgi is accessible
- `HTTP 403` — Patched, traversal blocked

### Detection Indicators

- Requests to `/cgi-bin/fwbcgi` via paths containing `../` after `/api/`
- `CGIINFO` header with Base64 JSON containing `username`, `loginname`, `vdom`, `profname`
- Unexpected admin user creation in system logs

### Mitigation

- **Patch** — Upgrade to 8.0.2, 7.6.5, 7.4.10, 7.2.12, or 7.0.12
- **WAF rules** — Block paths starting with `/api/` containing `../cgi-bin/fwbcgi`
- **Header filtering** — Reject requests with `CGIINFO` header
- **Network segmentation** — Don't expose management plane to untrusted networks

---

## CVE-2025-25257: Fabric Connector SQLi → RCE

### Vulnerability Summary

The Fabric Connector API uses the `Authorization: Bearer <token>` value directly in SQL queries. Attackers can inject SQL to write files, achieving code execution.

### Affected Versions

- 7.6.0–7.6.3 (fixed in 7.6.4)
- 7.4.0–7.4.7 (fixed in 7.4.8)
- 7.2.0–7.2.10 (fixed in 7.2.11)
- 7.0.0–7.0.10 (fixed in 7.0.11)

### Non-Destructive Probe

```bash
# Test for SQLi in Fabric Connector endpoint
curl -sk -X POST \
  -H "Authorization: Bearer ' UNION SELECT NULL,NULL,NULL,NULL INTO OUTFILE '/data/var/tmp/pwn.txt' -- -" \
  https://<target>/api/fabric/device/status
```

**Warning:** This probe attempts file creation. Use only in isolated test environments.

### Detection Indicators

- `Authorization` headers containing SQL metacharacters (`'`, `UNION`, `SELECT`)
- Unexpected files in `/data/lib/python*/site-packages/`
- Unexpected files in `/data/var/waf/html/ROOT/cgi-bin/`
- Hits to `/api/fabric/device/status` from internet IPs

### Mitigation

- **Patch** — Upgrade to 7.6.4, 7.4.8, 7.2.11, or 7.0.11
- **Input validation** — Reject `Authorization` headers with SQL metacharacters
- **File monitoring** — Alert on new files in Python site-packages or CGI directories

---

## CVE-2025-59719: FortiCloud SSO Signature Bypass

### Vulnerability Summary

Improper SAML signature verification allows attackers to forge FortiCloud SSO responses and log in as admin without credentials.

### Prerequisites

- FortiCloud SSO login must be enabled (auto-enabled if appliance registered via GUI)

### Affected Versions

- 8.0.0 (fixed in 8.0.1)
- 7.6.0–7.6.4 (fixed in 7.6.5)
- 7.4.0–7.4.9 (fixed in 7.4.10)

### Detection Indicators

- Unexpected SAML issuers in `/var/log/ssod`
- Unexpected SAML audience values
- Admin logins without corresponding authentication events

### Mitigation

- **Patch** — Upgrade to 8.0.1, 7.6.5, or 7.4.10
- **Disable FortiCloud SSO** — If not needed, disable in GUI
- **Block SAML endpoints** — Don't expose SAML endpoints to internet if unused

---

## CVE-2025-58034: OS Command Injection

### Vulnerability Summary

Management plane endpoints execute user-supplied input as shell commands.

### Affected Versions

- 7.0.0–7.0.11 (fixed in 7.0.12)
- 7.2.0–7.2.11 (fixed in 7.2.12)
- 7.4.0–7.4.10 (fixed in 7.4.11)
- 7.6.0–7.6.5 (fixed in 7.6.6)
- 8.0.0–8.0.1 (fixed in 8.0.2)

### Non-Destructive Probe

```bash
# Send parameter with shell metacharacters, watch for 500 with command output
curl -sk 'https://<target>/api/v2.0/cmdb/system/admin?test=;id;'
```

**Warning:** If command output appears in response, block immediately and patch.

### Mitigation

- **Patch** — Upgrade to 7.0.12, 7.2.12, 7.4.11, 7.6.6, or 8.0.2
- **Input sanitization** — Reject parameters containing shell metacharacters
- **Network controls** — Restrict management plane access

---

## Assessment Reporting Template

```
## FortiWeb Security Assessment Report

### Target Information
- Host: <target>
- IP: <ip>
- Version: <detected version>
- Assessment Date: <date>
- Assessor: <name>

### Findings

#### CVE-2025-64446 (Auth Bypass)
- Status: [Vulnerable / Patched / Unknown]
- Evidence: <response code, logs>
- Risk: Critical
- Recommendation: Upgrade to <patch version>

#### CVE-2025-25257 (SQLi → RCE)
- Status: [Vulnerable / Patched / Unknown]
- Evidence: <response, file artifacts>
- Risk: Critical
- Recommendation: Upgrade to <patch version>

#### CVE-2025-59719 (SSO Bypass)
- Status: [Vulnerable / Patched / N/A - SSO disabled]
- Evidence: <SAML logs, login events>
- Risk: High
- Recommendation: Upgrade to <patch version> or disable SSO

#### CVE-2025-58034 (Command Injection)
- Status: [Vulnerable / Patched / Unknown]
- Evidence: <response output>
- Risk: Critical
- Recommendation: Upgrade to <patch version>

### Overall Risk Assessment
<Summary of findings and priority remediation steps>
```

---

## References

- [watchTowr Labs — FortiWeb Auth Bypass](https://labs.watchtowr.com/when-the-impersonation-function-gets-used-to-impersonate-users-fortinet-fortiweb-auth-bypass/)
- [watchTowr vs FortiWeb — Detection Generator](https://github.com/watchtowrlabs/watchTowr-vs-Fortiweb-AuthBypass)
- [CVE-2025-25257 PoC](https://github.com/mrmtwoj/CVE-2025-25257)
- [FortiCloud SSO Bypass Overview](https://cyberpress.org/fortios-fortiweb-fortiproxy-flaw-allows-attackers-to-bypass-forticloud-sso/)
- [Fortinet PSIRT Advisory FG-IR-25-910](https://www.fortiguard.com/psirt/FG-IR-25-910)

---

## Authorization Checklist

Before using this skill, confirm:

- [ ] Written authorization from system owner
- [ ] Scope clearly defined (hosts, tests, timing)
- [ ] Emergency contact established
- [ ] Backup/recovery plan in place
- [ ] Legal/compliance review completed

**Unauthorized testing is illegal and unethical.**
