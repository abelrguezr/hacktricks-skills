---
name: phishing-detection
description: Detect phishing attempts targeting your organization by analyzing domain variations, certificate transparency logs, URL telemetry, and network fingerprints. Use this skill whenever you need to hunt for phishing infrastructure, investigate suspicious domains, monitor for brand impersonation, or set up proactive phishing detection. Trigger this skill for tasks like "find phishing domains targeting our company", "check if this domain is suspicious", "monitor for brand abuse", "analyze certificate transparency for our brand", or "detect credential harvesting sites".
---

# Phishing Detection Skill

A comprehensive skill for detecting and hunting phishing attempts targeting your organization or brand.

## When to Use This Skill

Use this skill when you need to:
- Find domains that impersonate your organization's brand
- Monitor for newly registered domains using your brand keywords
- Investigate suspicious URLs or domains
- Set up proactive phishing detection infrastructure
- Analyze certificate transparency logs for brand abuse
- Hunt for credential harvesting sites using favicon or content fingerprinting
- Check if a domain is using phishing techniques (bitflipping, homoglyphs, etc.)

## Core Detection Methods

### 1. Domain Variation Analysis

Generate and monitor domain variations that attackers might use to impersonate your brand.

**Tools:**
- `dnstwist` - Generates permutations of domain names (typos, bitflips, homoglyphs)
- `urlcrazy` - Alternative domain permutation tool

**Workflow:**
1. Generate candidate phishing domains using your brand name
2. Check which ones are registered (DNS resolution)
3. Monitor DNS logs for NXDOMAIN lookups from internal users (indicates typos before registration)
4. Pre-block or sinkhole suspicious domains if policy allows

### 2. Bitflipping Detection

Attackers register domains with single-bit modifications (e.g., `microsoft.com` → `windnws.com`).

**Action:** Include bitflipped variants in your monitoring list. Use `dnstwist` with bitflip mode enabled.

### 3. Favicon Fingerprinting

Phishing kits often reuse favicons from the brands they impersonate. Internet scanners compute MurmurHash3 of favicons.

**Process:**
1. Generate hash of your brand's favicon
2. Query Shodan/ZoomEye/Censys for matching hashes
3. Validate matches (check content, certificates, domain age)

### 4. URL Telemetry Hunting

Use `urlscan.io` to find historical scans of lookalike domains.

**Key queries:**
- Find lookalikes: `page.domain:(/.*yourbrand.*/ AND NOT yourbrand.com)`
- Find hotlinking: `domain:yourbrand.com AND NOT page.domain:yourbrand.com`
- Recent only: append `AND date:>now-7d`

### 5. Certificate Transparency Monitoring

Monitor CT logs for certificates containing your brand keywords.

**Tools:**
- `crt.sh` - Free web interface for CT search
- `CertStream` - Real-time CT stream
- `phishing_catcher` - Automated CT monitoring

**Prioritization:** Focus on newly registered domains (NRDs), unknown registrars, privacy-proxy WHOIS, and very recent certificate issuance.

### 6. Domain Age Analysis

Newly registered domains are higher risk. Use RDAP to check registration dates.

### 7. TLS Fingerprinting

Modern AiTM (Adversary-in-the-Middle) phishing uses reverse proxies like Evilginx. Monitor JA3/JA4 fingerprints at egress.

**Note:** Treat fingerprints as enrichment, not sole blockers.

## Scripts

The following scripts automate common detection tasks:

- `scripts/generate_domain_variations.sh` - Generate and check domain permutations
- `scripts/check_favicon_hash.py` - Generate favicon hash for Shodan queries
- `scripts/query_urlscan.py` - Search urlscan.io for brand abuse
- `scripts/check_domain_age.py` - Check domain registration age via RDAP
- `scripts/monitor_certstream.py` - Real-time CT monitoring for brand keywords

## Quick Start

1. **Identify your brand domains** - List all legitimate domains you own
2. **Generate variations** - Use `generate_domain_variations.sh` to create candidate list
3. **Check registrations** - See which variations are already registered
4. **Set up monitoring** - Configure `monitor_certstream.py` for real-time alerts
5. **Hunt existing infrastructure** - Use favicon and urlscan queries to find active phishing

## Best Practices

- **Monitor continuously** - Run checks daily or set up automated monitoring
- **Prioritize NRDs** - Newly registered domains are higher risk
- **Combine signals** - Use multiple detection methods together for better precision
- **Validate before acting** - Favicon matches and keyword hits need manual review
- **Maintain allowlists** - Reduce false positives by tracking your owned domains
- **Check DNS logs** - NXDOMAIN lookups from internal users indicate attempted typos

## Output Format

When investigating a domain, provide:
- Domain name and registration age
- DNS resolution status
- Favicon hash (if applicable)
- Certificate details (issuer, validity, SANs)
- Content analysis (login forms, brand impersonation)
- Risk assessment and recommended actions

## References

- urlscan.io API: https://urlscan.io/docs/search/
- JA4 fingerprinting: https://blog.apnic.net/2023/11/22/ja4-network-fingerprinting/
- dnstwist: https://github.com/elceef/dnstwist
- CertStream: https://github.com/certstream/certstream
- phishing_catcher: https://github.com/x0rz/phishing_catcher
