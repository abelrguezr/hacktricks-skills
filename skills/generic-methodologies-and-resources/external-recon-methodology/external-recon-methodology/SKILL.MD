---
name: external-recon
description: External reconnaissance methodology for security testing and bug bounty hunting. Use this skill whenever the user needs to discover assets, domains, subdomains, IPs, web servers, cloud resources, emails, or leaked credentials for a target organization. Trigger on requests about recon, enumeration, asset discovery, subdomain finding, OSINT gathering, or security reconnaissance against a company or domain.
---

# External Reconnaissance Methodology

A comprehensive guide for external reconnaissance in security testing and bug bounty hunting. This skill helps you systematically discover all assets belonging to a target organization.

## When to Use This Skill

Use this skill when:
- You need to enumerate assets for a target company or domain
- You're starting a bug bounty engagement and need to map the attack surface
- You want to find subdomains, domains, IPs, or cloud resources
- You need to discover emails, credentials, or leaked secrets
- You're performing OSINT gathering for security purposes
- You want to automate reconnaissance workflows

## Reconnaissance Workflow Overview

The methodology follows this progression:
1. **Asset Discovery** → Find companies and IP ranges
2. **Domain Discovery** → Find all domains in scope
3. **Subdomain Discovery** → Enumerate subdomains
4. **IP Enumeration** → Collect all IPs
5. **Web Server Discovery** → Find web applications
6. **Cloud Asset Discovery** → Find cloud resources
7. **Email & Credential Discovery** → Find emails and leaked credentials
8. **Secret Leak Discovery** → Find exposed secrets

---

## Phase 1: Asset Discovery

### 1.1 Find Company Acquisitions

First, identify all companies owned by the main target:

