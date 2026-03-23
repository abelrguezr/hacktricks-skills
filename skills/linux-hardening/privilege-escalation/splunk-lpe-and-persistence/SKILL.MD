---
name: splunk-security-assessment
description: Security assessment skill for Splunk services. Use this skill whenever the user needs to enumerate Splunk installations, assess Splunk security configurations, document Splunk vulnerabilities, or perform authorized penetration testing on Splunk infrastructure. Trigger on mentions of Splunk, port 8090, Splunk Universal Forwarder, Splunkd, or security assessments involving Splunk services.
---

# Splunk Security Assessment

A skill for security professionals to assess Splunk service security, enumerate configurations, and document vulnerabilities during authorized penetration testing engagements.

## When to Use This Skill

Use this skill when:
- Enumerating Splunk services during internal/external security assessments
- Assessing Splunk Universal Forwarder configurations
- Documenting Splunk-related vulnerabilities in security reports
- Performing authorized penetration testing on Splunk infrastructure
- Reviewing Splunk service hardening requirements

## Prerequisites

- **Authorization**: Only use on systems where you have explicit written authorization
- **Access**: Network access to Splunk services (typically port 8090 for web, 8089 for management)
- **Credentials**: Valid Splunk credentials for authenticated assessments

## Assessment Workflow

### 1. Service Enumeration

Identify Splunk services on target systems:

```bash
# Check for Splunk web interface (port 8090)
nmap -p 8090 <target>

# Check for Splunk management port (port 8089)
nmap -p 8089 <target>

# Banner grabbing
curl -v http://<target>:8090/
```

### 2. Configuration Review

Review Splunk configuration files for security issues:

```bash
# Check server.conf for network bindings
cat $SPLUNK_HOME/etc/system/local/server.conf | grep -i bind

# Check for authentication settings
cat $SPLUNK_HOME/etc/system/local/server.conf | grep -i auth

# Review password files (if authorized)
cat $SPLUNK_HOME/etc/system/local/passwords.conf
```

### 3. Universal Forwarder Assessment

Assess Splunk Universal Forwarder security:

```bash
# Check forwarder configuration
cat $SPLUNK_HOME/etc/system/local/outputs.conf

# Review authentication tokens
cat $SPLUNK_HOME/etc/system/local/server.conf | grep -i pass4
```

### 4. Vulnerability Documentation

Document known vulnerabilities:

| CVE | Description | Impact | Mitigation |
|-----|-------------|--------|------------|
| CVE-2023-46214 | Splunk query injection | RCE | Patch to latest version |
| UF Agent Auth | Weak forwarder authentication | RCE | Strong passwords, network segmentation |

## Security Recommendations

### Network Security

- **Bind to localhost**: Configure Splunk to only listen on localhost when possible
- **Firewall rules**: Restrict access to Splunk ports to authorized networks only
- **Network segmentation**: Isolate Splunk infrastructure from general network

### Authentication Hardening

- **Strong passwords**: Use complex passwords for Splunk accounts
- **Disable default accounts**: Remove or disable default admin accounts
- **Multi-factor authentication**: Enable MFA where supported
- **Password rotation**: Implement regular password rotation policies

### Configuration Hardening

```ini
# server.conf hardening example
[general]
enableSplunkdSSL = true
sslCertPath = $SPLUNK_HOME/etc/auth/server.pem
sslCertKeyPath = $SPLUNK_HOME/etc/auth/server.key

[sslConfig]
sslVerifyMode = peer
```

### Monitoring and Logging

- **Enable audit logging**: Monitor all administrative actions
- **Alert on anomalies**: Set up alerts for unusual access patterns
- **Log forwarding**: Forward Splunk logs to external SIEM

## Reporting

Generate security assessment reports using the bundled scripts:

```bash
# Generate vulnerability report
python scripts/generate_splunk_report.py --target <target> --output report.md

# Generate remediation checklist
python scripts/generate_remediation.py --target <target> --output remediation.md
```

## References

- [Splunk Security Documentation](https://docs.splunk.com/Documentation/Splunk/latest/Security/Security)
- [Splunk Universal Forwarder Security](https://docs.splunk.com/Documentation/Splunk/latest/Forwarder/Security)
- [CVE-2023-46214 Analysis](https://blog.hrncirik.net/cve-2023-46214-analysis)
- [SplunkWhisperer2 Exploit](https://github.com/cnotin/SplunkWhisperer2)

## Important Notes

- **Authorization Required**: Only perform these assessments on systems where you have explicit written authorization
- **Legal Compliance**: Ensure all activities comply with applicable laws and regulations
- **Scope Definition**: Clearly define assessment scope before beginning
- **Data Protection**: Handle any discovered credentials or sensitive data appropriately
- **Disclosure**: Report findings to appropriate stakeholders following responsible disclosure practices
