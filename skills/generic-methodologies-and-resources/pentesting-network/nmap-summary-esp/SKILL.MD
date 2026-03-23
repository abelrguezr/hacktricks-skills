---
name: nmap-scanner
description: How to use Nmap for network scanning, port discovery, service detection, and vulnerability assessment. Use this skill whenever the user needs to scan networks, discover hosts, enumerate ports, detect services, identify vulnerabilities, build static Nmap binaries for restricted environments, or optimize Nmap scan performance. Make sure to use this skill for any network reconnaissance, penetration testing, security auditing, or infrastructure discovery tasks involving Nmap, even if the user doesn't explicitly mention 'Nmap' or 'network scanning'.
---

# Nmap Scanner Skill

A comprehensive guide to using Nmap for network reconnaissance, port scanning, service detection, and vulnerability assessment.

## Quick Start

### Basic Scan Command
```bash
nmap -sV -sC -O -n -oA nmapscan <target>
```

**What this does:**
- `-sV`: Detect service versions
- `-sC`: Run default scripts
- `-O`: Enable OS detection
- `-n`: Skip DNS resolution
- `-oA`: Output in all formats (normal, XML, grepable)

### Common Scan Patterns

| Use Case | Command |
|----------|---------|
| Quick port scan | `nmap -F <target>` |
| Full port scan | `nmap -p- <target>` |
| Stealth scan | `nmap -sS <target>` |
| UDP scan | `nmap -sU <target>` |
| Aggressive scan | `nmap -A <target>` |
| No ping scan | `nmap -Pn <target>` |

## Target Specification

### Specify Targets

```bash
# Single IP
nmap 192.168.1.1

# IP range
nmap 192.168.1.1-100

# CIDR notation
nmap 192.168.1.0/24

# Multiple targets
nmap 192.168.1.1 192.168.1.2 192.168.1.3

# From file
nmap -iL targets.txt

# Random IPs
nmap -iR 10

# Exclude specific IPs
nmap --exclude 192.168.1.1,192.168.1.2 192.168.1.0/24
```

## Host Discovery

### Discovery Options

| Option | Description | Use When |
|--------|-------------|----------|
| `-sL` | List scan (DNS only) | Quick target enumeration |
| `-sn` | Ping scan (no port scan) | Find live hosts |
| `-Pn` | No ping (assume hosts up) | Hosts block ICMP |
| `-PR` | ARP ping | Local network scanning |
| `-PS <port>` | TCP SYN ping | Check specific ports |
| `-PA <port>` | TCP ACK ping | Firewall detection |
| `-PU <port>` | UDP ping | UDP service discovery |

### Discovery Examples

```bash
# ARP scan on local network
nmap -sn -PR 192.168.1.0/24

# TCP SYN ping on port 80
nmap -sn -PS80 192.168.1.0/24

# Assume all hosts are up (skip discovery)
nmap -Pn 192.168.1.0/24
```

## Port Scanning Techniques

### Scan Types

| Option | Name | Privileges | Description |
|--------|------|------------|-------------|
| `-sS` | SYN scan | Yes | Stealthy, default with root |
| `-sT` | TCP connect | No | Complete connection, works without root |
| `-sU` | UDP scan | Yes | Slower, for UDP services |
| `-sN` | NULL scan | Yes | No flags set |
| `-sF` | FIN scan | Yes | FIN flag only |
| `-sX` | Xmas scan | Yes | FIN+PSH+URG flags |
| `-sA` | ACK scan | Yes | Firewall mapping |
| `-sW` | Window scan | Yes | Distinguish open/closed |
| `-sY` | SCTP scan | Yes | SCTP protocol |
| `-sO` | IP protocol | Yes | Protocol scan |

### Port Selection

```bash
# Top 100 ports (fast)
nmap -F <target>

# Top 1000 ports (default)
nmap <target>

# All 65535 ports
nmap -p- <target>

# Specific ports
nmap -p 22,80,443 <target>

# Port range
nmap -p 1-1024 <target>

# Multiple protocols
nmap -p U:53,T:21-25,80,139,S:9 <target>

# Top N ports
nmap --top-ports 100 <target>

# Randomize port order
nmap -p- --randomize-hosts <target>

# Sequential port order
nmap -p- -r <target>
```

## Service and Version Detection

### Version Detection

```bash
# Basic version detection
nmap -sV <target>

# Version detection with intensity (0-9, default 7)
nmap -sV --version-intensity 5 <target>

# Aggressive version detection
nmap -sV --version-intensity 9 <target>
```

### Version Detection Intensity Levels

| Level | Description |
|-------|-------------|
| 0 | Only most probable probes |
| 1-3 | Increasing probe count |
| 7 | Default intensity |
| 9 | Maximum probes, longest time |

## Nmap Scripting Engine (NSE)

### Script Categories

