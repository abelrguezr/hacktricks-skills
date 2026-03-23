---
name: osint-platform-lookup
description: Look up information about IPs, domains, emails, and organizations using public OSINT APIs and platforms. Use this skill whenever the user wants to investigate suspicious activity, check IP/domain/email reputation, find leaked credentials, research organizations, or gather threat intelligence. Trigger for any request involving IP investigation, domain research, email verification, breach data lookup, or security reconnaissance.
---

# OSINT Platform Lookup

A skill for querying public OSINT (Open Source Intelligence) platforms and APIs to investigate IPs, domains, emails, and organizations.

## When to Use This Skill

Use this skill when the user wants to:
- Check if an IP address is malicious or suspicious
- Research a domain's history, ownership, or associated infrastructure
- Verify or investigate an email address
- Find leaked credentials or breach data
- Get geolocation or ASN information for an IP
- Research an organization's digital footprint
- Perform security reconnaissance or threat intelligence gathering

## Quick Reference: Platform Selection

| Investigation Type | Recommended Platforms |
|-------------------|----------------------|
| **IP Reputation** | ProjectHoneypot, FortiGuard, Fraudguard, SpamCop, mywot, Greynoise, Shodan, Censys, Binaryedge, IBM X-Force |
| **IP Geolocation** | ipinfo, IP2Location.io, IPQuery.io |
| **Domain Research** | SecurityTrails, BuiltWith, RiskIQ, DNSDumpster, Netcraft, NMMapper |
| **Email Investigation** | Hunter, Clearbit, FullContact, EmailRep.io, HaveIBeenPwned, GhostProject |
| **Breach Data** | HaveIBeenPwned, Dehashed, PSBDMP, IntelligenceX |
| **Bot/Spam Detection** | BotScout, SpamCop, Greynoise |
| **Open S3 Buckets** | buckets.grayhatwarfare.com |

## Platform Details

### IP Reputation & Threat Intelligence

**ProjectHoneypot** (Free)
- Check if an IP is related to suspicious/malicious activities
- Completely free, no API key required for basic queries
- URL: https://www.projecthoneypot.org/

**FortiGuard** (Free tier available)
- Check if a host (domain or IP) is related to suspicious/malicious activities
- Has some free API access
- URL: https://fortiguard.com/

**Fraudguard** (Free tier available)
- Similar to FortiGuard, checks hosts for suspicious activities
- Has some free API access
- URL: https://fraudguard.io/

**SpamCop** (Free tier available)
- Indicates if a host is related to spam activity
- Has some free API access
- URL: https://www.spamcop.net/

**mywot** (Free)
- Based on community opinions and metrics
- Determines if a domain is related to suspicious/malicious information
- URL: https://www.mywot.com/

**Greynoise** (15 days free)
- Search by IP or IP range
- Get information about IPs scanning the Internet
- URL: https://viz.greynoise.io/

**Shodan** (Free tier available)
- Get scan information of an IP address
- Has some free API access
- URL: https://www.shodan.io/

**Censys** (Free tier available)
- Very similar to Shodan
- URL: https://censys.io/

**Binaryedge** (Free tier available)
- Obtain interesting info from IPs
- URL: https://www.binaryedge.io/

**IBM X-Force Exchange** (Free tier available)
- Search by IP and gather information related to suspicious activities
- URL: https://exchange.xforce.ibmcloud.com/

### IP Geolocation & Network Info

**ipinfo** (100K/month free)
- Obtains basic info from an IP address
- Can test up to 100K requests/month for free
- URL: https://ipinfo.io/

**IP2Location.io** (30K/month free)
- Detects IP geolocation, data center, ASN, and VPN information
- Offers free 30K queries per month
- URL: https://www.ip2location.io/

**IPQuery.io** (Non-commercial)
- IP Geolocation and OSINT with targeted datapoints
- Non-commercial use
- URL: https://ipquery.io/

### Domain Research

**SecurityTrails** (Free tier available)
- Information about domains and IP addresses including:
  - Domains inside an IP or inside a domain server
  - Domains owned by an email (find related domains)
  - IP history of domains (find the host behind CloudFlare)
  - All domains using a nameserver
- Has some free access
- URL: https://securitytrails.com/app/account

**BuiltWith** (Commercial)
- Technologies used by websites
- Expensive, but comprehensive
- URL: https://builtwith.com/

**RiskIQ** (Free/community version available)
- A lot of information from domains and IPs
- Even in the free/community version
- URL: https://www.spiderfoot.net/documentation/

**DNSDumpster** (Commercial tool?)
- DNS reconnaissance and domain mapping
- URL: https://dnsdumpster.com/

**Netcraft** (Commercial tool?)
- Website and server information
- URL: https://www.netcraft.com/

**NMMapper** (Commercial tool?)
- Subdomain finder and network mapping
- URL: https://www.nmmapper.com/sys/tools/subdomainfinder/

### Email Investigation

**Hunter** (Free tier available)
- Find and verify emails
- Some free API requests, pay for more
- Commercial
- URL: https://hunter.io/

**Clearbit** (Commercial)
- Find related personal data to an email (profiles on other platforms)
- Domain info (basic company info, emails, people working)
- Company info from email
- Need to pay to access all possibilities
- URL: https://dashboard.clearbit.com/

**FullContact** (Free tier available)
- Search by email, domain, or company name
- Retrieve "personal" information related
- Can also verify emails
- Has some free access
- URL: https://www.fullcontact.com/

