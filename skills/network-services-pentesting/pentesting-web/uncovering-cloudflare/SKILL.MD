---
name: cloudflare-bypass
description: How to uncover and bypass Cloudflare protection to find origin server IPs or scrape protected websites. Use this skill whenever the user mentions Cloudflare bypass, origin IP discovery, WAF bypass, scraping protected sites, or needs to find real server IPs behind CDN protection. Trigger for any pentesting task involving Cloudflare, CDN bypass, or web scraping challenges with bot protection.
---

# Cloudflare Bypass & Origin Discovery

A skill for uncovering origin server IPs behind Cloudflare protection and bypassing Cloudflare's anti-bot measures for legitimate security testing and web scraping.

## When to Use This Skill

Use this skill when:
- You need to find the real origin IP of a website protected by Cloudflare
- You're performing security testing and need to bypass WAF protection
- You're scraping websites with Cloudflare bot protection
- You encounter Cloudflare challenges during reconnaissance
- You need to enumerate infrastructure behind CDN protection

## Quick Start

```bash
# For origin IP discovery
python scripts/cloudflare_recon.sh <target-domain>

# For AWS infrastructure scanning
python scripts/scan_aws_cloudflare.py <target-domain>

# For scraping bypass
python scripts/bypass_cloudflare_scrape.py <target-url>
```

## Technique 1: Historical DNS & Certificate Analysis

### Historical DNS Records
Check if the domain previously resolved to different IPs:

```bash
# Use securitytrails or similar services
# Check DNS history for old IP addresses
```

### Historical SSL Certificates
Search certificate transparency logs for origin IPs:

```bash
# Search Censys for certificates containing the domain
curl -s "https://search.censys.io/api/v1/certificates/search?q=subject.dns_names:*.<target-domain>" | jq '.results[] | .parsed.subject.dns_names'
```

### Subdomain Enumeration
Other subdomains might point directly to origin IPs:

```bash
# Check DNS records of subdomains for direct IP mappings
subfinder -d <target-domain> | while read sub; do
    dig +short $sub | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
done
```

## Technique 2: SSRF Exploitation

If you find an SSRF vulnerability in the application:

```bash
# Use SSRF to fetch internal metadata or origin IP
curl -X POST http://<vulnerable-endpoint> -d "url=http://169.254.169.254/latest/meta-data/"
```

## Technique 3: Fingerprint Matching

### Shodan Search
Search for unique strings from the website:

```bash
# Find unique HTML strings and search Shodan
curl -s https://<target-domain> | grep -oP '<title>.*?</title>'
# Then search Shodan for that exact string
```

### Favicon Hash Search
Use tools to match favicon hashes:

```bash
# CloudFlare-IP tool
git clone https://github.com/karma9874/CloudFlare-IP
cd CloudFlare-IP && python3 cloudflare.py <target-domain>

# fav-up tool
git clone https://github.com/pielco11/fav-up
cd fav-up && python3 fav_up.py <target-domain>
```

## Technique 4: Dedicated Cloudflare Bypass Tools

### CF-Hero
Comprehensive multi-source reconnaissance:

```bash
pip install cf-hero
cf-hero <target-domain>
```

### CloudFlair
Searches Censys certificates for origin IPs:

```bash
git clone https://github.com/christophetd/CloudFlair
cd CloudFlair && pip install -r requirements.txt
python3 cloudflair.py <target-domain>
```

### CloakQuest3r
Python tool for Cloudflare bypass:

```bash
git clone https://github.com/spyboy-productions/CloakQuest3r
cd CloakQuest3r && pip install -r requirements.txt
python3 CloakQuest3r.py <target-domain>
```

### CrimeFlare & Leaked.site
Check these databases:
- http://www.crimeflare.org:82/cfs.html
- https://crimeflare.herokuapp.com
- https://leaked.site/index.php?resolver/cloudflare.0/

### CloudPeler
Uses CrimeFlare API:

```bash
git clone https://github.com/zidansec/CloudPeler
cd CloudPeler && python3 cloudpeler.py <target-domain>
```

## Technique 5: AWS Infrastructure Scanning

