---
name: bacnet-enumeration
description: Enumerate BACnet devices on building automation networks. Use this skill whenever the user mentions BACnet, building automation, HVAC control systems, port 47808, or needs to discover and enumerate devices on industrial control networks. This skill helps identify BACnet devices, extract device information, and assess building automation security.
---

# BACnet Enumeration Skill

A skill for discovering and enumerating BACnet devices on building automation and control networks.

## When to Use This Skill

Use this skill when:
- The user mentions BACnet, port 47808, or building automation systems
- You need to enumerate HVAC, lighting, access control, or fire detection systems
- The user is performing security assessments on industrial control networks
- You need to discover devices on a BACnet network
- The user wants to extract device information from BACnet controllers

## What This Skill Does

This skill helps you:
1. **Discover BACnet devices** on the network using WHOIS broadcasts
2. **Enumerate device properties** including model, version, and vendor
3. **Run automated scans** using nmap scripts
4. **Search Shodan** for exposed BACnet devices

## Prerequisites

- Network access to the BACnet subnet (must be on the same network segment)
- Python 3 with BAC0 and netifaces libraries installed
- Nmap with BACnet scripts available
- Appropriate authorization to scan the target network

## Enumeration Methods

### Method 1: Python BAC0 Library (Recommended)

The BAC0 library provides the most comprehensive enumeration capabilities.

**Setup:**
```bash
pip3 install BAC0
pip3 install netifaces
```

**Usage:**

1. Determine your IP address and subnet mask
2. Use the `scripts/bacnet-enumerate.py` script to discover devices
3. Review the output for device information

**Example:**
```bash
python3 scripts/bacnet-enumerate.py --ip "192.168.1.4/24"
```

This will:
- Broadcast a WHOIS request to discover all BACnet devices
- Wait for devices to respond (5 seconds)
- Enumerate each discovered device
- Extract device ID, IP, company, model name, and version

### Method 2: Nmap Script (Quick Scan)

For quick enumeration without Python dependencies:

```bash
nmap --script bacnet-info --script-args full=yes -sU -n -sV -p 47808 <TARGET_IP>
```

**What this does:**
- Sends BACnet requests directly to IP-addressable devices
- Does NOT attempt to join the BACnet network as a foreign device
- Extracts available device information

**Use the helper script:**
```bash
./scripts/bacnet-nmap.sh <TARGET_IP>
```

### Method 3: Shodan Search (External Recon)

For discovering publicly exposed BACnet devices:

**Basic search:**
```
port:47808 instance
```

**Vendor-specific search:**
```
"Instance ID" "Vendor Name"
```

**Example searches:**
- `port:47808 "Johnson Controls"`
- `port:47808 "Trane"`
- `port:47808 "Siemens"`

## Device Information Extracted

When enumerating BACnet devices, you can typically extract:

| Property | Description |
|----------|-------------|
| Device ID | Unique identifier for the device |
| IP Address | Network address of the device |
| Company ID | Vendor identifier |
| Model Name | Device model information |
| Version | Firmware/software version |
| Object Count | Number of BACnet objects |

## Common Use Cases

### 1. Initial Network Discovery
```bash
python3 scripts/bacnet-enumerate.py --ip "YOUR_IP/MASK"
```

### 2. Targeted Device Enumeration
```bash
./scripts/bacnet-nmap.sh 192.168.1.100
```

### 3. Comprehensive Assessment
- Run WHOIS broadcast to discover all devices
- Enumerate each device individually
- Document device types, versions, and vendors
- Identify potential security concerns

## Important Notes

- **Network Access Required**: You must be on the same subnet as the BACnet devices
- **UDP Protocol**: BACnet uses UDP port 47808, not TCP
- **Authorization**: Only enumerate devices you have permission to assess
- **Broadcast Traffic**: WHOIS requests generate broadcast traffic on the network
- **Device Response Time**: Allow 5+ seconds for devices to respond to WHOIS

## Troubleshooting

**No devices discovered:**
- Verify you're on the correct subnet
- Check firewall rules allowing UDP 47808
- Ensure BAC0 library is properly installed
- Try nmap as an alternative method

**Connection errors:**
- Verify network interface configuration
- Check that netifaces library is installed
- Ensure your IP address is correctly formatted (e.g., "192.168.1.4/24")

## Security Considerations

- BACnet devices often run on legacy systems with limited security
- Many devices have default credentials or no authentication
- Firmware versions may be outdated and vulnerable
- Document findings carefully for remediation
- Coordinate with facility management before testing

## References

- **Protocol Standard**: ASHRAE, ANSI, ISO 16484-5
- **BAC0 Library**: https://github.com/axegon/BAC0
- **Nmap BACnet Script**: https://nmap.org/nsedoc/scripts/bacnet-info.html
- **Shodan BACnet**: https://www.shodan.io/search?query=port:47808