| Category | Purpose | Safety |
|----------|---------|--------|
| `default` | Basic discovery | Safe |
| `safe` | Non-intrusive | Safe |
| `discovery` | Information gathering | Safe |
| `version` | Version detection | Safe |
| `auth` | Authentication testing | May be intrusive |
| `vuln` | Vulnerability detection | Safe |
| `exploit` | Exploitation | Intrusive |
| `dos` | Denial of service | Intrusive |
| `fuzzer` | Input fuzzing | Intrusive |
| `malware` | Malware detection | Safe |

### Using Scripts

```bash
# Run default scripts
nmap -sC <target>

# Run specific script
nmap --script http-title <target>

# Run script category
nmap --script=vuln <target>

# Run multiple scripts
nmap --script=http-title,http-server-header <target>

# Run all safe scripts
nmap --script=safe <target>

# Exclude intrusive scripts
nmap --script="not intrusive" <target>

# Complex script selection
nmap --script="(default or safe) and not http-*" <target>
```

### Script Arguments

```bash
# Pass arguments to scripts
nmap --script=http-headers --script-args http.useragent="Mozilla/5.0" <target>

# Load arguments from file
nmap --script=vulscan --script-args-file vuln-args.txt <target>

# Trace script execution
nmap --script-trace --script=http-title <target>
```

### Finding Scripts

```bash
# List all scripts
nmap --script-help=all

# Search by pattern
nmap --script-help="http-*"

# Get help for specific script
nmap --script-help=http-title

# List scripts by category
nmap --script-help=vuln
```

## OS Detection

### OS Detection Options

```bash
# Basic OS detection
nmap -O <target>

# Aggressive OS detection
nmap -O --osscan-guess <target>

# Limit OS detection (requires open + closed port)
nmap -O --osscan-limit <target>
```

### OS Detection Requirements

- At least one open TCP port
- At least one closed TCP port
- Root privileges for best results
- Works best on non-Windows systems

## Timing and Performance

### Timing Templates

| Template | Description | Use Case |
|----------|-------------|----------|
| `-T0` | Paranoid | Maximum stealth |
| `-T1` | Sneaky | Very slow, stealthy |
| `-T2` | Polite | Slower than normal |
| `-T3` | Normal | Default |
| `-T4` | Aggressive | Faster, may trigger IDS |
| `-T5` | Insane | Maximum speed, unreliable |

### Timing Control

```bash
# Set timing template
nmap -T4 <target>

# Host timeout (per host)
nmap --host-timeout 30m <target>

# Scan delay between probes
nmap --scan-delay 1s <target>

# Maximum scan delay
nmap --max-scan-delay 10s <target>

# Minimum/maximum packets per second
nmap --min-rate 100 --max-rate 1000 <target>

# Retry settings
nmap --max-retries 3 <target>

# RTT timeout settings
nmap --min-rtt-timeout 100ms --max-rtt-timeout 10s <target>
```

### Speed Optimization

```bash
# Defeat RST rate limiting (faster for filtered ports)
nmap --defeat-rst-ratelimit <target>

# Adjust host group size
nmap --min-hostgroup 256 --max-hostgroup 1024 <target>

# Adjust parallelism
nmap --min-parallelism 10 --max-parallelism 100 <target>
```

## Firewall and IDS Evasion

### Evasion Techniques

```bash
# Fragment packets
nmap -f <target>

# Fragment with specific MTU
nmap --mtu 16 <target>

# Use decoys
nmap -D 192.168.1.1,192.168.1.2,ME <target>

# Random decoys
nmap -D RND:10 <target>

# Spoof source IP
nmap -S 192.168.1.100 <target>

# Use specific interface
nmap -e eth0 <target>

# Spoof source port
nmap --source-port 53 <target>

# Spoof MAC address
nmap --spoof-mac Apple <target>

# Randomize host order
nmap --randomize-hosts <target>

# Set TTL
nmap --ttl 10 <target>
```

### Data Manipulation

```bash
# Send custom data (hex)
nmap --data "0xdeadbeef" <target>

# Send custom data (string)
nmap --data-string "Scan by Security Team" <target>

# Add random data length
nmap --data-length 100 <target>

# Set IP options
nmap --ip-options "S:192.168.1.1" <target>
```

## Output Formats

### Output Options

| Option | Format | Description |
|--------|--------|-------------|
| `-oN` | Normal | Human-readable |
| `-oX` | XML | Machine-readable |
| `-oG` | Greppable | Easy to parse |
| `-oA` | All | All formats (except -oS) |

### Output Examples

```bash
# All formats with same prefix
nmap -oA scan_results <target>

# Specific format
nmap -oX scan_results.xml <target>

# Append to existing file
nmap -oA - append_scan <target>
```

### Verbosity and Debugging

