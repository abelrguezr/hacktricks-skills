---
name: pcap-inspection
description: Analyze PCAP files for forensic investigation, malware detection, and network traffic analysis. Use this skill whenever the user needs to inspect network captures, extract credentials, identify malicious activity, analyze DNS traffic, or investigate suspicious connections. Trigger for any PCAP/PCAPNG file analysis, network forensics tasks, or when examining captured network traffic for security investigations.
---

# PCAP Inspection

A comprehensive skill for analyzing PCAP (Packet Capture) files for forensic investigation, malware detection, and network traffic analysis.

## Quick Start

When given a PCAP file, follow this workflow:

1. **Validate and fix** the PCAP file if needed
2. **Extract basic information** using capinfos
3. **Choose analysis tools** based on your investigation goals
4. **Run targeted analysis** (credentials, malware, DNS, connections)
5. **Document findings**

## PCAP vs PCAPNG

> **Important**: PCAPNG is newer and not supported by all tools. If a tool fails to read your file, convert from PCAPNG to PCAP using Wireshark:
> ```bash
> tshark -r file.pcapng -w file.pcap
> ```

## Step 1: Validate and Fix PCAP

If the PCAP header is broken, fix it first:

```bash
# Online fixer (for small files)
# Visit: http://f00l.de/hacking/pcapfix.php

# Or use tshark to convert/repair
tshark -r broken.pcap -w fixed.pcap
```

## Step 2: Extract Basic Information

Get quick stats about the capture:

```bash
# Basic file info
capinfos capture.pcap

# Quick packet count and duration
tshark -r capture.pcap -q -z io,stat,0
```

## Step 3: Choose Your Analysis Path

### For Credential Extraction

Use these tools to find usernames, passwords, and authentication data:

```bash
# BruteShark - comprehensive credential extraction
# Extracts HTTP, FTP, Telnet, IMAP, SMTP credentials
# Also extracts authentication hashes for Hashcat cracking
bruteshark -f capture.pcap

# PCredz - parse credentials from PCAP
# https://github.com/lgandx/PCredz
pcredz -f capture.pcap

# Wireshark - manual inspection
# Follow TCP streams, look for cleartext protocols
```

### For Malware Detection

```bash
# Suricata - signature-based detection
# First install and setup:
apt-get install suricata oinkmaster
echo "url = http://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz" >> /etc/oinkmaster.conf
oinkmaster -C /etc/oinkmaster.conf -o /etc/suricata/rules

# Then analyze:
suricata -r capture.pcap -c /etc/suricata/suricata.yaml -k none -v -l log/

# YaraPcap - scan extracted HTTP streams with YARA rules
# https://github.com/kevthehermit/YaraPcap
# Automatically extracts HTTP streams, decompresses gzip, scans with YARA
```

### For Network Traffic Analysis (Zeek)

Zeek is a passive network traffic analyzer. Run it first, then analyze the logs:

```bash
# Generate Zeek logs from PCAP
zeek -r capture.pcap

# Analyze the generated logs (see below for specific queries)
```

### For File Extraction

```bash
# Xplico - extract files from PCAP (Linux only)
# Installs web interface at 127.0.0.1:9876 (xplico:xplico)
sudo apt-get install xplico
/etc/init.d/xplico start
# Then access web UI, create case, upload PCAP

# NetworkMiner - Windows tool for file extraction
# Download from: https://www.netresec.com/?page=NetworkMiner

# Wireshark - File > Export Objects > HTTP, SMB, etc.
```

## Step 4: Zeek Analysis Commands

After running `zeek -r capture.pcap`, analyze the generated logs:

### Connection Analysis

```bash
# Longest connections (potential reverse shells)
cat conn.log | zeek-cut id.orig_h id.orig_p id.resp_h id.resp_p proto service duration | sort -nrk 7 | head -n 10

# Sum duration by destination IP:Port
cat conn.log | zeek-cut id.orig_h id.resp_h id.resp_p proto duration | awk 'BEGIN{ FS="\t" } { arr[$1 FS $2 FS $3 FS $4] += $5 } END{ for (key in arr) printf "%s%s%s\n", key, FS, arr[key] }' | sort -nrk 5 | head -n 10

# Connection count per IP pair
cat conn.log | zeek-cut id.orig_h id.resp_h duration | awk 'BEGIN{ FS="\t" } { arr[$1 FS $2] += $3; count[$1 FS $2] += 1 } END{ for (key in arr) printf "%s%s%s%s%s\n", key, FS, count[key], FS, arr[key] }' | sort -nrk 4 | head -n 10

# Check connections to specific IP
cat conn.log | zeek-cut id.orig_h id.resp_h id.resp_p proto service | grep '1.1.1.1' | sort | uniq -c
```

