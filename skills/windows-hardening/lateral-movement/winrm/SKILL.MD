---
name: winrm-hardening
description: How to assess, test, and harden Windows Remote Management (WinRM) configurations. Use this skill whenever the user mentions WinRM, Windows remote management, lateral movement via WinRM, needs to audit/harden WinRM settings on Windows systems, or is working on Windows security hardening. Make sure to use this skill for any WinRM-related security assessment, configuration review, or hardening task.
---

# WinRM Hardening Skill

This skill helps you assess, test, and harden Windows Remote Management (WinRM) configurations for security. WinRM is a Windows service that enables remote management and is a common target for lateral movement attacks.

## When to Use This Skill

Use this skill when:
- You need to audit WinRM configurations on Windows systems
- You're hardening Windows systems against lateral movement
- You're testing WinRM security in authorized penetration testing
- You need to understand WinRM attack vectors and mitigations
- You're reviewing Windows remote management security

## WinRM Overview

WinRM (Windows Remote Management) is a service that:
- Enables remote management of Windows systems
- Uses WS-Management protocol (HTTP/HTTPS)
- Default ports: 5985 (HTTP), 5986 (HTTPS)
- Can be exploited for lateral movement if misconfigured

## Assessment Workflow

### 1. Check WinRM Service Status

First, determine if WinRM is running and how it's configured:

```powershell
# Check if WinRM service is running
Get-Service WinRM

# Check WinRM configuration
winrm enumerate winrm/config

# Check listeners
winrm enumerate winrm/config/listener

# Check clients
winrm enumerate winrm/config/client
```

### 2. Identify Security Issues

Common WinRM security issues to look for:

| Issue | Risk | Detection |
|-------|------|----------|
| HTTP enabled (port 5985) | High - unencrypted traffic | `winrm enumerate winrm/config/listener` |
| No authentication required | Critical | Check `winrm/config/service/Auth` |
| Basic authentication enabled | High - credentials in transit | Check `winrm/config/service/Auth` |
| Kerberos delegation enabled | Medium - credential theft risk | Check `winrm/config/service` |
| Unrestricted firewall rules | High | Check Windows Firewall rules |
| Default credentials | Critical | Test with known weak creds |

### 3. Test WinRM Connectivity

```powershell
# Test local WinRM
winrm quickconfig

# Test remote WinRM (requires credentials)
Test-WSMan -ComputerName <target>

# Test with specific credentials
Test-WSMan -ComputerName <target> -Credential (Get-Credential)
```

## Hardening Recommendations

### Critical Hardening Steps

1. **Disable HTTP, Enable HTTPS Only**
   ```powershell
   # Remove HTTP listener
   winrm delete winrm/config/listener?Address=*+Transport=HTTP
   
   # Create HTTPS listener with certificate
   winrm create winrm/config/listener?Address=*+Transport=HTTPS @{
     Hostname="<hostname>"
     CertificateThumbprint="<thumbprint>"
   }
   ```

2. **Configure Strong Authentication**
   ```powershell
   # Disable Basic authentication
   winrm set winrm/config/service/Auth @{Basic="false"}
   
   # Enable Kerberos and NTLM only
   winrm set winrm/config/service/Auth @{Kerberos="true";Negotiate="true";NTLM="true"}
   ```

3. **Disable Unconstrained Delegation**
   ```powershell
   winrm set winrm/config/service @{AllowUnencrypted="false";MaxEnvelopeSizekb="1024"}
   ```

4. **Restrict Firewall Access**
   ```powershell
   # Allow only specific source IPs
   New-NetFirewallRule -DisplayName "WinRM HTTPS" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow -RemoteAddress <trusted-subnet>
   ```

5. **Enable Logging**
   ```powershell
   winrm set winrm/config/service @{MaxTimeoutms="1800000";EnableWinRMLogging="true"}
   ```

### Additional Hardening

- **Use certificate-based authentication** instead of username/password
- **Implement Network Level Authentication (NLA)** for RDP
- **Regularly audit WinRM configurations** across the environment
- **Monitor WinRM logs** for suspicious activity
- **Limit WinRM to necessary systems only**

## Lateral Movement Considerations

WinRM is commonly used for lateral movement. Understand these attack vectors:

### Common Attack Patterns

1. **Credential Reuse**: Attackers use stolen credentials to connect via WinRM
2. **Pass-the-Hash**: NTLM hashes can be used with WinRM
3. **Kerberoasting**: Service tickets can be targeted
4. **Unconstrained Delegation**: Can lead to credential theft

### Detection Indicators

- Unexpected WinRM connections from unusual sources
- WinRM connections during off-hours
- Multiple failed WinRM authentication attempts
- WinRM connections to sensitive systems

## Scripts

Use the bundled scripts for common tasks:

- `check-winrm-config.ps1` - Audit WinRM configuration
- `harden-winrm.ps1` - Apply hardening recommendations
- `test-winrm-connectivity.ps1` - Test WinRM connectivity

## References

- [Microsoft WinRM Documentation](https://docs.microsoft.com/en-us/windows/win-server/remote/remote-management-services/overview-winrm)
- [WinRM Security Best Practices](https://docs.microsoft.com/en-us/windows/win-server/remote/remote-management-services/configure-winrm-security)
- [HackTricks WinRM Pentesting](https://book.hacktricks.xyz/windows-hardening/lateral-movement/winrm)

## Important Notes

- **Authorization Required**: Only perform WinRM testing on systems you own or have explicit authorization to test
- **Backup Configurations**: Always backup WinRM configurations before making changes
- **Test in Lab First**: Validate hardening changes in a test environment before production
- **Document Changes**: Keep records of all WinRM configuration changes
