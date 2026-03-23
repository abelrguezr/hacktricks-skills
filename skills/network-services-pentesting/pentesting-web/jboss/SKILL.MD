---
name: jboss-pentest
description: Security assessment and enumeration of JBoss application servers. Use this skill whenever the user mentions JBoss, JBoss AS, JBoss EAP, or needs to enumerate Java application servers, check for default credentials, find exposed management consoles, or assess JMX vulnerabilities. Trigger for any web application security testing involving JBoss servers, even if the user doesn't explicitly name JBoss but describes Java EE application server assessment.
---

# JBoss Application Server Security Assessment

A skill for enumerating and assessing JBoss application servers during security testing engagements.

## When to Use This Skill

Use this skill when:
- Assessing web applications hosted on JBoss servers
- Enumerating Java application servers for exposed management interfaces
- Checking for default credentials on JBoss management consoles
- Finding vulnerable JBoss instances via reconnaissance
- Testing JMX console security and MBean access
- Performing web application penetration testing on Java EE environments

## Quick Start

1. **Identify the target** - Get the JBoss server URL
2. **Run enumeration** - Check for exposed management paths
3. **Test default credentials** - Try admin/admin on management consoles
4. **Assess MBean access** - Check for vulnerable invoker servlets
5. **Document findings** - Report exposed services and vulnerabilities

## Enumeration Paths

Check these common JBoss paths for exposed management interfaces:

### Core Management Paths
- `/web-console/ServerInfo.jsp` - Server information disclosure
- `/status?full=true` - Full status page with server details
- `/admin-console/` - Administrative console
- `/jmx-console/` - JMX console for MBean management
- `/management/` - Management interface
- `/web-console/` - Web console root

### Version-Specific Invoker Servlets

**JBoss 6 and 7:**
- `/web-console/Invoker` - MBean invocation servlet

**JBoss 5 and earlier:**
- `/invoker/JMXInvokerServlet` - JMX invoker
- `/invoker/EJBInvokerServlet` - EJB invoker

## Default Credentials

Test these common default credentials on management consoles:

| Username | Password |
|----------|----------|
| admin | admin |
| admin | password |
| administrator | administrator |
| root | root |
| system | system |

## Enumeration Tools

### clusterd
A tool for JBoss cluster enumeration and exploitation.

**Repository:** https://github.com/hatRiot/clusterd

**Usage:**
```bash
# Clone and run
pip install clusterd
clusterd --target http://target.com --scan
```

### Metasploit
Use the JBoss vulnerability scanner module:

```bash
msfconsole
use auxiliary/scanner/http/jboss_vulnscan
set RHOSTS <target>
set RPORT 8080
run
```

### JexBoss
Exploitation tool for JBoss vulnerabilities.

**Repository:** https://github.com/joaomatosf/jexboss

**Usage:**
```bash
# Basic scan
python jexboss.py -u http://target.com/web-console/Invoker

# With authentication
python jexboss.py -u http://target.com/web-console/Invoker -u admin -p admin

# Remote code execution (if vulnerable)
python jexboss.py -u http://target.com/web-console/Invoker --rce
```

## Reconnaissance Techniques

### Google Dorking
Find exposed JBoss servers using search queries:

```
inurl:status EJInvokerServlet
inurl:"/jmx-console/"
intitle:"JBoss" "Welcome to JBoss"
inurl:"/web-console/ServerInfo.jsp"
```

### Manual Testing Steps

1. **Check for exposed paths** - Use curl or browser to test each path
2. **Look for version information** - ServerInfo.jsp often reveals version
3. **Test authentication** - Try default credentials on each console
4. **Check for MBean access** - If invoker servlets are exposed, test MBean operations
5. **Document all findings** - Record which paths are accessible and with what credentials

## Common Vulnerabilities

- **Exposed management consoles** - Unauthenticated access to admin interfaces
- **Default credentials** - admin/admin still in use
- **Vulnerable MBean access** - Invoker servlets allowing arbitrary MBean operations
- **Information disclosure** - ServerInfo.jsp revealing version and configuration
- **Remote code execution** - Via vulnerable JMX operations in older versions

## Assessment Workflow

1. **Reconnaissance**
   - Identify JBoss server via banners, paths, or technology detection
   - Map all accessible management paths
   - Document server version if discoverable

2. **Authentication Testing**
   - Test default credentials on all management consoles
   - Check for weak password policies
   - Attempt credential enumeration if possible

3. **Vulnerability Assessment**
   - Run automated scanners (clusterd, Metasploit)
   - Test for known JBoss vulnerabilities
   - Check for exposed MBean operations

4. **Exploitation (if authorized)**
   - Use JexBoss for RCE testing on vulnerable versions
   - Test MBean manipulation capabilities
   - Document all successful exploitation paths

5. **Reporting**
   - List all exposed management interfaces
   - Document credential findings
   - Provide remediation recommendations

## Remediation Recommendations

- **Disable unused management consoles** - Remove or restrict access to admin interfaces
- **Change default credentials** - Always modify default admin passwords
- **Restrict access** - Use firewall rules to limit management console access
- **Update JBoss** - Keep server patched to latest version
- **Remove invoker servlets** - Disable JMXInvokerServlet and EJBInvokerServlet if not needed
- **Implement authentication** - Require authentication for all management paths
- **Use HTTPS** - Encrypt management console traffic

## Safety Notes

- Only test systems you have explicit authorization to assess
- Document all testing activities for audit purposes
- Be aware that some exploitation techniques can cause service disruption
- Follow responsible disclosure practices for any vulnerabilities found
