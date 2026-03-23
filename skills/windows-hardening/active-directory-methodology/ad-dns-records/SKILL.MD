---
name: ad-dns-enumeration
description: Active Directory DNS enumeration, manipulation, and hardening. Use this skill whenever the user mentions AD DNS, DNS records, zone transfers, adidnsdump, DNS spoofing, WPAD, dynamic DNS updates, or any Active Directory DNS-related reconnaissance or security testing. Also trigger for DNS hardening, detection rules, or when investigating DNS-based attacks in AD environments.
---

# Active Directory DNS Enumeration & Hardening

This skill helps you enumerate, analyze, and harden Active Directory DNS infrastructure. It covers reconnaissance techniques, attack vectors (for defensive understanding), and security hardening recommendations.

## When to Use This Skill

Use this skill when you need to:
- Enumerate DNS records in an Active Directory environment
- Understand DNS-based attack vectors in AD
- Harden AD DNS infrastructure
- Investigate DNS-related security incidents
- Create detection rules for DNS abuse
- Test DNS security controls in authorized engagements

## Quick Reference

| Task | Tool | Command Pattern |
|------|------|----------------|
| Enumerate all DNS records | adidnsdump | `adidnsdump -u user ldap://dc-ip -r` |
| List all zones | adidnsdump | `adidnsdump --print-zones` |
| Add DNS record (PowerShell) | PowerMad | `Invoke-DNSUpdate -DNSType A -DNSName name -DNSData ip` |
| Add DNS record (Python) | Impacket | `dnsupdate.py -u user -dc-ip ip -action add -record name -type A -data ip` |
| Add DNS record (BloodyAD) | BloodyAD | `bloodyAD dns add A name ip` |

---

## 1. DNS Enumeration

### Understanding the Risk

By default, **any authenticated user** in Active Directory can enumerate all DNS records in Domain or Forest DNS zones. This is similar to a zone transfer and can expose:
- Internal hostnames and IP addresses
- Service locations (DCs, file servers, application servers)
- Legacy systems and forgotten infrastructure
- Network topology information

### Using adidnsdump

