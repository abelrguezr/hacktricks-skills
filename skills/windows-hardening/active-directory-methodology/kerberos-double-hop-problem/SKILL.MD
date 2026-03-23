---
name: kerberos-double-hop
description: How to understand and work around the Kerberos double hop authentication problem in Windows environments. Use this skill whenever you need to authenticate across multiple hops in Active Directory, troubleshoot Kerberos authentication failures between servers, set up PowerShell remoting across multiple systems, or work with WinRM/SSH in multi-hop scenarios. This applies to penetration testing, security assessments, and legitimate administrative tasks where you need to chain authentication through intermediate servers.
---

# Kerberos Double Hop Problem

## What is the Double Hop Problem?

The Kerberos double hop problem occurs when you try to authenticate across **two hops** using Kerberos. For example, when using PowerShell/WinRM to connect from Server A to Server B, then from Server B to Server C.

### Why it happens

When authentication occurs through Kerberos, credentials aren't cached in memory. The flow looks like this:

1. User provides credentials → Domain Controller returns a Kerberos TGT
2. User uses TGT to request a service ticket to connect to Server1
3. User connects to Server1 and provides the service ticket
4. **Server1 doesn't have the user's credentials or TGT** → When trying to authenticate to Server2, it fails

This is by design for security, but it creates operational challenges.

## Detection

### Check if CredSSP is enabled

```powershell
Get-WSManCredSSP
```

Or remotely:

```powershell
Invoke-Command -ComputerName <target> -Credential <cred> -ScriptBlock {
    Get-WSManCredSSP
}
```

### Check Remote Credential Guard patches

For Windows 11 22H2+, verify the April 2024 cumulative updates are installed:

```powershell
("KB5036896","KB5036889","KB5036894") | ForEach-Object {
    Get-HotFix -Id $_ -ErrorAction SilentlyContinue
}
```

## Workarounds

### 1. Nested Invoke-Command (Quick Workaround)

This doesn't solve the problem but works around it by executing commands through the first server:

```powershell
$cred = Get-Credential <domain>\<username>
Invoke-Command -ComputerName <first-server> -Credential $cred -ScriptBlock {
    Invoke-Command -ComputerName <second-server> -Credential $using:cred -ScriptBlock {
        hostname
    }
}
```

**When to use:** Quick one-off commands, testing connectivity

### 2. Register PSSession Configuration

Create a persistent session configuration that bypasses the double hop limitation:

```powershell
# On the first server
Register-PSSessionConfiguration -Name doublehopsess -RunAsCredential <domain>\<username>
Restart-Service WinRM

# Connect using the configuration
Enter-PSSession -ConfigurationName doublehopsess -ComputerName <target> -Credential <domain>\<username>
```

**When to use:** When you need a persistent session and have admin access to configure WinRM

### 3. Port Forwarding with netsh

For local administrators on an intermediary target, forward ports to reach the final server:

```powershell
# Add port proxy rule
netsh interface portproxy add v4tov4 \
    listenport=5446 \
    listenaddress=10.35.8.17 \
    connectport=5985 \
    connectaddress=10.35.8.23

# Add firewall rule
netsh advfirewall firewall add rule \
    name=fwd \
    dir=in \
    action=allow \
    protocol=TCP \
    localport=5446
```

Then use `winrs.exe` for less detectable access:

```powershell
winrs -r:http://<first-server>:5446 -u:<domain>\<user> -p:<password> <command>
```

**When to use:** When you have local admin on the intermediary and want to avoid PowerShell monitoring

### 4. OpenSSH Installation

Install OpenSSH on the first server to enable SSH-based multi-hop access:

```powershell
# 1. Download and extract OpenSSH to the target
# 2. Run installation script
Install-sshd.ps1

# 3. Add firewall rule for port 22
New-NetFirewallRule -DisplayName "OpenSSH" -Direction Inbound -LocalPort 22 -Protocol TCP -Action Allow

# 4. If you get "Connection reset" errors, fix permissions
icacls.exe "C:\ProgramData\ssh" /grant Everyone:RX /T
```

**When to use:** Jump box scenarios, when you need SSH access through the intermediary

### 5. Remote Credential Guard (RCG)

RCG keeps the TGT on the originating workstation while allowing RDP sessions to request new Kerberos tickets:

1. Enable via Group Policy: `Computer Configuration > Administrative Templates > System > Credentials Delegation > Restrict delegation of credentials to remote servers`
2. Select "Require Remote Credential Guard"
3. Connect with: `mstsc.exe /remoteGuard /v:<server>`

**When to use:** Production environments where CredSSP is disabled, RDP-based access

**Note:** Windows 11 22H2+ requires the April 2024 cumulative updates for multi-hop RCG to work.

### 6. LSA Whisperer CacheLogon (Advanced)

For high-friction environments where CredSSP/RCG are disallowed, you can inject NT hashes into existing logon sessions:

```powershell
# 1. Enumerate logon sessions
lsa.exe sessions

# 2. Seed the cache with the NT hash
lsa.exe cachelogon --session 0x3e4 --domain <domain> --username <user> --nthash <hash>

# 3. Run your multi-hop command
Invoke-Command -ComputerName <second-server> -Credential <cred> -ScriptBlock { hostname }

# 4. Clear the cache when done
lsa.exe cacheclear --session 0x3e4
```

**When to use:** Advanced scenarios, when other methods are blocked, you have code execution in LSASS

**Trade-offs:** Heavier telemetry, requires LSASS access, more detectable

## Security Considerations

### Unconstrained Delegation

If unconstrained delegation is enabled, the server gets a TGT for each user accessing it. This can be exploited to compromise the Domain Controller.

### CredSSP Risks

CredSSP is notably insecure:
- Credentials are delegated to the remote computer
- If the remote computer is compromised, credentials can be used to control the network session
- **Recommendation:** Disable on production systems and sensitive networks

### Remote Credential Guard

RCG is the recommended approach for production environments as it:
- Keeps TGT on the originating workstation
- Doesn't expose reusable secrets on intermediate servers
- Requires proper patching on Windows 11 22H2+

## Quick Decision Guide

| Scenario | Recommended Approach |
|----------|---------------------|
| Quick test command | Nested Invoke-Command |
| Persistent session needed | Register PSSession Configuration |
| Avoid PowerShell monitoring | Port forwarding + winrs.exe |
| Jump box scenario | OpenSSH |
| Production RDP access | Remote Credential Guard |
| High-friction, all else blocked | LSA Whisperer CacheLogon |

## References

- [Microsoft: Understanding Kerberos Double Hop](https://techcommunity.microsoft.com/t5/ask-the-directory-services-team/understanding-kerberos-double-hop/ba-p/395463)
- [Slayer Labs: Double Hop](https://posts.slayerlabs.com/double-hop/)
- [SpecterOps: LSA Whisperer](https://specterops.io/blog/2024/04/17/lsa-whisperer/)
- [4sysops: Solve Multi-Hop Without CredSSP](https://4sysops.com/archives/solve-the-powershell-multi-hop-problem-without-using-credssp/)
- [Microsoft: April 2024 Cumulative Updates](https://support.microsoft.com/en-au/topic/april-9-2024-kb5036896)
