---
name: suricata-iptables-forensics
description: Configure and use Suricata IDS/IPS and iptables for network security forensics. Use this skill whenever you need to set up network intrusion detection, create firewall rules, write Suricata signatures, block suspicious traffic, analyze network packets, or configure network security monitoring. Trigger this skill for any task involving iptables chains, Suricata rules, network filtering, packet inspection, or security rule creation.
---

# Suricata & Iptables Forensics Skill

This skill helps you configure and use Suricata (IDS/IPS) and iptables for network security forensics and monitoring.

## Quick Start

### Iptables Basics

Iptables uses chains to process rules sequentially. Three primary chains are always present:

- **INPUT**: Incoming connections to the local system
- **FORWARD**: Traffic passing through (routers, NAT)
- **OUTPUT**: Outgoing connections from the system

### Common Iptables Commands

```bash
# Delete all rules
iptables -F

# List all rules
iptables -L
iptables -S

# Block IP addresses
iptables -I INPUT -s 192.168.1.100 -j DROP
iptables -I INPUT -s 10.0.0.5,10.0.0.6 -j DROP

# Block ports
iptables -I INPUT -p tcp --dport 443 -j DROP
iptables -I INPUT -p tcp --dport 8000 -j DROP

# Block specific IP on specific port
iptables -I INPUT -s 192.168.1.100 -p tcp --dport 443 -j DROP

# String-based drop (case sensitive)
iptables -I INPUT -p tcp --dport 80 -m string --algo bm --string 'CTF{' -j DROP
iptables -I OUTPUT -p tcp --sport 80 -m string --algo bm --string 'CTF{' -j DROP

# Default drop, allow specific ports
iptables -P INPUT DROP
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
```

### Persist Iptables Rules

**Debian/Ubuntu:**
```bash
apt-get install iptables-persistent
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6
iptables-restore < /etc/iptables/rules.v4
```

**RHEL/CentOS:**
```bash
iptables-save > /etc/sysconfig/iptables
ip6tables-save > /etc/sysconfig/ip6tables
iptables-restore < /etc/sysconfig/iptables
```

## Suricata Setup

### Installation

**Ubuntu:**
```bash
add-apt-repository ppa:oisf/suricata-stable
apt-get update
apt-get install suricata
```

**Debian:**
```bash
echo "deb http://http.debian.net/debian buster-backports main" > /etc/apt/sources.list.d/backports.list
apt-get update
apt-get install suricata -t buster-backports
```

**CentOS:**
```bash
yum install epel-release
yum install suricata
```

### Get and Configure Rules

```bash
# Get rules
suricata-update
suricata-update list-sources
suricata-update enable-source et/open
suricata-update

# Update /etc/suricata/suricata.yaml:
default-rule-path: /var/lib/suricata/rules
rule-files:
  - suricata.rules
```

### Run Suricata

```bash
# Start service
systemctl suricata start

# Run manually on interface
suricata -c /etc/suricata/suricata.yaml -i eth0

# Validate config
suricata -T -c /etc/suricata/suricata.yaml -v

# Reload rules
suricatasc -c ruleset-reload-nonblocking
```

### Configure as IPS (Inline Mode)

1. Edit `/etc/suricata/suricata.yaml` - find and uncomment:
```yaml
drop:
  alerts: yes
  flows: all
```

2. Forward packets to Suricata queue:
```bash
iptables -I INPUT -j NFQUEUE
iptables -I OUTPUT -j NFQUEUE
```

3. Start Suricata in IPS mode:
```bash
suricata -c /etc/suricata/suricata.yaml -q 0
```

Or edit the service:
```bash
systemctl edit suricata.service
```

Add:
```ini
[Service]
ExecStart=
ExecStart=/usr/bin/suricata -c /etc/suricata/suricata.yaml --pidfile /run/suricata.pid -q 0 -vvv
Type=simple
```

Then:
```bash
systemctl daemon-reload
systemctl restart suricata
```

## Writing Suricata Rules

### Rule Structure

A Suricata rule has three parts:
1. **Action**: What to do when matched (alert, drop, pass, reject)
2. **Header**: Protocol, IPs, ports, direction
3. **Options**: Specific matching criteria

### Valid Actions

| Action | Description |
|--------|-------------|
| `alert` | Generate an alert |
| `pass` | Stop further inspection |
| `drop` | Drop packet and generate alert |
| `reject` | Send RST/ICMP error to sender |
| `rejectsrc` | Same as reject |
| `rejectdst` | Send error to receiver |
| `rejectboth` | Send errors to both sides |

### Protocols

- `tcp`, `udp`, `icmp`, `ip` (any/all)
- Layer 7: `http`, `ftp`, `tls`, `smb`, `dns`, `ssh`

### IP Address Syntax

