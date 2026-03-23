---
name: windows-lateral-movement
description: Guide for understanding Windows lateral movement techniques in authorized security assessments. Use this skill when the user asks about lateral movement, PsExec, SmbExec, WmiExec, WinRM, DCOM, RDP, or any Windows remote execution methods during penetration testing, red teaming, or security assessments. Also trigger when users need to understand how attackers move through Windows networks, detect lateral movement, or harden systems against these techniques.
---

# Windows Lateral Movement Guide

## Purpose

This skill provides educational guidance on Windows lateral movement techniques for **authorized security professionals** conducting penetration testing, red teaming, or security assessments. Understanding these techniques is essential for:

- **Red teaming**: Simulating adversary behavior
- **Blue teaming**: Detecting and responding to lateral movement
- **Security assessments**: Identifying and remediating vulnerabilities
- **Incident response**: Understanding attack patterns

## ⚠️ Ethical Use Warning

**Only use this knowledge in authorized contexts:**

- You have explicit written permission to test the target systems
- You are working within a defined scope and rules of engagement
- You are conducting authorized penetration testing or security research
- You are studying for defensive purposes (detection, hardening, response)

**Unauthorized use of these techniques is illegal and unethical.**

## What is Lateral Movement?

Lateral movement is the technique attackers use to move through a network after gaining initial access to one system. The goal is to reach high-value targets (domain controllers, sensitive data stores, etc.) by pivoting through intermediate systems.

## Common Windows Lateral Movement Techniques

### 1. PsExec

**Overview**: PsExec is a legitimate Sysinternals tool that can execute processes on remote systems using the Admin$ share.

**How it works**:
- Uses SMB to connect to the remote Admin$ share
- Copies the executable to the remote system
- Creates a service to run the executable
- Cleans up after execution

**Detection indicators**:
- New services created on remote systems
- SMB connections to Admin$ share
- Process creation from unexpected locations
- Network traffic on port 445

**Mitigation**:
- Disable Admin$ share where possible
- Monitor service creation events (Event ID 7045)
- Implement network segmentation
- Use application whitelisting

### 2. SmbExec

**Overview**: Executes commands on remote systems using SMB and the Windows API.

**How it works**:
- Connects via SMB to the remote system
- Uses the Windows API to create a service
- Executes the command through the service
- Removes the service after execution

**Detection indicators**:
- Similar to PsExec (service creation, SMB traffic)
- PowerShell or Python scripts making SMB connections
- Event ID 7045 (service installation)

**Mitigation**:
- Same as PsExec
- Monitor for suspicious SMB activity
- Implement SMB signing

### 3. WmiExec

**Overview**: Uses Windows Management Instrumentation (WMI) to execute commands remotely.

**How it works**:
- Connects to WMI namespace on remote system
- Uses WMI to create and execute processes
- No files written to disk (fileless)

**Detection indicators**:
- WMI event subscriptions (Event ID 5861)
- Process creation via WMI (Event ID 4688 with WMI parent)
- Network traffic on port 135, 445
- `wmiprvse.exe` spawning unexpected processes

**Mitigation**:
- Disable WMI where not needed
- Monitor WMI event subscriptions
- Implement WMI query logging
- Use WMI namespace security

### 4. AtExec / SchtasksExec

**Overview**: Uses Windows scheduled tasks to execute commands on remote systems.

**How it works**:
- Creates a scheduled task on the remote system
- Task executes the desired command
- Task can be deleted after execution

**Detection indicators**:
- Scheduled task creation (Event ID 4698)
- Task execution (Event ID 4699)
- Task deletion (Event ID 4700)
- Network traffic on port 135, 445

**Mitigation**:
- Monitor scheduled task events
- Implement task creation restrictions
- Use Group Policy to limit task creation
- Audit task execution

### 5. WinRM

**Overview**: Windows Remote Management uses WS-Management protocol for remote administration.

**How it works**:
- Uses HTTP/HTTPS (ports 5985/5986)
- Supports PowerShell remoting
- Can execute commands and scripts remotely

**Detection indicators**:
- WinRM service activity (Event ID 5960-5962)
- PowerShell remoting events
- Network traffic on ports 5985/5986
- `WinRM` process spawning

**Mitigation**:
- Disable WinRM where not needed
- Use HTTPS (port 5986) with certificates
- Implement WinRM logging
- Restrict WinRM access via firewall

### 6. DCOM Exec

**Overview**: Uses Distributed Component Object Model (DCOM) to execute commands remotely.

**How it works**:
- Uses DCOM to connect to remote system
- Creates processes through DCOM interfaces
- Requires administrative credentials

**Detection indicators**:
- DCOM activity (Event ID 5156, 5157)
- Process creation via DCOM
- Network traffic on port 135
- `svchost.exe` spawning unexpected processes

**Mitigation**:
- Disable DCOM where not needed
- Implement DCOM security settings
- Monitor DCOM activity
- Use network segmentation

### 7. RDPexec

**Overview**: Uses Remote Desktop Protocol to execute commands on remote systems.