**EmailRep.io** (Commercial)
- Get reputation of an email
- URL: https://emailrep.io/key

### Breach Data & Leaked Credentials

**HaveIBeenPwned** (Commercial)
- Search by domain and email
- Get if it was pwned and passwords
- URL: https://haveibeenpwned.com/

**Dehashed** (Commercial)
- Find leaked credentials of emails and even domains
- URL: https://www.dehashed.com/data

**PSBDMP** (Commercial)
- Search pastebins where an email appeared
- URL: https://psbdmp.ws/

**IntelligenceX** (Free tier available)
- Search Domains, IPs, and emails
- Get info from dumps
- Has some free access
- URL: https://intelx.io/

**GhostProject** (Commercial)
- Get passwords from leaked emails
- URL: https://ghostproject.fr/

### Bot & Spam Detection

**BotScout** (Initially free)
- Check if the IP address is related to a bot that registers accounts
- Can also check usernames and emails
- URL: http://botscout.com/api.htm

### Open S3 Buckets

**buckets.grayhatwarfare.com** (Free)
- Find open S3 buckets searching by keyword
- URL: https://buckets.grayhatwarfare.com/

### Malicious Activity Detection

**AlienVault OTX** (Free)
- Find malicious activities related to IPs and Domains
- Free service
- URL: https://otx.alienvault.com/api

## Workflow Guidelines

### 1. Clarify the Investigation Goal

Before querying platforms, understand:
- What are we investigating? (IP, domain, email, organization)
- What information do we need? (reputation, geolocation, breach data, etc.)
- Are there legal/ethical considerations?

### 2. Select Appropriate Platforms

Choose platforms based on:
- **Free vs. Paid**: Start with free options, escalate to paid if needed
- **Coverage**: Some platforms specialize in certain data types
- **Rate Limits**: Be aware of monthly limits (e.g., ipinfo 100K/month, IP2Location 30K/month)
- **API Requirements**: Some need API keys, others don't

### 3. Query Multiple Sources

For comprehensive results:
- Query 2-3 platforms for the same data type
- Cross-reference results for accuracy
- Note discrepancies between sources

### 4. Document Findings

Structure your output clearly:
- Platform name and result
- Key findings
- Confidence level (if available)
- Timestamp of query

### 5. Respect Rate Limits & Terms

- Don't exceed free tier limits
- Check terms of service for each platform
- Some platforms are commercial-only for certain features

## Common Investigation Patterns

### Pattern 1: IP Reputation Check

```markdown
1. Start with ProjectHoneypot (free, no API key)
2. Check FortiGuard or Fraudguard for additional reputation data
3. Use Greynoise if investigating scanning activity
4. Query Shodan or Censys for service enumeration
5. Get geolocation from ipinfo or IP2Location
```

### Pattern 2: Domain Research

```markdown
1. Use SecurityTrails for domain history and related infrastructure
2. Check BuiltWith for technology stack
3. Query RiskIQ for additional domain intelligence
4. Use DNSDumpster for DNS reconnaissance
5. Check mywot for community reputation
```

### Pattern 3: Email Investigation

```markdown
1. Verify with Hunter or FullContact
2. Check EmailRep.io for reputation
3. Search HaveIBeenPwned for breach data
4. Query Dehashed or PSBDMP for leaked credentials
5. Use Clearbit for associated profiles (if paid access)
```

### Pattern 4: Breach Data Search

```markdown
1. Start with HaveIBeenPwned (most comprehensive)
2. Check IntelligenceX for dump data
3. Query Dehashed for credentials
4. Search PSBDMP for pastebin appearances
5. Use GhostProject for password data (if available)
```

## API Key Management

Many platforms require API keys. When working with users:

1. **Ask for API keys** if they have them
2. **Note which platforms need keys** before starting
3. **Handle keys securely** - don't log or expose them
4. **Track rate limits** to avoid hitting quotas

## Output Format

When presenting results, use this structure:

```markdown
## Investigation Results

### Target: [IP/Domain/Email]

#### Platform: [Name]
- **Status**: [Active/Inactive/Unknown]
- **Reputation**: [Good/Suspicious/Malicious]
- **Key Findings**: [Bullet points]
- **Confidence**: [High/Medium/Low]
- **URL**: [Link to platform result]

[Repeat for each platform queried]

#### Summary
- Overall assessment
- Recommended next steps
- Any concerning findings
```

## Ethical Considerations

- Only investigate targets you have permission to research
- Don't use this for harassment or stalking
- Respect privacy and data protection laws
- Some platforms have commercial restrictions - honor them
- Be aware that some data may be outdated or inaccurate

## Scripts

See the `scripts/` directory for helper scripts:
- `query_ip_reputation.sh` - Query multiple IP reputation services
- `query_domain_info.sh` - Gather domain intelligence from multiple sources
- `query_email_breach.sh` - Check email against breach databases

## Troubleshooting

**"API key required" errors**
- Check if the platform requires authentication
- Verify the API key is correct and active
- Some platforms have free tiers that don't require keys

**Rate limit exceeded**
- Wait for the rate limit window to reset
- Use alternative platforms
- Consider paid access for higher limits

**Inconsistent results between platforms**
- This is normal - different platforms have different data sources
- Cross-reference multiple sources
- Note the timestamp of each query (data may be stale)

**Platform unavailable**
- Some platforms have downtime or maintenance
- Try alternative platforms in the same category
- Check the platform's status page if available