### DNS Analysis

```bash
# All DNS queries with answers
cat dns.log | zeek-cut -c id.orig_h query qtype_name answers

# Top 10 domains requested
cat dns.log | zeek-cut query | sort | uniq | rev | cut -d '.' -f 1-2 | rev | sort | uniq -c | sort -nr | head -n 10

# IPs for specific domain
cat dns.log | zeek-cut id.orig_h query | grep 'example\.com' | cut -f 1 | sort | uniq -c

# Most common DNS record types
cat dns.log | zeek-cut qtype_name | sort | uniq -c | sort -nr
```

### Using RITA (if available)

```bash
# Long connections
rita show-long-connections -H --limit 10 zeek_logs

# Beacon detection
rita show-beacons zeek_logs | head -n 10

# DNS analysis
rita show-exploded-dns -H --limit 10 zeek_logs
```

## Step 5: Pattern-Specific Searches

### Search for specific content in PCAP

```bash
# Ngrep - search for patterns in PCAP
ngrep -I capture.pcap "^GET" "port 80 and tcp"

# Search for specific strings
tshark -r capture.pcap -Y "http contains \"password\""

# Find all HTTP requests
tshark -r capture.pcap -Y "http.request" -T fields -e http.host -e http.request.uri
```

### Identify suspicious patterns

```bash
# Unusual ports
tshark -r capture.pcap -Y "tcp.port not in {80,443,22,21,25,53,110,143,993,995}" -T fields -e ip.src -e ip.dst -e tcp.dstport

# Large transfers
tshark -r capture.pcap -Y "frame.len > 10000" -T fields -e ip.src -e ip.dst -e frame.len

# DNS over unusual ports (potential tunneling)
tshark -r capture.pcap -Y "udp.port != 53 and dns" -T fields -e ip.src -e ip.dst -e udp.dstport
```

## Online Analysis Tools

For quick analysis without installing tools:

| Tool | Purpose | URL |
|------|---------|-----|
| PacketTotal | Extract info, search for malware | https://packettotal.com |
| VirusTotal | Search for malicious activity | https://www.virustotal.com |
| Hybrid Analysis | Malicious activity detection | https://www.hybrid-analysis.com |
| APackets | Full PCAP analysis in browser | https://apackets.com/ |

## Tool Selection Guide

| Goal | Recommended Tools |
|------|-------------------|
| Quick overview | capinfos, tshark -q |
| Credential extraction | BruteShark, PCredz, Wireshark |
| Malware detection | Suricata, YaraPcap, VirusTotal |
| File extraction | Xplico, NetworkMiner, Wireshark |
| Network analysis | Zeek, RITA, Wireshark |
| DNS investigation | Zeek dns.log, tshark |
| Connection analysis | Zeek conn.log, RITA |
| Pattern searching | ngrep, tshark with display filters |

## Common Investigation Scenarios

### Scenario 1: Suspicious Network Activity

1. Run Zeek on the PCAP
2. Check `conn.log` for longest connections (potential C2)
3. Check `dns.log` for unusual domains
4. Run Suricata for known malware signatures
5. Extract files with Xplico/NetworkMiner

### Scenario 2: Credential Theft Investigation

1. Run BruteShark for automated credential extraction
2. Use PCredz for additional parsing
3. In Wireshark, follow TCP streams on ports 21, 23, 25, 110, 143
4. Search for HTTP POST requests with form data
5. Look for NTLM/Kerberos authentication in tshark

### Scenario 3: Data Exfiltration Detection

1. Analyze `conn.log` for large data transfers
2. Check DNS logs for DNS tunneling patterns
3. Look for connections to unusual ports
4. Extract and analyze transferred files
5. Check for beaconing patterns with RITA

## Best Practices

1. **Always validate PCAP integrity** before analysis
2. **Work on copies** of original captures
3. **Document your findings** with timestamps and tool versions
4. **Use multiple tools** - different tools catch different things
5. **Start broad, then narrow** - get overview before deep diving
6. **Check both directions** - analyze traffic to and from hosts
7. **Look for anomalies** - what's unusual in this capture?

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Tool won't read PCAP | Convert PCAPNG to PCAP with tshark |
| Broken PCAP header | Use pcapfix.php or tshark to repair |
| Missing protocols | Install protocol dissecters for Wireshark |
| Slow analysis | Use tshark filters to reduce scope |
| Large files | Split with tshark or use sampling |

## References

- Wireshark documentation: https://www.wireshark.org/docs/
- Zeek documentation: https://docs.zeek.org/
- Suricata rules: https://suricata.io/open-source/
- BruteShark: https://github.com/odedshimon/BruteShark
- Xplico: https://github.com/xplico/xplico
