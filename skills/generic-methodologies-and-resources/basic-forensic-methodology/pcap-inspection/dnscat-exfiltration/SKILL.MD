---
name: dnscat-exfiltration-extractor
description: Extract exfiltrated data from DNSCat traffic in pcap files. Use this skill whenever the user mentions DNSCat, DNS exfiltration, C2 over DNS, or needs to analyze pcap files for DNS-based data theft. This skill decodes hex-encoded DNS subdomains and strips the 9-byte C&C header to recover the original exfiltrated content.
---

# DNSCat Exfiltration Extractor

This skill extracts data that was exfiltrated via DNSCat protocol from pcap files. DNSCat is a C2 framework that tunnels data over DNS queries, encoding the payload in hex within subdomain names.

## When to Use This Skill

Use this skill when:
- You have a pcap file and suspect DNSCat-based exfiltration
- The user mentions DNSCat, DNS tunneling, or DNS-based C2
- You need to recover data from DNS queries to a suspicious domain
- Forensic analysis reveals DNS queries with hex-encoded subdomains

## How DNSCat Exfiltration Works

DNSCat encodes exfiltrated data as hex strings in DNS subdomain queries. The protocol adds a 9-byte header for C&C communication that must be stripped to recover the actual data.

## Extraction Process

### Step 1: Identify the C2 Domain

First, identify the domain used for DNSCat communication. This is typically:
- A suspicious domain in the pcap
- A domain with many DNS queries containing hex-like subdomains
- Specified by the user

### Step 2: Run the Extraction Script

Use the bundled script to extract the data:

```bash
python3 scripts/dnscat_extractor.py <pcap_file> <c2_domain>
```

**Arguments:**
- `<pcap_file>`: Path to the pcap file containing DNSCat traffic
- `<c2_domain>`: The C2 domain (e.g., `jz-n-bs.local` or `bad_domain`)

**Example:**
```bash
python3 scripts/dnscat_extractor.py ch21.pcap jz-n-bs.local
```

### Step 3: Review the Output

The script outputs:
- Each chunk of exfiltrated data as it's decoded
- The complete reconstructed payload at the end
- Statistics about the extraction (number of queries, bytes recovered)

## Technical Details

### Protocol Structure

1. **DNS Query Format**: `hex_data.c2_domain.tld`
2. **Header**: First 9 bytes are C&C protocol overhead (not actual data)
3. **Payload**: Remaining bytes contain the exfiltrated content
4. **Encoding**: Hex-encoded ASCII/bytes

### Decoding Process

1. Parse DNS queries from the pcap
2. Filter for queries to the C2 domain
3. Extract subdomain components
4. Decode hex strings
5. Strip the 9-byte header from the first chunk
6. Concatenate all chunks in order

## Common Use Cases

### Forensic Investigation
```bash
# Analyze captured traffic for exfiltration
python3 scripts/dnscat_extractor.py network_capture.pcap suspicious-domain.com
```

### CTF Challenge
```bash
# Extract flag from DNSCat pcap
python3 scripts/dnscat_extractor.py challenge.pcap c2.ctf.local
```

### Incident Response
```bash
# Recover stolen data from DNS logs
python3 scripts/dnscat_extractor.py dns_traffic.pcap attacker-domain.net
```

## Troubleshooting

### No Data Extracted
- Verify the C2 domain is correct
- Check if the pcap contains DNS queries to that domain
- Ensure DNSCat wasn't using encryption (encrypted traffic won't decode)

### Garbage Output
- The 9-byte header may not be stripped correctly
- Try adjusting the header offset if you know the exact protocol version
- Verify the pcap isn't corrupted

### Missing Chunks
- DNS queries may be out of order in the pcap
- Some chunks may be missing due to packet loss
- The script attempts to maintain order but gaps may exist

## References

- [DNSCat2 Protocol Documentation](https://github.com/iagox86/dnscat2/blob/master/doc/protocol.md)
- [DNSCat Decoder Tool](https://github.com/josemlwdf/DNScat-Decoder)
- [BSidesSF 2017 Writeup](https://github.com/jrmdev/ctf-writeups/tree/master/bsidessf-2017/dnscap)

## Limitations

- Only works with unencrypted DNSCat traffic
- Requires the correct C2 domain
- May not handle all DNSCat versions perfectly
- Large files may take time to process