**How it works**:
- Establishes RDP connection to remote system
- Executes commands through RDP session
- Can use automated tools for command execution

**Detection indicators**:
- RDP connection events (Event ID 4624 with logon type 10)
- RDP session creation (Event ID 4778)
- Network traffic on port 3389
- Multiple RDP sessions from same source

**Mitigation**:
- Disable RDP where not needed
- Implement Network Level Authentication (NLA)
- Use RDP gateway
- Monitor RDP connection events
- Implement MFA for RDP

### 8. SCMexec

**Overview**: Uses Service Control Manager (SCM) to execute commands remotely.

**How it works**:
- Connects to SCM on remote system
- Creates a service to execute commands
- Starts the service
- Removes the service after execution

**Detection indicators**:
- Service creation events (Event ID 7045)
- Service start events (Event ID 7040)
- Service deletion events (Event ID 7046)
- Network traffic on port 135, 445

**Mitigation**:
- Monitor service events
- Implement service creation restrictions
- Use application whitelisting
- Audit service changes

## Cloud-Specific Techniques

### Pass the Cookie (Azure)

**Overview**: Uses Azure AD session cookies to authenticate to other Azure resources.

**Detection indicators**:
- Unusual Azure AD sign-in patterns
- Multiple resource access from same session
- Anomalous API calls

**Mitigation**:
- Implement conditional access policies
- Monitor Azure AD sign-in logs
- Use MFA
- Implement least privilege

### Pass the PRT (Azure)

**Overview**: Uses Primary Refresh Token (PRT) for authentication in Azure AD environments.

**Detection indicators**:
- Unusual device registration patterns
- Anomalous authentication events
- Multiple resource access from same device

**Mitigation**:
- Monitor device registration events
- Implement device compliance policies
- Use conditional access
- Audit PRT usage

### Pass the AzureAD Certificate

**Overview**: Uses Azure AD certificates for authentication to Azure resources.

**Detection indicators**:
- Unusual certificate usage patterns
- Multiple resource access with same certificate
- Anomalous authentication events

**Mitigation**:
- Monitor certificate usage
- Implement certificate rotation
- Use certificate-based conditional access
- Audit certificate authentication

## Detection Strategy

### Key Event IDs to Monitor

| Event ID | Description |
|----------|-------------|
| 4624 | An account was logged on |
| 4688 | A new process was created |
| 4698 | A scheduled task was created |
| 4699 | A scheduled task was executed |
| 4700 | A scheduled task was deleted |
| 4778 | A user account was locked out |
| 5861 | WMI event subscription created |
| 7040 | A service was installed |
| 7045 | A service was created |
| 7046 | A service was deleted |

### Network Indicators

- SMB traffic (port 445)
- RPC traffic (port 135)
- WinRM traffic (ports 5985/5986)
- RDP traffic (port 3389)
- WMI traffic (ports 135, 445)

### Behavioral Indicators

- Multiple failed authentication attempts followed by success
- Lateral movement patterns (system to system)
- Unusual process execution patterns
- Service creation/deletion patterns
- Scheduled task creation patterns

## Hardening Recommendations

### Network Security

1. **Segmentation**: Implement network segmentation to limit lateral movement
2. **Firewall rules**: Restrict unnecessary ports between systems
3. **SMB signing**: Enable SMB signing to prevent man-in-the-middle attacks
4. **TLS**: Use TLS for remote management protocols

### System Hardening

1. **Disable unnecessary services**: Disable WMI, DCOM, WinRM where not needed
2. **Application whitelisting**: Implement application whitelisting
3. **Least privilege**: Use least privilege principles
4. **Patch management**: Keep systems up to date

### Monitoring

1. **Enable logging**: Enable all relevant security event logging
2. **Centralized logging**: Implement centralized log collection
3. **SIEM integration**: Integrate with SIEM for correlation
4. **Alerting**: Create alerts for lateral movement indicators

## References

- [HackTricks Lateral Movement](https://book.hacktricks.xyz/windows-hardening/windows-local-privilege-escalation#lateral-movement)
- [MITRE ATT&CK: Lateral Movement](https://attack.mitre.org/tactics/TA0008/)
- [Sysinternals PsExec](https://learn.microsoft.com/en-us/sysinternals/downloads/psexec)
- [Microsoft: Windows Event IDs](https://learn.microsoft.com/en-us/windows/security/threat-protection/auditing/event-ids)

## When to Use This Skill

Use this skill when:

- You're conducting an authorized penetration test and need to understand lateral movement options
- You're building detection rules for lateral movement techniques
- You're hardening Windows systems against lateral movement
- You're investigating a potential breach and need to understand lateral movement patterns
- You're studying for security certifications (OSCP, OSEP, CRTO, etc.)
- You're writing security documentation or training materials
- You need to explain lateral movement concepts to stakeholders

## Important Notes

- **Authorization is critical**: Never use these techniques without explicit written permission
- **Documentation**: Document all testing activities and findings
- **Communication**: Keep stakeholders informed during testing
- **Cleanup**: Ensure all test artifacts are removed after testing
- **Legal compliance**: Understand and comply with all applicable laws and regulations
