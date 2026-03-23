---
name: vmware-esx-vcenter-security-audit
description: Security audit and hardening guidance for VMware ESX/vCenter infrastructure. Use this skill when users need to assess VMware virtualization security, understand attack vectors for defensive purposes, enumerate ESXi hosts for authorized penetration testing, identify ransomware indicators in virtual environments, or harden vSphere deployments. Trigger on mentions of VMware, ESXi, vCenter, virtualization security, hypervisor auditing, or ESX pentesting.
---

# VMware ESX/vCenter Security Audit

A skill for security professionals to audit, harden, and defend VMware ESX/vCenter infrastructure. This skill provides guidance on understanding attack vectors, identifying indicators of compromise, and implementing defensive controls.

## ⚠️ Authorization Required

All activities described in this skill require explicit written authorization. Use only on systems you own or have permission to test.

## Enumeration & Discovery

### Network Scanning

Identify VMware services and versions:

```bash
# Nmap service detection with VMware-specific scripts
nmap -sV --script "http-vmware-path-vuln or vmware-version" -p <PORT> <IP>

# Common VMware ports to scan
# 443 - vSphere Client (HTTPS)
# 902 - vSphere Agent
# 22 - SSH (if enabled)
# 902-903 - vSphere services
```

### Metasploit Enumeration

```bash
# ESXi fingerprinting
msfconsole
use auxiliary/scanner/vmware/esx_fingerprint
set RHOSTS <target>
run

# Check for MS15-034 HTTP.sys vulnerability
use auxiliary/scanner/http/ms15_034_http_sys_memory_dump
set RHOSTS <target>
run
```

### Credential Testing (Authorized Only)

```bash
# Test for weak credentials on VMware HTTP interface
use auxiliary/scanner/vmware/vmware_http_login
set RHOSTS <target>
set RPORT 443
set USERNAME <username>
set PASSWORD <password>
run
```

## Post-Exploitation Indicators

### Hypervisor Takeover Signs

Monitor for these commands in ESXi logs:

| Command | Purpose | Detection Priority |
|---------|---------|-------------------|
| `uname -a` | Host fingerprinting | Medium |
| `esxcli network nic list` | Network adapter enumeration | High |
| `esxcli network firewall set --enabled false` | Firewall disablement | Critical |
| `/etc/init.d/vpxa stop` | vCenter isolation | Critical |
| `passwd root` | Credential rotation | Critical |

### C2 Beacon Detection

Look for persistent processes polling external URIs:

```bash
# Check for suspicious network connections
netstat -anp | grep ESTABLISHED

# Look for unusual cron jobs
cat /var/spool/cron/crontabs/*

# Check for unknown processes
ps -ef | grep -v "init\|vpxa\|hostd"
```

### Ransomware Indicators

#### File Extensions Targeted

| Extension | Description | Risk Level |
|-----------|-------------|------------|
| `.vmdk`, `.vmem`, `.vmsd`, `.vmsn`, `.vswp` | VM disks, snapshots, swap | Critical |
| `.ova`, `.ovf` | VM appliance bundles | High |
| `.vib` | ESXi installation bundles | High |
| `.vbk`, `.vbm` | Veeam backup files | Critical |
| `.emario`, `.marion`, `.mario` | Encrypted files | Critical |

#### Detection Queries

```bash
# Find recently modified VM files
find /vmfs/volumes -name "*.vmdk" -mtime -1

# Look for ransom notes
find / -name "*Restore*" -o -name "*ransom*" -o -name "*How To*" 2>/dev/null

# Check for encrypted file extensions
find /vmfs/volumes -name "*.emario" -o -name "*.mario" 2>/dev/null
```

## Hardening Recommendations

### Network Security

1. **Segment management traffic** - Isolate vCenter and ESXi management interfaces
2. **Disable unnecessary services** - Turn off SSH, DCUI if not needed
3. **Implement network ACLs** - Restrict access to management ports (443, 902, 22)
4. **Enable TLS 1.2+** - Disable older SSL/TLS versions

### Access Control

1. **Strong authentication** - Use MFA for vCenter access
2. **Principle of least privilege** - Create role-based access controls
3. **Regular credential rotation** - Change default passwords immediately
4. **Audit logging** - Enable and monitor vCenter logs

### Host Hardening

```bash
# Disable unnecessary services
esxcli system settings advanced set -o /UserVars/ESXShellEnabled -i 0

# Enable lockdown mode
esxcli system lockdown set -e true

# Configure firewall rules
esxcli network firewall ruleset set -e true -r sshServer
```

### Backup Protection

1. **3-2-1 backup rule** - 3 copies, 2 media types, 1 offsite
2. **Immutable backups** - Use write-once-read-many (WORM) storage
3. **Air-gapped recovery** - Maintain offline backup copies
4. **Regular restore testing** - Validate backup integrity monthly

## Incident Response

### Immediate Actions

1. **Isolate affected hosts** - Disconnect from network
2. **Preserve evidence** - Capture memory, logs, disk images
3. **Identify scope** - Check all ESXi hosts and vCenter
4. **Notify stakeholders** - Follow incident response procedures

### Recovery Steps

1. **Clean rebuild** - Reinstall ESXi from trusted media
2. **Restore from clean backups** - Verify backup integrity first
3. **Patch vulnerabilities** - Apply latest security updates
4. **Rotate all credentials** - Change all passwords and certificates
5. **Monitor for persistence** - Watch for re-infection indicators

## References

- [Unit 42 – RansomHouse Encryption Analysis](https://unit42.paloaltonetworks.com/ransomhouse-encryption-upgrade/)
- [VMware Security Hardening Guide](https://www.vmware.com/security/hardening)
- [CWE-426: Untrusted Search Path](https://cwe.mitre.org/data/definitions/426.html)

## Quick Reference

### Common VMware Ports

| Port | Service | Protocol |
|------|---------|----------|
| 22 | SSH | TCP |
| 443 | vSphere Client | TCP |
| 902 | vSphere Agent | TCP |
| 903 | vSphere Agent | TCP |
| 902-903 | vSphere Services | TCP |

### Critical Files to Monitor

- `/var/log/` - System logs
- `/var/log/vmware/` - VMware-specific logs
- `/etc/vmware/` - Configuration files
- `/vmfs/volumes/` - VM datastores
- `/var/lib/vmware/` - VMware state files
