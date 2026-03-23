---
name: macos-network-security
description: macOS network security assessment and hardening. Use this skill whenever the user mentions macOS security, network services, remote access (VNC, SSH, ARD, Screen Sharing), Bonjour, mDNS, service enumeration, privilege escalation, or security vulnerabilities. Trigger for any macOS security assessment, hardening recommendations, or network protocol analysis tasks.
---

# macOS Network Security Assessment & Hardening

This skill helps you assess, understand, and harden macOS network services and protocols. It covers remote access services, service discovery protocols, known vulnerabilities, and security best practices.

## Quick Reference

### Remote Access Services

| Service | Port | System Name | Check Command |
|---------|------|-------------|---------------|
| VNC/Screen Sharing | 5900/tcp | Screen Sharing | `netstat -na | grep LISTEN | grep 5900` |
| SSH | 22/tcp | Remote Login | `netstat -na | grep LISTEN | grep 22` |
| Apple Remote Desktop (ARD) | 3283/tcp | Remote Management | `netstat -na | grep LISTEN | grep 3283` |
| AppleEvent | 3031/tcp | Remote Apple Event | `netstat -na | grep LISTEN | grep 3031` |
| File Sharing | 88, 445, 548/tcp | File Sharing | `netstat -na | grep LISTEN | grep -E '88|445|548'` |
| Back to My Mac | 4488/tcp | Back to My Mac | `netstat -na | grep LISTEN | grep 4488` |

### Service Discovery Protocols

| Protocol | Port | Purpose |
|----------|------|----------|
| mDNS (Multicast DNS) | 5353/UDP | Name resolution without DNS server |
| DNS-SD (DNS Service Discovery) | 5353/UDP | Service discovery on local network |
| Bonjour | 5353/UDP | Apple's Zero Configuration Networking |

## Service Enumeration

### Check All Remote Services Status

Run this script to check which remote services are enabled:

```bash
# Check remote services status
rmMgmt=$(netstat -na | grep LISTEN | grep tcp46 | grep "*.3283" | wc -l)
scrShrng=$(netstat -na | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.5900" | wc -l)
flShrng=$(netstat -na | grep LISTEN | egrep 'tcp4|tcp6' | egrep "\\*.88|\\*.445|\\*.548" | wc -l)
rLgn=$(netstat -na | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.22" | wc -l)
rAE=$(netstat -na | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.3031" | wc -l)
bmM=$(netstat -na | grep LISTEN | egrep 'tcp4|tcp6' | grep "*.4488" | wc -l)
printf "\nService Status (0=OFF, >0=ON):\n"
printf "Screen Sharing: %s\n" "$scrShrng"
printf "File Sharing: %s\n" "$flShrng"
printf "Remote Login (SSH): %s\n" "$rLgn"
printf "Remote Management (ARD): %s\n" "$rmMgmt"
printf "Remote Apple Events: %s\n" "$rAE"
printf "Back to My Mac: %s\n\n" "$bmM"
```

### Browse Bonjour Services

```bash
# Browse SSH services
dns-sd -B _ssh._tcp

# Browse HTTP services
dns-sd -B _http._tcp

# Browse all services
dns-sd -B _services._dns-sd._udp.local
```

### Network Scanning

```bash
# Nmap - discover mDNS services on a host
nmap -sU -p 5353 --script=dns-service-discovery <target>

# mdns_recon - scan subnet for misconfigured mDNS responders
python3 mdns_recon.py -r 192.168.1.0/24 -s _ssh._tcp.local
```

## Security Vulnerabilities

### Recent Screen Sharing / ARD Vulnerabilities

| Year | CVE | Impact | Fixed In |
|------|-----|--------|----------|
| 2023 | CVE-2023-42940 | Session rendering leak - wrong desktop transmitted | macOS Sonoma 14.2.1 |
| 2024 | CVE-2024-23296 | Kernel memory bypass after remote login | macOS Ventura 13.6.4 / Sonoma 14.4 |

### Recent Bonjour/mDNS Vulnerabilities

