---
name: network-ndmp-enumeration
description: How to enumerate and assess Network Data Management Protocol (NDMP) services on port 10000. Use this skill whenever the user mentions NDMP, port 10000, backup protocols, NAS backup systems, Symantec/Veritas Backup Exec, network-attached storage backups, or any pentesting task involving backup infrastructure. This skill provides enumeration commands, nmap scripts, and reconnaissance techniques for NDMP services.
---

# NDMP Enumeration Skill

Network Data Management Protocol (NDMP) is a protocol for transporting data between network-attached storage (NAS) devices and backup devices. It's commonly found on port 10000/tcp and is used by backup solutions like Symantec/Veritas Backup Exec.

## When to Use This Skill

Use this skill when:
- You discover port 10000 open during a network scan
- You're assessing backup infrastructure security
- You need to enumerate NDMP services on a target
- You're working with NAS devices and backup systems
- You encounter Symantec/Veritas Backup Exec in your scope

## Quick Start

```bash
# Basic NDMP enumeration
nmap -n -sV --script "ndmp-fs-info or ndmp-version" -p 10000 <TARGET_IP>

# More verbose version detection
nmap -sV -p 10000 <TARGET_IP>
```

## Enumeration Commands

### Nmap Scripts

NDMP has dedicated NSE (Nmap Scripting Engine) scripts for enumeration:

```bash
# Run both default NDMP scripts
nmap -n -sV --script "ndmp-fs-info or ndmp-version" -p 10000 <TARGET_IP>

# Run ndmp-fs-info only (filesystem information)
nmap -n -sV --script ndmp-fs-info -p 10000 <TARGET_IP>

# Run ndmp-version only (version detection)
nmap -n -sV --script ndmp-version -p 10000 <TARGET_IP>

# Full service detection with version
nmap -sV -p 10000 <TARGET_IP>
```

### Expected Output

```text
PORT      STATE SERVICE REASON  VERSION
10000/tcp open  ndmp    syn-ack Symantec/Veritas Backup Exec ndmp
```

## Shodan Reconnaissance

Use Shodan to find NDMP services globally or in your target range:

```bash
# Search for NDMP services
shodan search "ndmp"

# More specific queries
shodan search "port:10000"
shodan search "product:NDMP"
shodan search "Symantec Backup Exec"
```

## Protocol Details

- **Default Port**: 10000/tcp
- **Purpose**: Transport data between NAS devices and backup devices
- **Benefit**: Removes need to transport data through backup server, enhancing speed and reducing load
- **Common Vendors**: Symantec, Veritas, NetApp, Dell EMC

## Assessment Workflow

1. **Initial Discovery**: Scan port 10000 during network reconnaissance
2. **Version Detection**: Use `nmap -sV` to identify backup software version
3. **Script Enumeration**: Run NDMP-specific NSE scripts for filesystem info
4. **Shodan Check**: Query Shodan for additional context on the service
5. **Documentation**: Record findings including version, vendor, and any exposed information

## Important Notes

- NDMP services are often overlooked in security assessments
- Version information can reveal known vulnerabilities
- Filesystem information from `ndmp-fs-info` may expose sensitive data paths
- Always verify authorization before testing backup infrastructure
- Backup systems often have elevated privileges - treat findings as high priority

## Next Steps After Enumeration

Once you've enumerated an NDMP service:

1. Check for known CVEs against the identified version
2. Review backup policies and access controls
3. Assess if the service is properly segmented from production networks
4. Verify authentication requirements (if any)
5. Document all findings for the security report