For targets hosted on AWS, scan EC2 IP ranges:

```bash
# Use the bundled script
python scripts/scan_aws_cloudflare.py <target-domain> [region]

# Manual approach
DOMAIN=<target-domain>
for ir in $(curl https://ip-ranges.amazonaws.com/ip-ranges.json | jq -r '.prefixes[] | select(.service=="EC2") | select(.region|test("^us")) | .ip_prefix'); do
    echo "Checking $ir"
    prips $ir | hakoriginfinder -h "$DOMAIN"
done
```

## Technique 6: Cloudflare Configuration Bypasses

### Authenticated Origin Pulls (mTLS)
If the target uses Cloudflare's certificate for origin authentication:

1. Set up your own domain in Cloudflare
2. Point it to the victim's origin IP
3. Cloudflare will accept the connection (same certificate)
4. Attack through your domain without protection

### IP Allowlist Bypass
If the target only allows Cloudflare IPs:

1. Set up your domain in Cloudflare
2. Point to victim's origin IP
3. Your requests come from Cloudflare IPs
4. Bypass the allowlist

## Technique 7: Scraping Bypass Methods

### Cache Services
For simple content retrieval:

```bash
# Google cache
https://webcache.googleusercontent.com/search?q=cache:<target-url>

# Wayback Machine
https://archive.org/web/<target-url>
```

### Cloudflare Solvers

```bash
# FlareSolverr (Docker)
docker run -p 8191:8191 flaresolverr/flaresolverr:latest

# cloudscraper (Python)
pip install cloudscraper
python -c "import cloudscraper; s = cloudscraper.create_scraper(); print(s.get('<target-url>').text)"

# cloudflare-scrape
pip install cloudflare-scrape
cloudflare-scrape -u <target-url>
```

### Headless Browsers with Stealth

```bash
# Puppeteer with stealth plugin
npm install puppeteer puppeteer-extra puppeteer-extra-plugin-stealth

# Playwright with stealth
npm install playwright playwright-stealth

# SeleniumBase (recommended)
pip install seleniumbase
seleniumbase --uc <target-url>  # UC Mode for undetected Chrome
```

### Smart Proxies
Use proxy services with built-in Cloudflare bypass:

- ScraperAPI: https://www.scraperapi.com/
- Scrapingbee: https://www.scrapingbee.com/
- Oxylabs: https://oxylabs.io/
- Smartproxy: https://smartproxy.com/

## Bundled Scripts

### cloudflare_recon.sh
Wrapper script for running multiple Cloudflare recon tools:

```bash
./scripts/cloudflare_recon.sh <target-domain>
```

### scan_aws_cloudflare.py
Scans AWS IP ranges for origin servers:

```bash
python scripts/scan_aws_cloudflare.py <target-domain> [region]
```

### bypass_cloudflare_scrape.py
Attempts various scraping bypass methods:

```bash
python scripts/bypass_cloudflare_scrape.py <target-url>
```

## Workflow Recommendations

1. **Start with automated tools**: Run CF-Hero or CloudFlair first
2. **Check historical data**: DNS history and certificate logs
3. **Try SSRF**: If you have application access, test for SSRF
4. **Scan cloud infrastructure**: If you know the provider (AWS, GCP, Azure)
5. **Use fingerprinting**: Shodan and favicon matching
6. **For scraping**: Try cache first, then solvers, then headless browsers

## Legal & Ethical Considerations

- Only use these techniques on systems you have authorization to test
- Cloudflare bypass for scraping may violate ToS
- Document your authorization before performing any bypass
- Respect rate limits and don't cause service disruption

## References

- [HackTricks Cloudflare Bypass](https://book.hacktricks.xyz/pentesting-web/uncovering-cloudflare)
- [ScrapeOps Cloudflare Guide](https://scrapeops.io/web-scraping-playbook/how-to-bypass-cloudflare/)
- [Socradar Cloudflare Vulnerability](https://socradar.io/cloudflare-protection-bypass-vulnerability-on-threat-actors-radar/)
- [Trickest AWS Cloudflare Bypass](https://trickest.com/blog/cloudflare-bypass-discover-ip-addresses-aws/)