| Year | CVE | Severity | Impact | Fixed In |
|------|-----|----------|--------|----------|
| 2024 | CVE-2024-44183 | Medium | DoS via crafted mDNS packet | Ventura 13.7 / Sonoma 14.7 / Sequoia 15.0 |
| 2025 | CVE-2025-31222 | High | Local privilege escalation | Ventura 13.7.6 / Sonoma 14.7.6 / Sequoia 15.5 |

### ARD Security Concerns

**Critical**: ARD uses only the first 8 characters of the VNC password for authentication, making it vulnerable to brute force attacks with no default rate limiting.

**Detection**: Use nmap's `vnc-info` script to identify vulnerable instances:
```bash
nmap --script vnc-info -p 5900 <target>
```

Services supporting `VNC Authentication (2)` are especially susceptible.

## Hardening Recommendations

### 1. Disable Unnecessary Remote Services

```bash
# Disable Screen Sharing
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -deactivate

# Disable Remote Login (SSH)
sudo launchctl unload -w /System/Library/LaunchDaemons/ssh.plist

# Disable Bonjour (if not needed)
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.mDNSResponder.plist
```

### 2. Firewall Rules for ARD

If ARD must be enabled, restrict it to local subnet:

```bash
# Add ARDAgent to Application Firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/MacOS/ARDAgent

# Block ARDAgent by default
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockapp /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/MacOS/ARDAgent on
```

### 3. Network-Level Protections

- **Restrict UDP 5353** to link-local scope on routers and firewalls
- **Block or rate-limit** mDNS traffic on wireless controllers
- **Use mDNS proxy** to prevent cross-subnet service discovery
- **Put remote services behind VPN** instead of exposing to Internet

### 4. System Hardening

- **Enable System Integrity Protection (SIP)** - critical for full vulnerability protection
- **Keep macOS fully patched** - Apple supports last 3 major releases
- **Use strong passwords** - especially for VNC/ARD (8+ chars minimum)
- **Disable "VNC viewers may control screen with password"** when possible

### 5. MDM Restrictions (Enterprise)

For environments requiring Bonjour internally but not across boundaries:
- Use **AirPlay Receiver profile restrictions** via MDM
- Deploy **mDNS proxy** solutions
- Configure **network segmentation** to isolate service discovery

## Assessment Workflow

### Step 1: Enumerate Services

1. Check local listening ports
2. Browse local Bonjour services
3. Scan network for exposed services

### Step 2: Identify Vulnerabilities

1. Check macOS version against CVE table
2. Test ARD for weak authentication
3. Verify mDNS responder configuration

### Step 3: Apply Hardening

1. Disable unnecessary services
2. Configure firewall rules
3. Update system and verify patches
4. Document remaining services and justification

## Tools Reference

| Tool | Purpose | Command |
|------|---------|----------|
| `netstat` | Port enumeration | `netstat -na | grep LISTEN` |
| `dns-sd` | Bonjour service discovery | `dns-sd -B _service._tcp` |
| `nmap` | Network scanning | `nmap -sU -p 5353 --script=dns-service-discovery` |
| `mdns_recon` | mDNS reconnaissance | `python3 mdns_recon.py -r <range>` |
| `socketfilterfw` | Application Firewall | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw` |

## When to Use This Skill

Use this skill when you need to:
- Assess macOS network security posture
- Enumerate remote access services on macOS
- Understand Bonjour/mDNS protocol behavior
- Identify and remediate macOS network vulnerabilities
- Harden macOS systems against network-based attacks
- Investigate privilege escalation via network services
- Configure secure remote access on macOS
- Audit macOS systems for compliance

## References

- [The Mac Hacker's Handbook](https://www.amazon.com/-/es/Charlie-Miller-ebook-dp-B004U7MUMU/dp/B004U7MUMU)
- [TAOMM - The Art of Mac Malware](https://taomm.org/vol1/analysis.html)
- [macOS Red Teaming - ARD](https://lockboxx.blogspot.com/2019/07/macos-red-teaming-206-ard-apple-remote.html)
- [NVD - CVE Database](https://nvd.nist.gov/)
