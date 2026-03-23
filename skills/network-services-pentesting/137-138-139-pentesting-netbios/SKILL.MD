---
name: netbios-enumeration
description: Enumerate NetBIOS services (ports 137, 138, 139) to discover server names, workgroups, and MAC addresses during network pentesting. Use this skill whenever you need to enumerate NetBIOS services, discover Windows/Samba shares, investigate network name resolution, or assess NetBIOS security. Trigger this skill for any task involving NetBIOS ports, Windows network enumeration, or SMB-related reconnaissance.
---

# NetBIOS Enumeration

## Overview

NetBIOS provides three core services for network communication:

| Service | Port | Protocol | Purpose |
|---------|------|----------|----------|
| Name Service | 137 | UDP/TCP | Name registration and resolution |
| Datagram Distribution | 138 | UDP | Connectionless communication |
| Session Service | 139 | TCP | Connection-oriented communication |

## Quick Start

```bash
# Enumerate NetBIOS names and MAC addresses
nmblookup -A <IP>

# Scan a subnet for NetBIOS hosts
nbtscan <IP>/30

# Nmap enumeration with nbstat script
nmap -sU -sV -T4 --script nbstat.nse -p137 -Pn -n <IP>
```

## Detailed Enumeration

### Name Service (Port 137)

The Name Service handles name registration and resolution. Devices participate in a NetBIOS network through a broadcast process where "Name Query" packets are sent. If no objections are received, the name is considered available.

**Commands:**

```bash
# Query a specific host for NetBIOS names
nmblookup -A <IP>

# Scan a subnet range
nbtscan <IP>/30

# Nmap with nbstat.nse script (most comprehensive)
nmap -sU -sV -T4 --script nbstat.nse -p137 -Pn -n <IP>
```

**What you'll discover:**
- Computer/Server names
- Workgroup or domain membership
- MAC address of the network interface
- User names (sometimes visible)
- NetBIOS service types

### Datagram Distribution Service (Port 138)

NetBIOS datagrams allow for connectionless communication via UDP, supporting direct messaging or broadcasting to all network names.

**Check if open:**
```bash
nmap -sU -p138 <IP>
```

### Session Service (Port 139)

The Session Service facilitates connection-oriented interactions between two devices using TCP. A session begins with a "Session Request" packet and supports larger messages, error detection, and recovery.

**Check if open:**
```bash
nmap -sT -p139 <IP>
```

## What to Look For

When enumerating NetBIOS, pay attention to:

1. **Computer names** - The NetBIOS name of the target system
2. **Workgroup/Domain** - Network membership information
3. **MAC address** - Physical network interface identifier
4. **Service types** - What NetBIOS services are running
5. **User accounts** - Sometimes visible in enumeration output

## Common Nmap Findings

```
PORT    STATE SERVICE    VERSION
137/udp open  netbios-ns Samba nmbd netbios-ns (workgroup: WORKGROUP)
138/udp open|filtered netbios-dgm
139/tcp open  netbios-ssn  Microsoft Windows netbios-ssn
```

## Next Steps After Enumeration

Once you've enumerated NetBIOS services, consider:

1. **Check SMB vulnerabilities** - Port 445 often accompanies NetBIOS
2. **Attempt null sessions** - Anonymous SMB connections
3. **Look for password hashes** - LanMan/NTLM hashes may be accessible
4. **Investigate share access** - Enumerate and access network shares
5. **Check for misconfigurations** - Anonymous access, weak permissions

## Automation Script

For repeated enumeration tasks, use the bundled script:

```bash
./scripts/netbios-enumerate.sh <IP>
```

This runs all three enumeration methods and saves results to a file.

## References

- [HackTricks NetBIOS Pentesting](https://book.hacktricks.wiki/en/network-services-pentesting/137-138-139-pentesting-netbios.html)
- [NetBIOS over TCP/IP - Wikipedia](https://en.wikipedia.org/wiki/NetBIOS_over_TCP/IP)