[adidnsdump](https://github.com/dirkjanm/adidnsdump) is the primary tool for AD DNS enumeration.

#### Installation

```bash
git clone https://github.com/dirkjanm/adidnsdump
cd adidnsdump
pip install .
```

#### Basic Enumeration

```bash
# Enumerate the default zone and resolve hidden records
adidnsdump -u domain_name\\username ldap://10.10.10.10 -r

# List all available zones (DomainDnsZones, ForestDnsZones, legacy zones)
adidnsdump -u domain_name\\username ldap://10.10.10.10 --print-zones

# Dump a specific zone (e.g., ForestDnsZones)
adidnsdump -u domain_name\\username ldap://10.10.10.10 --zone _msdcs.domain.local -r

# Output as JSON (v1.4.0+)
adidnsdump -u domain_name\\username ldap://10.10.10.10 --json -r
```

#### Output Analysis

The tool outputs records to `records.csv`. Key columns to examine:
- **Name**: Record name
- **Type**: A, AAAA, CNAME, SRV, etc.
- **Data**: IP address or target
- **TTL**: Time-to-live

Look for:
- SRV records (service locations)
- CNAME records (aliases that may reveal infrastructure)
- Records with unusual naming patterns
- Legacy or deprecated hostnames

---

## 2. DNS Record Manipulation

### Understanding the Risk

The **Authenticated Users** group has **Create Child** permissions on DNS zones by default. This means any domain account can:
- Register new DNS records
- Modify existing records (if they own them)
- Enable traffic hijacking
- Facilitate NTLM relay attacks
- Potentially achieve domain compromise

### Adding DNS Records

#### Method 1: PowerMad (PowerShell)

```powershell
Import-Module .\Powermad.ps1

# Add A record
Invoke-DNSUpdate -DNSType A -DNSName evil -DNSData 10.10.14.37 -Verbose

# Add CNAME record
Invoke-DNSUpdate -DNSType CNAME -DNSName alias -DNSData target.domain.local -Verbose

# Delete a record
Invoke-DNSUpdate -DNSType A -DNSName evil -DNSData 10.10.14.37 -Delete -Verbose
```

#### Method 2: Impacket dnsupdate.py (Python)

```bash
# Add A record via secure dynamic update
python3 dnsupdate.py -u 'DOMAIN/user:password' -dc-ip 10.10.10.10 \
  -action add -record evil.domain.local -type A -data 10.10.14.37

# Delete record
python3 dnsupdate.py -u 'DOMAIN/user:password' -dc-ip 10.10.10.10 \
  -action delete -record evil.domain.local -type A -data 10.10.14.37
```

#### Method 3: BloodyAD

```bash
# Add A record
bloodyAD -u DOMAIN\\user -p 'password' --host 10.10.10.10 dns add A evil 10.10.14.37

# Add CNAME record
bloodyAD -u DOMAIN\\user -p 'password' --host 10.10.10.10 dns add CNAME alias target.domain.local
```

---

## 3. Common Attack Vectors

### 3.1 Wildcard Record Spoofing

Creating a wildcard record (`*.<zone>`) turns the AD DNS server into an enterprise-wide responder.

**Impact:**
- Captures NTLM hashes from any query
- Enables NTLM relay to LDAP/SMB
- Requires WINS lookup to be disabled

**Detection:** Look for wildcard records in zone enumeration output.

### 3.2 WPAD Hijacking

Adding a `wpad` record or NS record pointing to attacker infrastructure can proxy HTTP requests.

**Impact:**
- Harvest credentials from web traffic
- Bypass Global Query Block List (GQBL) with NS records
- CVE-2018-8320 patched wildcard/DNAME bypasses, but NS records still work

**Detection:** Monitor for wpad, isatap, and wildcard record creation.

### 3.3 Stale Entry Takeover

Claiming IP addresses from de-registered workstations.

**Impact:**
- Resource-based constrained delegation attacks
- Shadow Credentials attacks
- No DNS modification needed if record already exists

**Detection:** Enable DNS scavenging and monitor for record ownership changes.

### 3.4 DHCP → DNS Spoofing (DDSpoof)

Unauthenticated attackers on the same subnet can overwrite A records via forged DHCP requests.

**Impact:**
- Machine-in-the-middle over Kerberos/LDAP
- Can target Domain Controllers
- Full domain takeover potential

**Detection:** Monitor DHCP server logs and DNS update events.

### 3.5 Certifried (CVE-2022-26923)

Changing `dNSHostName` of a controlled machine account and requesting certificates.

**Impact:**
- Impersonate Domain Controllers
- Decrypt LDAP traffic
- Full domain compromise

**Tools:** Certipy, BloodyAD automate this attack.

---

## 4. Service Hijacking Case Study

### NATS Service Hijacking Pattern

When dynamic updates are open to authenticated users, de-registered service names can be re-claimed.

#### Step-by-Step Pattern

1. **Confirm record is missing:**
   ```bash
   dig @dc01.domain.local service-name.domain.local
   ```

2. **Re-create the record:**
   ```bash
   nsupdate
   > server 10.10.10.10
   > update add service-name.domain.local 300 A 10.10.14.2
   > send
   ```

3. **Impersonate the service:**
   - Capture legitimate service banner
   - Replay to victims
   - Harvest credentials from plaintext protocols

4. **Pivot with captured credentials:**
   - Access internal services
   - Extract additional secrets
   - Move laterally

**Applicable to:** HTTP APIs, RPC, MQTT, and any service with unsecured TCP handshakes.

---

## 5. Detection & Hardening

### 5.1 Access Control

```powershell
# Deny Authenticated Users from creating child objects on sensitive zones
# Delegate dynamic updates to a dedicated DHCP account
```

**Recommendations:**
- Deny **Authenticated Users** the *Create all child objects* right on sensitive zones
- Delegate dynamic updates to a dedicated account used by DHCP
- Use least-privilege principles for DNS management

### 5.2 Zone Configuration

**If dynamic updates are required:**
- Set zone to **Secure-only**
- Enable **Name Protection** in DHCP
- Only the owner computer object can overwrite its own record

### 5.3 Monitoring

**Key Event IDs to monitor:**
- **257/252**: Dynamic update events
- **770**: Zone transfer attempts
- **LDAP writes** to `CN=MicrosoftDNS,DC=DomainDnsZones`

**SIEM Rules:**
```yaml
# DNS Record Creation Alert
- event_id: 257
  source: DNS Server
  condition: "New record created by non-DHCP account"
  severity: medium

# Zone Transfer Alert
- event_id: 770
  source: DNS Server
  condition: "Zone transfer requested"
  severity: high

# Suspicious Record Names
- pattern: "(wpad|isatap|\*)"
  source: DNS Server
  condition: "Record name matches suspicious pattern"
  severity: high
```

### 5.4 Blocklist Dangerous Names

Block these names with intentionally-benign records or via Global Query Block List:
- `wpad`
- `isatap`
- `*` (wildcard)
- `ms-wpad`
- `pki` (if not needed)

### 5.5 Patch Management

**Critical DNS Server CVEs:**
- **CVE-2024-26224**: RCE, CVSS 9.8
- **CVE-2024-26231**: RCE, CVSS 9.8
- **CVE-2022-26923**: Certifried certificate impersonation
- **CVE-2018-8320**: WPAD bypass

**Action:** Keep DNS servers patched and monitor for new vulnerabilities.

---

## 6. Quick Hardening Checklist

- [ ] Set zones to **Secure-only** dynamic updates
- [ ] Enable **Name Protection** in DHCP
- [ ] Deny **Authenticated Users** create child objects on sensitive zones
- [ ] Block dangerous names (wpad, isatap, *)
- [ ] Enable DNS scavenging with appropriate no-refresh/refresh intervals
- [ ] Monitor event IDs 257, 252, 770
- [ ] Keep DNS servers patched
- [ ] Audit DNS zone permissions quarterly
- [ ] Implement DNS query logging
- [ ] Consider DNSSEC for critical zones

---

## References

- [adidnsdump GitHub](https://github.com/dirkjanm/adidnsdump)
- [Getting in the Zone - Dumping AD DNS](https://dirkjanm.io/getting-in-the-zone-dumping-active-directory-dns-with-adidnsdump/)
- [ADIDNS Revisited - WPAD, GQBL and More](https://www.kevrobertson.com/adidns-revisited-wpad-gqbl-and-more/)
- [Akamai DDSpoof Research](https://www.akamai.com/blog/security/spoofing-dns-records-by-abusing-dhcp-dns-dynamic-updates)
- [HackTheBox Mirage Writeup](https://0xdf.gitlab.io/2025/11/22/htb-mirage.html)