**Manual Research:**
- Visit [Crunchbase](https://www.crunchbase.com/) → Search company → Click "acquisitions"
- Check Wikipedia page for acquisitions section
- For public companies: SEC/EDGAR filings, investor relations pages
- For corporate trees: [OpenCorporates](https://opencorporates.com/) and [GLEIF LEI](https://www.gleif.org/)

**Why this matters:** Acquired companies are in scope and may have forgotten assets.

### 1.2 Find ASNs and IP Ranges

An ASN (Autonomous System Number) identifies IP blocks owned by an organization.

**Search by company name, IP, or domain:**
- [bgp.he.net](https://bgp.he.net/)
- [bgpview.io](https://bgpview.io/)
- [ipinfo.io](https://ipinfo.io/)
- [asnlookup.com](http://asnlookup.com/) (free API)

**Regional registries:**
- AFRINIC (Africa), ARIN (North America), APNIC (Asia), LACNIC (Latin America), RIPE NCC (Europe)

**Automated tools:**
```bash
# Amass (not always recommended)
amass intel -org "company-name"
amass intel -asn 8911,50313

# BBOT (recommended - aggregates ASNs automatically)
bbot -t target.com -f subdomain-enum
```

### 1.3 Reverse Whois Lookups

Find related assets by searching whois data (organization names, emails, addresses):

**Free tools:**
- [viewdns.info/reversewhois](https://viewdns.info/reversewhois/)
- [domaineye.com/reverse-whois](https://domaineye.com/reverse-whois)
- [reversewhois.io](https://www.reversewhois.io)
- [whoxy.com](https://www.whoxy.com) (free web, paid API)

**Automated:**
```bash
# DomLink (requires whoxy API key)
# Amass
amass intel -d target.com -whois
```

**Tip:** Use this recursively - every new domain found can be searched again.

---

## Phase 2: Domain Discovery

### 2.1 Reverse DNS Lookups

Perform reverse DNS on discovered IP ranges to find more domains:

```bash
# Using dnsrecon
dnsrecon -r <IP_RANGE> -n <DNS_SERVER>
dnsrecon -d facebook.com -r 157.240.221.35/24  # Using victim's DNS
dnsrecon -r 157.240.221.35/24 -n 1.1.1.1       # Using Cloudflare
dnsrecon -r 157.240.221.35/24 -n 8.8.8.8       # Using Google
```

**For large ranges:** Use [massdns](https://github.com/blechschmidt/massdns) or [dnsx](https://github.com/projectdiscovery/dnsx)

**Online tool:** [ptrarchive.com](http://ptrarchive.com/)

### 2.2 Trackers and Analytics IDs

Same tracker IDs across pages indicate same management team:

**Tools:**
- [Udon](https://github.com/dhn/udon)
- [BuiltWith](https://builtwith.com)
- [Sitesleuth](https://www.sitesleuth.io)
- [Publicwww](https://publicwww.com)
- [SpyOnWeb](http://spyonweb.com)
- [Webscout](https://github.com/straightblast/Sc0ut)

### 2.3 Favicon Hash Discovery

Domains with the same favicon hash are likely related:

```bash
# Calculate favicon hash
python3 << 'EOF'
import mmh3
import requests
import codecs

def fav_hash(url):
    response = requests.get(url)
    favicon = codecs.encode(response.content, "base64")
    fhash = mmh3.hash(favicon)
    print(f"{url} : {fhash}")
    return fhash

fav_hash("https://target.com/favicon.ico")
EOF
```

**Search in Shodan:**
```bash
shodan search org:"Target" http.favicon.hash:116323821 --fields ip_str,port
```

**At scale:** `httpx -l targets.txt -favicon`

### 2.4 Copyright and Unique Strings

Search for organization-specific strings in web pages:

```bash
# In Shodan
shodan search http.html:"Copyright string"
```

### 2.5 Certificate Transparency Logs

Find domains via certificate logs (often reveals forgotten domains):

**Tools:**
- [crt.sh](https://crt.sh/)
- [certspotter.com](https://certspotter.com/)
- [search.censys.io](https://search.censys.io/)
- [chaos.projectdiscovery.io](https://chaos.projectdiscovery.io/) + [chaos-client](https://github.com/projectdiscovery/chaos-client)

**CRT Time correlation:** Domains with certificates renewed at similar times may belong to the same organization.

### 2.6 DMARC Information

Find domains sharing the same DMARC records:

- [dmarc.live](https://dmarc.live/info/google.com)
- [dmarc-subdomains](https://github.com/Tedixx/dmarc-subdomains)
- [spoofcheck](https://github.com/BishopFox/spoofcheck)
- [dmarcian.com](https://dmarcian.com/)

### 2.7 Shodan Organization Search

```bash
# Search by organization name
shodan search org:"Tesla, Inc."

# Search by SSL certificate organization
shodan search ssl:"Tesla Motors"

# Using sslsearch tool
```

### 2.8 Passive DNS / Historical DNS

Find old and forgotten records:

- [securitytrails.com](https://securitytrails.com/)
- [PassiveTotal](https://community.riskiq.com/)
- [DomainTools Iris](https://www.domaintools.com/products/iris/)
- [DNSDB](https://www.farsightsecurity.com/solutions/dnsdb/)

---

## Phase 3: Subdomain Discovery

### 3.1 OSINT Tools (Passive)

**Recommended tools (configure API keys for best results):**

```bash
# BBOT (comprehensive)
bbot -t target.com -f subdomain-enum
bbot -t target.com -f subdomain-enum -rf passive  # Passive only
bbot -t target.com -f subdomain-enum -m naabu gowitness  # + port scan + screenshots

# Amass
amass enum -d target.com
amass enum -d target.com | grep target.com  # List only

# Subfinder
./subfinder -d target.com [-silent]

# Findomain
./findomain -t target.com [--quiet]

# OneForAll
python3 oneforall.py --target target.com run

# Assetfinder
assetfinder --subs-only target.com

# Sudomy (requires sudomy.api with keys)
sudomy -d target.com

# Vita
vita -d target.com

# theHarvester
theHarvester -d target.com -b "crtsh, virustotal, google, linkedin, ..."
```

### 3.2 Free APIs

```bash
# Sonar API (via Crobat)
curl https://sonar.omnisint.io/subdomains/target.com | jq -r ".[]"

# JLDC API
curl https://jldc.me/anubis/subdomains/target.com | jq -r ".[]"

# RapidDNS
rapiddns(){
  curl -s "https://rapiddns.io/subdomain/$1?full=1" \
  | grep -oE "[\.a-zA-Z0-9-]+\.$1" \
  | sort -u
}
rapiddns target.com

# crt.sh
crt(){
  curl -s "https://crt.sh/?q=%25.$1" \
  | grep -oE "[\.a-zA-Z0-9-]+\.$1" \
  | sort -u
}
crt target.com

# GAU (get all urls)
gau --subs target.com | cut -d "/" -f 3 | sort -u
```

### 3.3 DNS Brute Force

**Wordlists:**
- [jhaddix subdomains](https://gist.github.com/jhaddix/86a06c5dc309d08580a018c66354a056)
- [Assetnote best-dns-wordlist](https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt)
- [SecLists DNS](https://github.com/danielmiessler/SecLists/tree/master/Discovery/DNS)

**Resolvers:**
- [public-dns.info](https://public-dns.info/nameservers-all.txt)
- [trickest/resolvers](https://raw.githubusercontent.com/trickest/resolvers/main/resolvers-trusted.txt)

**Tools:**
```bash
# MassDNS (fast, prone to false positives)
sed 's/$/.target.com/' subdomains.txt > bf-subdomains.txt
./massdns -r resolvers.txt -w /tmp/results.txt bf-subdomains.txt
grep -E "target.com. [0-9]+ IN A .+" /tmp/results.txt

# Gobuster
gobuster dns -d target.com -t 50 -w subdomains.txt

# Shuffledns (wrapper around massdns)
shuffledns -d target.com -list subdomains.txt -r resolvers.txt

# PureDNS
puredns bruteforce wordlist.txt target.com

# Aiodnsbrute
aiodnsbrute -r resolvers -w wordlist.txt -vv -t 1024 target.com
```

### 3.4 Second Round - Permutations

Generate variations of discovered subdomains:

```bash
# Dnsgen
cat subdomains.txt | dnsgen -

# Goaltdns
goaltdns -l subdomains.txt -w words.txt -o output.txt

# Gotator
gotator -sub subdomains.txt -silent

# Altdns
altdns -i subdomains.txt -w words.txt -o output.txt

# Dmut
cat subdomains.txt | dmut -d words.txt -w 100 --use-pb -s resolvers.txt

# Alterx
alterx -d target.com -list patterns.txt

# Regulator (smart permutations)
python3 main.py target.com target target.rules
make_brute_list.sh target.rules target.brute
puredns resolve target.brute --write target.valid

# Subzuf (response-guided fuzzing)
echo www | subzuf target.com
```

### 3.5 VHost Discovery

Find virtual hosts on discovered IPs:

```bash
# FFUF (auto-calibrate)
ffuf -u http://IP -H "Host: FUZZ.target.com" \
  -w subdomains.txt -ac

# Gobuster
gobuster vhost -u https://target.com -t 50 -w subdomains.txt

# Wfuzz
wfuzz -w wordlist.txt --hc 400,404,403 \
  -H "Host: FUZZ.target.com" -u http://target.com -t 100

# VHostScan
VHostScan -t target.com
```

### 3.6 CORS Brute Force

Discover subdomains via CORS headers:

```bash
ffuf -w subdomains.txt -u http://IP \
  -H 'Origin: http://FUZZ.target.com' \
  -mr "Access-Control-Allow-Origin" -ignore-body
```

### 3.7 Subdomain Monitoring

Monitor for new subdomains via Certificate Transparency:

- [sublert](https://github.com/yassineaboukir/sublert)

---

## Phase 4: IP Enumeration

### 4.1 Collect All IPs

Gather IPs from:
- Discovered IP ranges
- DNS queries for domains/subdomains
- Historical DNS (SecurityTrails, etc.)

**Tool:** [hakip2host](https://github.com/hakluke/hakip2host) - Find domains pointing to specific IPs

### 4.2 Port Scanning

**Important:** Skip CDNs (CloudFlare, etc.) - scan only direct IPs

```bash
# Masscan for fast port discovery
# Nmap for detailed scanning
# See network pentesting methodology for full guide
```

---

## Phase 5: Web Server Discovery

### 5.1 Find Web Servers

```bash
# Httprobe
cat domains.txt | httprobe  # Ports 80, 443
cat domains.txt | httprobe -p http:8080 -p https:8443  # Custom ports

# Fprobe
# Httpx
httpx -l domains.txt
```

### 5.2 Take Screenshots

Visual inspection helps identify vulnerable endpoints:

**Tools:**
- [EyeWitness](https://github.com/FortyNorthSecurity/EyeWitness)
- [Gowitness](https://github.com/sensepost/gowitness)
- [Aquatone](https://github.com/michenriksen/aquatone)
- [Shutter](https://shutter-project.org/)
- [webscreenshot](https://github.com/maaaaz/webscreenshot)

**Analysis:**
- [eyeballer](https://github.com/BishopFox/eyeballer) - Identify likely vulnerable pages from screenshots

---

## Phase 6: Cloud Asset Discovery

### 6.1 Generate Keywords

Create wordlists with:
- Company name and variations
- Industry-specific terms (e.g., "crypto", "wallet", "dao")
- Domain and subdomain names
- Common bucket naming patterns

**Wordlists:**
- [goaltdns words](https://raw.githubusercontent.com/cujanovic/goaltdns/master/words.txt)
- [altdns words](https://raw.githubusercontent.com/infosec-au/altdns/master/words.txt)
- [AWSBucketDump](https://raw.githubusercontent.com/jordanpotti/AWSBucketDump/master/BucketNames.txt)

### 6.2 Cloud Enumeration Tools

```bash
# Cloud_enum
# CloudScraper
# Cloudlist
# S3Scanner
```

**Remember:** Look beyond AWS - check GCP, Azure, DigitalOcean, etc.

---

## Phase 7: Email Discovery

### 7.1 Find Emails

**Tools:**
- [theHarvester](https://github.com/laramies/theHarvester) (with APIs)
- [Hunter.io](https://hunter.io/) (free API)
- [Snov.io](https://app.snov.io/) (free API)
- [Minelead.io](https://minelead.io/) (free API)

### 7.2 Use Cases

- Brute-force web logins and auth services
- Phishing campaigns (if authorized)
- Additional OSINT about personnel

---

## Phase 8: Credential & Secret Discovery

### 8.1 Credential Leaks

Check for leaked credentials:

- [leak-lookup.com](https://leak-lookup.com)
- [dehashed.com](https://www.dehashed.com/)

### 8.2 GitHub Leaks

**Tool:** [Leakos](https://github.com/carlospolop/Leakos)

```bash
# Download all public repos of organization and developers
# Run gitleaks automatically
# Can also scan text from URLs
```

**Also check:** [GitHub dorks](github-leaked-secrets.md)

### 8.3 Paste Site Leaks

**Tool:** [Pastos](https://github.com/carlospolop/Pastos)

Searches 80+ paste sites for company content.

### 8.4 Google Dorks

**Tool:** [Gorks](https://github.com/carlospolop/Gorks)

Automates Google Hacking Database queries.

**Note:** Don't run all queries manually - Google will block you.

---

## Phase 9: Public Code Analysis

If the company has open-source code:

- Analyze for vulnerabilities
- Use language-specific tools
- [Snyk](https://app.snyk.io/) - Free public repo scanning

---

## Quick Reference: Tool Commands

### Subdomain Enumeration (Recommended)
```bash
# BBOT (most comprehensive)
bbot -t target.com -f subdomain-enum

# Amass
amass enum -d target.com

# Subfinder
subfinder -d target.com

# Combine multiple sources
bbot -t target.com -f subdomain-enum | sort -u > all_subdomains.txt
```

### DNS Brute Force
```bash
# MassDNS + validation
massdns -r resolvers.txt -w results.txt subdomains.txt
puredns validate results.txt -r resolvers.txt -o valid.txt
```

### Web Discovery
```bash
# Find web servers
cat subdomains.txt | httprobe > web_servers.txt

# Take screenshots
gowitness file web_servers.txt -o screenshots/
```

### Full Recon (Automated)
```bash
# Osmedeus
osmedeus -t target.com

# Reconftw
reconftw -d target.com

# Reengine
reengine -t target.com
```

---

## Important Notes

### Scope Awareness
- Always verify if discovered assets are in scope
- Some domains/subdomains may be hosted on third-party infrastructure
- CDNs should be skipped for direct port scanning

### Legal Considerations
- Only perform reconnaissance on authorized targets
- Respect rate limits on APIs
- Some tools require API keys - configure them properly

### Efficiency Tips
1. Start with passive OSINT before active scanning
2. Use multiple tools and combine results
3. Automate repetitive tasks with scripts
4. Monitor for new subdomains continuously
5. Document findings systematically

---

## Next Steps After Recon

Once enumeration is complete:

1. **Prioritize targets** - Focus on unique IPs, new subdomains, cloud assets
2. **Vulnerability scanning** - Use Nuclei, Nessus, OpenVAS (if authorized)
3. **Web application testing** - Follow web pentesting methodology
4. **Service-specific testing** - Test discovered services (SSH, databases, etc.)
5. **Report findings** - Document all discovered assets and vulnerabilities

---

## References

- [The Bug Hunter's Methodology v4.0 - Recon Edition](https://www.youtube.com/watch?v=p4JgIu1mceI) by @Jhaddix
- [Subdomain Enumeration Tool Face-Off](https://blog.blacklanternsecurity.com/p/subdomain-enumeration-tool-face-off)
- [HackTricks External Recon](https://book.hacktricks.xyz/pentesting-web/external-recon-methodology)
