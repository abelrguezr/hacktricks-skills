---
name: ethernetip-pentest
description: How to enumerate and pentest EtherNet/IP industrial devices on port 44818. Use this skill whenever the user mentions EtherNet/IP, industrial control systems, Rockwell Automation, PLC devices, or port 44818. Also trigger for ICS/SCADA reconnaissance, factory automation security testing, or when investigating industrial Ethernet protocols. Make sure to use this skill for any pentesting task involving industrial automation networks, even if the user doesn't explicitly name EtherNet/IP.
---

# EtherNet/IP Pentesting

A skill for enumerating and testing EtherNet/IP industrial control system devices.

## What is EtherNet/IP?

EtherNet/IP is an **industrial Ethernet networking protocol** used in **industrial automation control systems**. Developed by Rockwell Automation and managed by ODVA, it ensures multi-vendor interoperability in:

- Water processing plants
- Manufacturing facilities
- Utilities and power systems
- Factory automation networks

**Default port:** 44818 (TCP/UDP)

## When to Use This Skill

Use this skill when:
- You need to enumerate industrial control system devices
- Port 44818 is open on a target
- You're testing ICS/SCADA security
- You encounter Rockwell Automation or Allen-Bradley devices
- You need to identify EtherNet/IP device information
- You're doing industrial network reconnaissance

## Enumeration Workflow

### Step 1: Identify EtherNet/IP Devices

First, confirm the target is running EtherNet/IP:

```bash
# Check if port 44818 is open
nmap -p 44818 <target-ip>

# Verify with service detection
nmap -n -sV -p 44818 <target-ip>
```

### Step 2: Run Enumeration Scripts

Use the bundled enumeration script for comprehensive device discovery:

```bash
# Run the enumeration script
./scripts/enumerate_enip.sh <target-ip>
```

This script performs:
- Nmap service detection with enip-info script
- Cpppo-based identity listing
- UDP broadcast discovery (if applicable)

### Step 3: Manual Enumeration (if needed)

If you need more control, run these commands manually:

```bash
# Nmap with EtherNet/IP script
nmap -n -sV --script enip-info -p 44818 <target-ip>

# Cpppo identity listing (TCP)
python3 -m cpppo.server.enip.list_services --list-identity -a <target-ip>

# Cpppo with UDP broadcast
python3 -m cpppo.server.enip.list_services --udp --broadcast --list-identity -a <target-ip>
```

### Step 4: Shodan Reconnaissance

Search for similar devices or public exposure:

```bash
# Search for specific product names
shodan search "port:44818 \"<product-name>\""

# General EtherNet/IP search
shodan search "port:44818"
```

## Required Tools

Ensure these are installed before running enumeration:

```bash
# Nmap with scripting engine
sudo apt install nmap

# Cpppo library for EtherNet/IP
pip3 install cpppo

# Shodan CLI (optional)
pip3 install shodan
shodan init <your-api-key>
```

## Example Outputs

### Nmap enip-info output:
```
PORT      STATE SERVICE VERSION
44818/tcp open  enip    EtherNet/IP
| enip-info:
|   Product Name: Allen-Bradley ControlLogix
|   Vendor: Rockwell Automation
|   Serial Number: 12345678
|   Device Type: Controller
```

### Cpppo list_services output:
```
Device: 192.168.1.100
  Product Name: CompactLogix 5370
  Vendor: Rockwell Automation
  Serial Number: ABC123
  Revision: 25.007
  State: Run
```

## Common EtherNet/IP Devices

| Device Type | Vendor | Typical Use |
|-------------|--------|-------------|
| ControlLogix | Rockwell | Large-scale automation |
| CompactLogix | Rockwell | Compact control systems |
| MicroLogix | Rockwell | Small automation tasks |
| PowerFlex | Rockwell | Motor drives |
| PanelView | Rockwell | HMI interfaces |

## Security Considerations

⚠️ **Important:** EtherNet/IP devices are often part of critical infrastructure. Always:

1. **Get explicit authorization** before testing industrial systems
2. **Coordinate with operations teams** to avoid disrupting production
3. **Test during maintenance windows** when possible
4. **Document all findings** for the security team
5. **Avoid aggressive scanning** that could trigger device alarms or shutdowns

## Troubleshooting

### Port 44818 appears closed but device exists
- Try UDP scan: `nmap -sU -p 44818 <target-ip>`
- Check for firewalls between you and the device
- Verify the device is powered on and connected

### Cpppo commands fail
- Ensure Python 3.7+ is installed
- Reinstall cpppo: `pip3 install --upgrade cpppo`
- Check network connectivity to the target

### Nmap script not found
- Update Nmap: `sudo apt update && sudo apt upgrade nmap`
- Verify script path: `ls /usr/share/nmap/scripts/enip-info.nse`

## Next Steps After Enumeration

Once you've identified EtherNet/IP devices:

1. **Document device inventory** - Record all discovered devices, vendors, and models
2. **Check for known vulnerabilities** - Search CVE databases for the specific device models
3. **Review network segmentation** - Ensure ICS networks are properly isolated
4. **Assess authentication** - Many EtherNet/IP devices have no authentication by default
5. **Consider specialized ICS tools** - Tools like Grapl, Nozomi, or Dragos for deeper analysis

## References

- [ODVA EtherNet/IP Specification](https://www.odva.org/)
- [Rockwell Automation Security Advisories](https://www.rockwellautomation.com/en-us/support/security.html)
- [ICS-CERT Advisories](https://www.cisa.gov/ics)
- [Nmap enip-info Script Documentation](https://nmap.org/nsedoc/scripts/enip-info.html)