| Example | Meaning |
|---------|--------|
| `!1.1.1.1` | Every IP except 1.1.1.1 |
| `![1.1.1.1, 1.1.1.2]` | Every IP except these two |
| `$HOME_NET` | Defined in yaml config |
| `[$EXTERNAL_NET, !$HOME_NET]` | External but not home |
| `[10.0.0.0/24, !10.0.0.5]` | Subnet except one IP |

### Port Syntax

| Example | Meaning |
|---------|--------|
| `any` | Any port |
| `[80, 81, 82]` | Ports 80, 81, 82 |
| `[80:82]` | Range 80-82 |
| `[1024:]` | 1024 and above |
| `!80` | Every port except 80 |
| `[80:100,!99]` | 80-100 except 99 |

### Direction

```
source -> destination  (one way)
source <> destination  (both ways)
```

### Common Keywords

**Meta Keywords:**
```bash
msg: "description"           # Rule description
sid: 123                     # Unique rule ID
rev: 1                       # Revision number
classtype: bad-unknown       # Classification
reference: url, www.info.com # Reference URL
priority: 1                  # Priority level
```

**Content Matching:**
```bash
content: "something"         # String match
content: |61 61 61|          # Hex: AAA
content: "http|3A|//"        # Mixed string/hex
content: "abc"; nocase;      # Case insensitive
```

**Replace (IPS mode):**
```bash
content: "abc"; replace: "def"  # Must be same length
```

**Regex:**
```bash
pcre: "/<regex>/opts"
pcre: "/NICK .*USA.*[0-9]{3,}/i"
```

**Geolocation:**
```bash
geoip: src,RU  # Match source from Russia
```

**ICMP:**
```bash
itype: <10    # ICMP type less than 10
icode: 0      # ICMP code
```

## Rule Examples

### Basic Alert
```bash
alert http $HOME_NET any -> $EXTERNAL_NET any (
  msg:"HTTP GET Request Containing Rule in URI";
  flow:established,to_server;
  http.method; content:"GET";
  http.uri; content:"rule";
  fast_pattern;
  classtype:bad-unknown;
  sid:123;
  rev:1;
)
```

### Drop by Port
```bash
drop tcp any any -> any 8000 (
  msg:"Block port 8000";
  sid:1000;
)
```

### String Detection
```bash
alert tcp any any -> any any (
  msg:"PHP RCE Attempt";
  content:"eval";
  nocase;
  metadata: tag php-rce;
  sid:101;
  rev:1;
)
```

### Regex Detection
```bash
drop tcp any any -> any any (
  msg:"CTF Flag Pattern";
  pcre:"/CTF\{[\w]{3,}/i";
  sid:10001;
)
```

### Content Replace
```bash
alert tcp any any -> any any (
  msg:"Flag Replace";
  content:"CTF{a6st";
  replace:"CTF{u798";
  nocase;
  sid:100;
  rev:1;
)
```

## Common Use Cases

### Block CTF Flag Exfiltration
```bash
# Iptables
iptables -I OUTPUT -p tcp -m string --algo bm --string 'CTF{' -j DROP

# Suricata
drop tcp any any -> any any (
  msg:"CTF Flag Exfiltration";
  pcre:"/CTF\{[\w\-]{3,}/i";
  sid:20001;
)
```

### Block SQL Injection Attempts
```bash
alert http any any -> any any (
  msg:"SQL Injection Attempt";
  http.method; content:"GET";
  http.uri; content:"'"; content:"OR"; nocase;
  classtype:web-application-attack;
  sid:30001;
)
```

### Allowlist Specific IPs
```bash
iptables -P INPUT DROP
iptables -I INPUT -s 192.168.1.0/24 -j ACCEPT
iptables -I INPUT -s 10.0.0.0/8 -j ACCEPT
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
```

## Troubleshooting

### Suricata
```bash
# Check status
systemctl status suricata

# View logs
tail -f /var/log/suricata/eve.json

# Test config
suricata -T -c /etc/suricata/suricata.yaml -v

# Check rule syntax
suricata -T -c /etc/suricata/suricata.yaml
```

### Iptables
```bash
# Count matches
iptables -L -v -n

# Save current rules
iptables-save > /tmp/backup.rules

# Restore from backup
iptables-restore < /tmp/backup.rules

# Flush all rules (careful!)
iptables -F
```

## Best Practices

1. **Test rules before deploying** - Use `alert` before `drop` to verify matching
2. **Use descriptive messages** - Include context in `msg:` field
3. **Set unique SIDs** - Avoid conflicts with existing rules
4. **Document rule purpose** - Add comments or metadata
5. **Monitor false positives** - Review alerts before enabling drop actions
6. **Backup before changes** - Save iptables rules before modifying
7. **Use fast_pattern** - For performance on frequently matched content
8. **Test in staging** - Validate IPS rules before production deployment
