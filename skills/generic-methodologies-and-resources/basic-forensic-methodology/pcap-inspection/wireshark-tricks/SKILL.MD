---
name: wireshark-pcap-analysis
description: Analyze PCAP files with Wireshark for network forensics. Use this skill whenever the user mentions PCAP files, network traffic analysis, Wireshark, packet inspection, TLS decryption, or needs to extract data from network captures. This skill covers statistics analysis, filtering, domain identification, hostname resolution, and traffic decryption.
---

# Wireshark PCAP Analysis

A skill for analyzing network packet captures using Wireshark for forensic investigation.

## Quick Start

1. Open your PCAP file in Wireshark
2. Use the statistics menus to get an overview
3. Apply filters to focus on relevant traffic
4. Extract and decrypt data as needed

## Statistics Overview

### Expert Information
Navigate to **Analyze → Expert Information** to get an overview of errors, warnings, and notable events in the captured packets.

### Resolved Addresses
Check **Statistics → Resolved Addresses** to see protocol mappings, MAC vendor information, and resolved hostnames.

### Protocol Hierarchy
Use **Statistics → Protocol Hierarchy** to understand the protocol distribution and data volume across different layers.

### Conversations
Review **Statistics → Conversations** to identify communication patterns between endpoints and data transfer volumes.

### Endpoints
Examine **Statistics → Endpoints** to see all IP addresses, MAC addresses, and their associated traffic statistics.

### DNS Statistics
Access **Statistics → DNS** to analyze DNS queries and responses captured in the traffic.

### I/O Graph
Generate **Statistics → I/O Graph** to visualize traffic patterns and identify anomalies over time.

## Common Filters

Filter for HTTP and HTTPS traffic:
```
(http.request or ssl.handshake.type == 1) and !(udp.port eq 1900)
```

Add TCP SYN packets:
```
(http.request or ssl.handshake.type == 1 or tcp.flags eq 0x0002) and !(udp.port eq 1900)
```

Include DNS queries:
```
(http.request or ssl.handshake.type == 1 or tcp.flags eq 0x0002 or dns) and !(udp.port eq 1900)
```

For complete filter reference, see: https://www.wireshark.org/docs/dfref/

## Domain Identification

### Add Host Header Column
Right-click the column header → Edit Columns → Add a column for the HTTP Host header to identify requested domains.

### Extract SNI from TLS
Add a column for `ssl.handshake.type == 1` to capture Server Name Indication from HTTPS connections.

## Hostname Resolution

### From DHCP
Search for `DHCP` packets to find hostname assignments (note: older tutorials reference `bootp`, but modern Wireshark uses `DHCP`).

### From NBNS
Search for NBNS (NetBIOS Name Service) traffic to identify local hostnames on the network.

## TLS Decryption

### Method 1: Server Private Key
1. Go to **Edit → Preferences → Protocols → SSL**
2. Click Edit and add:
   - IP address
   - Port
   - Protocol
   - Key file path
   - Password (if encrypted)

### Method 2: Session Keys (Browser-based)
1. Set environment variable `SSLKEYLOGFILE` in the browser to a file path
2. Browse to generate the key log file
3. In Wireshark: **Edit → Preferences → Protocols → SSL**
4. Set "(Pre)-Master-Secret log filename" to the key log file path

This works with Firefox and Chrome to decrypt TLS traffic for analysis.

## ADB Communication Extraction

To extract APK files from ADB packet captures, use the bundled script:

```
scripts/extract_adb_apk.py <pcap-file>
```

This script parses ADB WRTE commands and reconstructs the transferred data.

## Search Tips

- Press **Ctrl+F** to search for content inside packet payloads
- Right-click column headers to add custom layers to the main information bar
- Use display filters to narrow down to specific protocols or hosts

## Practice Resources

- Free PCAP challenges: https://www.malware-traffic-analysis.net/
- Wireshark filter reference: https://www.wireshark.org/docs/dfref/
- Unit42 Wireshark tutorials:
  - Customizing columns: https://unit42.paloaltonetworks.com/unit42-customizing-wireshark-changing-column-display/
  - Display filters: https://unit42.paloaltonetworks.com/using-wireshark-display-filter-expressions/
  - Identifying hosts: https://unit42.paloaltonetworks.com/using-wireshark-identifying-hosts-and-users/
  - Exporting objects: https://unit42.paloaltonetworks.com/using-wireshark-exporting-objects-from-a-pcap/
