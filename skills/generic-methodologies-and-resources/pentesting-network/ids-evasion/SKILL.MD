---
name: ids-ips-evasion
description: IDS/IPS evasion techniques for network security testing and penetration testing. Use this skill whenever the user mentions IDS evasion, IPS bypass, network security testing, firewall evasion, packet manipulation, TTL manipulation, fragmentation attacks, checksum tricks, or any scenario where they need to test or bypass intrusion detection/prevention systems. This includes authorized penetration testing, security assessments, red team operations, and network security research.
---

# IDS/IPS Evasion Techniques

This skill provides techniques for evading Intrusion Detection Systems (IDS) and Intrusion Prevention Systems (IPS) during authorized security testing and penetration testing operations.

## When to Use This Skill

Use this skill when:
- You're conducting authorized penetration testing or security assessments
- You need to test IDS/IPS effectiveness
- You're doing red team operations that require network stealth
- You're researching network security controls
- You need to understand how IDS/IPS systems can be bypassed

**Important:** Only use these techniques on systems you own or have explicit written authorization to test.

## Core Evasion Techniques

### TTL Manipulation

Send packets with a Time-To-Live (TTL) value that allows them to reach the IDS/IPS but not the final target. Then send duplicate packets with the same sequence numbers carrying malicious content—the IDS/IPS will treat them as repetitions and skip inspection.

**How to apply:**
- Use Nmap with `--ttlvalue <value>` to set custom TTL
- Calculate TTL based on network topology (hops to IDS vs hops to target)
- Send initial packets with low TTL, then follow with malicious packets using same sequence

**Why this works:** IDS/IPS sees the first packet and logs it, then ignores subsequent packets with matching sequences as duplicates.

### Adding Garbage Data

Insert random or garbage data into packets to break signature-based detection without affecting the actual payload.

**How to apply:**
- Use Nmap with `--data-length 25` to add padding
- Insert random bytes between protocol headers and payload
- Maintain valid packet structure while obscuring signatures

**Why this works:** Signature-based detection looks for specific byte patterns. Adding garbage breaks these patterns while the target system still processes the packet correctly.

### Packet Fragmentation

Fragment packets into smaller pieces. If the IDS/IPS cannot properly reassemble them, the malicious content reaches the target while the sensor sees incomplete or benign fragments.

**How to apply:**
- Use Nmap with `-f` flag for fragmentation
- Fragment at the IP layer to create multiple small packets
- Ensure fragments reassemble correctly on the target

**Why this works:** Many IDS/IPS systems have limited reassembly capabilities or different reassembly logic than the target OS.

### Invalid Checksum Exploitation

Send packets with invalid checksums. Sensors often skip checksum validation for performance, but target systems will reject invalid packets.

**How to apply:**
- Craft packets with intentionally invalid checksums
- Use RST flags with bad checksums to confuse connection state tracking
- The IDS/IPS may think a connection is closing while the target discards the packet

**Why this works:** Performance-optimized sensors skip checksum calculation, creating a mismatch in how packets are interpreted.

### Uncommon IP and TCP Options

Set unusual flags and options in IP/TCP headers that sensors may disregard but target hosts accept.

**How to apply:**
- Research target OS behavior with unusual header options
- Use tools like Scapy to craft custom packets
- Test which options are accepted by target but ignored by sensor

**Why this works:** Different systems implement protocol stacks differently, creating opportunities for differential behavior.

### Overlapping Fragments

Create overlapping IP fragments where different systems reassemble them differently based on their OS-specific policies.

**How to apply:**
- Create fragments with overlapping byte ranges
- Exploit OS-specific reassembly preferences:
  - **BSD:** Prefers smaller offset; for same offset, chooses first packet
  - **Linux:** Like BSD, but prefers last packet with same offset
  - **Windows (First):** First value wins, stays
  - **Cisco (Last):** Last value wins, stays
- Place benign data where sensor looks, malicious data where target reassembles

**Why this works:** Different operating systems have different rules for handling overlapping fragments, creating reassembly mismatches.

### TCP Stream Overlap / Reassembly Mismatch

Similar to IP fragmentation, but at the TCP stream level. Overlapping TCP segments can be reassembled differently by IDS/IPS and target host.

**How to apply:**
- Send benign segment first, then malicious overlapping segment (or reverse order)
- Adjust order based on target OS reassembly policy
- Use tiny overlaps to keep stream valid while maximizing sensor ambiguity
- Place benign bytes where IDS/IPS inspects, malicious bytes where host reassembles

**Why this works:** TCP reassembly logic varies between systems, creating opportunities to hide malicious content from sensors.

### IPv6 Extension Headers & Fragment Tricks

IPv6 allows arbitrary header chains. The upper-layer header (TCP/UDP/ICMPv6) appears after all extension headers. Devices that don't parse the full chain can be bypassed.

**How to apply:**
- Create long extension-header chains to push upper-layer header deeper
- Use small first fragments containing only IPv6 + Fragment + options
- Leave L4 header for later fragments
- Combine extension headers with fragmentation to hide the real protocol
- Exploit devices that accept non-compliant tiny fragments (RFC 7112 requires entire IPv6 header chain in first fragment)

**Why this works:** Many devices only inspect the first fragment or don't fully parse extension header chains, missing the actual payload.

## Tools

### SniffJoke
- **Repository:** https://github.com/vecna/sniffjoke
- **Purpose:** IDS evasion tool that exploits sensor vulnerabilities
- **Use case:** Testing IDS/IPS detection capabilities

### Scapy
- **Repository:** https://github.com/secdev/scapy
- **Purpose:** Python packet manipulation library
- **Use case:** Crafting custom packets with specific evasion techniques
- **Example usage:**
  ```python
  from scapy.all import *
  # Craft custom packets with TTL manipulation, fragmentation, etc.
  ```

## References

- **RFC 7112:** https://www.rfc-editor.org/rfc/rfc7112 (IPv6 Fragmentation)
- **RFC 9098:** https://www.rfc-editor.org/rfc/rfc9098 (IPv6 Extension Headers)

## Best Practices

1. **Always have authorization** - Only test systems you own or have written permission to assess
2. **Document your testing** - Keep records of what you tested and why
3. **Start with reconnaissance** - Understand the network topology before applying evasion techniques
4. **Test incrementally** - Apply one technique at a time to understand its effectiveness
5. **Consider legal implications** - These techniques can be used maliciously; use responsibly
6. **Combine techniques** - Multiple evasion methods together are often more effective than single techniques
7. **Understand your target** - Different IDS/IPS systems have different vulnerabilities

## Common Scenarios

### Scenario 1: Testing Corporate IDS
- Start with TTL manipulation to test basic detection
- Add fragmentation to test reassembly capabilities
- Use checksum tricks to test validation behavior
- Document which techniques succeeded

### Scenario 2: Red Team Network Operations
- Combine multiple evasion techniques for maximum stealth
- Use IPv6 tricks if the network supports it
- Test TCP stream overlap for persistent connections
- Monitor for detection and adjust accordingly

### Scenario 3: Security Research
- Systematically test each technique against different IDS/IPS products
- Document detection rates and evasion success
- Contribute findings to improve defensive capabilities

## Limitations

- Modern IDS/IPS systems have improved detection capabilities
- Some techniques may trigger anomaly-based detection
- Network topology affects technique effectiveness
- Legal and ethical constraints apply
- Not all techniques work against all systems

## Next Steps

After understanding these techniques:
1. Set up a lab environment for safe testing
2. Practice with tools like Scapy and SniffJoke
3. Test against known IDS/IPS systems
4. Document findings and refine your approach
5. Stay updated on new detection and evasion techniques