```bash
# Increase verbosity
nmap -v <target>
nmap -vv <target>
nmap -vvv <target>

# Enable debugging
nmap -d <target>
nmap -dd <target>

# Show reasons for state
nmap --reason <target>

# Show packet trace
nmap --packet-trace <target>

# Show version trace
nmap --version-trace <target>

# Show script trace
nmap --script-trace <target>

# Show progress stats
nmap --stats-every 1m <target>
```

## Vulscan (Vulnerability Scanning)

### Vulscan Usage

```bash
# Run vulscan with all databases
sudo nmap -sV --script=vulscan <target>

# Run vulscan with specific database
sudo nmap -sV --script=vulscan --script-args vulscandb=cve.csv <target>

# Run vulscan with multiple databases
sudo nmap -sV --script=vulscan --script-args vulscandb=cve.csv,scipvuldb.csv <target>
```

### Vulscan Databases

| Database | Source |
|----------|--------|
| `cve.csv` | MITRE CVE |
| `scipvuldb.csv` | SCIP Vulnerability DB |
| `osvdb.csv` | OSVDB |
| `securityfocus.csv` | SecurityFocus BID |
| `securitytracker.csv` | SecurityTracker |
| `xforce.csv` | IBM X-Force |
| `exploitdb.csv` | Exploit-DB |
| `openvas.csv` | OpenVAS |

## Advanced Features

### Traceroute

```bash
# Enable traceroute
nmap --traceroute <target>

# Traceroute with specific protocol
nmap --traceroute --traceroute-port 80 <target>
```

### IPv6

```bash
# Enable IPv6 scanning
nmap -6 <target>

# IPv6 with version detection
nmap -6 -sV <target>
```

### Resume Interrupted Scan

```bash
# Resume from previous scan
nmap --resume scan_results.xml
```

### Runtime Interaction

While Nmap is running, press:

| Key | Action |
|-----|--------|
| `v` | Increase verbosity |
| `V` | Decrease verbosity |
| `d` | Increase debugging |
| `D` | Decrease debugging |
| `p` | Toggle packet trace |
| `?` | Show help |

## Common Scan Recipes

### Quick Reconnaissance
```bash
nmap -sV -sC -O -n -oA quick_scan <target>
```

### Full Port Scan
```bash
nmap -p- -sV -sC -oA full_scan <target>
```

### Stealth Scan
```bash
nmap -sS -T2 -f -D RND:5 <target>
```

### Vulnerability Assessment
```bash
sudo nmap -sV -sC --script=vuln -oA vuln_scan <target>
```

### Web Service Scan
```bash
nmap -p 80,443,8080,8443 --script=http-* -sV <target>
```

### Database Scan
```bash
nmap -p 3306,5432,1433,27017,6379 --script=mysql-info,postgres-version,ms-sql-info,redis-info -sV <target>
```

### Network Discovery
```bash
nmap -sn -PR 192.168.1.0/24
```

### Aggressive Full Scan
```bash
nmap -A -T4 -oA aggressive_scan <target>
```

## Building Static Nmap for Restricted Environments

For hardened or minimal Linux environments (containers, appliances), use the bundled script to build a statically linked Nmap binary.

```bash
# Run the build script
./scripts/build-static-nmap.sh

# Output: nmap-linux-amd64-static-bundle.tar.gz
```

The bundle includes:
- Statically linked Nmap binary
- NSE scripts directory
- NSE data files (services, protocols, OS database, etc.)

## Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| Permission denied | Run with `sudo` |
| No route to host | Check network connectivity |
| Scan too slow | Use `-T4` or `-T5` |
| False negatives | Use `-Pn` to skip ping |
| Firewall blocking | Use `-f` or `-D` options |
| Missing scripts | Check NSE installation |
| Version detection fails | Increase `--version-intensity` |

### Debugging Tips

```bash
# Enable verbose output
nmap -vvv <target>

# Enable debugging
nmap -ddd <target>

# Trace packets
nmap --packet-trace <target>

# Show reasons
nmap --reason <target>
```

## Best Practices

1. **Always specify output format** - Use `-oA` to save results
2. **Use appropriate timing** - `-T3` for normal, `-T4` for faster
3. **Skip DNS when not needed** - Use `-n` for speed
4. **Test on authorized targets only** - Ensure you have permission
5. **Document your scans** - Include date, purpose, and scope
6. **Use scripts selectively** - Default scripts are usually sufficient
7. **Verify results** - Cross-check with manual testing
8. **Keep Nmap updated** - New scripts and features regularly added

## References

- [Nmap Official Documentation](https://nmap.org/book/)
- [Nmap Scripting Engine](https://nmap.org/book/nse.html)
- [Nmap Service Probes](https://nmap.org/book/nmap-service-probes.html)
- [Nmap Output Formats](https://nmap.org/book/output-formats.html)

## See Also

- `scripts/build-static-nmap.sh` - Build static Nmap binary
- `scripts/nmap-command-builder.sh` - Generate Nmap commands from requirements
