---
name: phishing-assessment
description: How to conduct authorized phishing assessments and security awareness testing. Use this skill whenever the user mentions phishing campaigns, email security testing, social engineering assessments, credential harvesting simulations, GoPhish configuration, domain impersonation techniques, or security awareness training. Make sure to use this skill for any authorized security testing involving email-based attacks, MFA bypass scenarios, or help-desk social engineering simulations.
---

# Phishing Assessment Methodology

A comprehensive guide for conducting authorized phishing assessments and security awareness testing.

## ⚠️ Authorization Required

**Only use this methodology with explicit written authorization from the target organization.** Unauthorized phishing attacks are illegal and unethical.

## Assessment Workflow

### Phase 1: Reconnaissance

1. **Select the victim domain** - Identify the target organization's primary domain
2. **Enumerate login portals** - Search for authentication pages to impersonate
3. **OSINT for email discovery** - Find valid email addresses using public sources

### Phase 2: Infrastructure Setup

1. **Acquire domain** - Purchase or register a domain for the campaign
2. **Configure email records** - Set up SPF, DMARC, DKIM, and rDNS
3. **Deploy GoPhish** - Install and configure the phishing framework

### Phase 3: Campaign Preparation

1. **Create email templates** - Design realistic phishing emails
2. **Build landing pages** - Clone or create credential harvesting pages
3. **Import targets** - Load email addresses into the campaign

### Phase 4: Execution & Monitoring

1. **Launch campaign** - Send phishing emails to targets
2. **Monitor results** - Track clicks, submissions, and success rates
3. **Document findings** - Report results and recommendations

## Domain Generation Techniques

### Variation Methods

Use these techniques to generate similar-looking domains:

| Technique | Example | Description |
|-----------|---------|-------------|
| **Keyword** | `zelster.com-management.com` | Add important keywords |
| **Hyphenated** | `www-zelster.com` | Replace dot with hyphen |
| **New TLD** | `zelster.org` | Use different TLD |
| **Homoglyph** | `zelfser.com` | Replace with similar-looking letters |
| **Transposition** | `zelsetr.com` | Swap two letters |
| **Pluralization** | `zelsters.com` | Add/remove 's' |
| **Omission** | `zelser.com` | Remove one letter |
| **Repetition** | `zeltsser.com` | Repeat a letter |
| **Replacement** | `zektser.com` | Replace with nearby keyboard letter |
| **Subdomained** | `ze.lster.com` | Insert dot inside domain |
| **Insertion** | `zerltser.com` | Insert a letter |
| **Missing dot** | `zelstercom.com` | Append TLD without dot |

### Automated Tools

- **dnstwist** - Generate domain variations
- **urlcrazy** - Create typosquatting domains
- **Online generators** - dnstwist.it, dnstwister.report

### Bitflipping Domains

Single-bit modifications can change domains (e.g., `windows.com` → `windnws.com`). Attackers register these to intercept traffic.

### Trusted Domain Acquisition

Search expired domains at `expireddomains.net` and verify their reputation using:
- FortiGuard web filter
- Palo Alto URL filtering

## Email Discovery

### Free Tools

- **theHarvester** - Comprehensive OSINT tool
- **phonebook.cz** - Email discovery
- **maildb.io** - Breached email database
- **hunter.io** - Professional email finder
- **anymailfinder.com** - Email verification

### Verification Methods

1. **SMTP brute-force** - Test email addresses against mail servers
2. **Web portal enumeration** - Check for username brute-force vulnerabilities
3. **Public email testing** - Send to info@, press@, public@ addresses

## GoPhish Configuration

### Installation

```bash
# Download and extract to /opt/gophish
cd /opt/gophish
./gophish
```

Access admin panel on port 3333 with the password shown in output.

### TLS Certificate Setup

```bash
DOMAIN="<your-domain>"

# Install certbot
sudo snap install --classic certbot

# Generate certificate
certbot certonly --standalone -d "$DOMAIN"

# Copy to GoPhish
mkdir /opt/gophish/ssl_keys
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" /opt/gophish/ssl_keys/key.pem
cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" /opt/gophish/ssl_keys/key.crt
```

### GoPhish Configuration

Edit `/opt/gophish/config.json`:

```json
{
  "admin_server": {
    "listen_url": "127.0.0.1:3333",
    "use_tls": true,
    "cert_path": "gophish_admin.crt",
    "key_path": "gophish_admin.key"
  },
  "phish_server": {
    "listen_url": "0.0.0.0:443",
    "use_tls": true,
    "cert_path": "/opt/gophish/ssl_keys/key.crt",
    "key_path": "/opt/gophish/ssl_keys/key.pem"
  },
  "db_name": "sqlite3",
  "db_path": "gophish.db"
}
```

### Service Configuration

Create `/etc/init.d/gophish`:

```bash
#!/bin/bash
process=gophish
appDirectory=/opt/gophish
logfile=/var/log/gophish/gophish.log

start() {
    echo 'Starting Gophish...'
    cd ${appDirectory}
    nohup ./$process >>$logfile 2>&1 &
}

stop() {
    echo 'Stopping Gophish...'
    pid=$(/bin/pidof ${process})
    kill ${pid}
}

case $1 in
    start|stop|status) "$1" ;;
esac
```

## Email Server Configuration

### DNS Records

**SPF Record** (TXT):
```
v=spf1 mx a ip4:<your-ip> ?all
```

**DMARC Record** (TXT at `_dmarc.<domain>`):
```
v=DMARC1; p=none
```

**DKIM Record** - Configure with Postfix and generate keys

**rDNS (PTR)** - Set at your hosting provider

### Testing Email Configuration

1. **mail-tester.com** - Send test email to provided address
2. **check-auth@verifier.port25.com** - Verify authentication headers
3. **Gmail test** - Check `Authentication-Results` header for `spf=pass` and `dkim=pass`

### Blacklist Removal

- **Spamhaus**: spamhaus.org/lookup/
- **Microsoft**: sender.office.com

## Campaign Creation

### Sending Profile

- Use generic sender names: `noreply`, `support`, `servicedesk`
- Enable "Ignore Certificate Errors"
- Test with temporary email addresses (10minutemail)

### Email Template

```html
<html>
<head><title></title></head>
<body>
<p>Dear {{.FirstName}} {{.LastName}},</p>
<br />
<p>We require all users to login before the end of the week.</p>
<br />
<p>Regards,<br/>IT Department</p>
<p>{{.Tracker}}</p>
</body>
</html>
```

**Best practices:**
- Add tracking image
- Use realistic signatures from public emails
- Keep subject lines normal and expected
- Consider attaching files for NTLM credential theft

### Landing Page

- Clone legitimate login pages
- Enable "Capture Submitted Data" and "Capture Passwords"
- Set redirect to legitimate site or success page
- Store static resources in `/opt/gophish/static/endpoint`

### Users & Groups

Import CSV with columns: `firstname`, `lastname`, `email`

## Advanced Techniques

### MFA Bypass Methods

**Proxy MitM** (evilginx2, CredSniper, muraena):
1. Impersonate real login form
2. Forward credentials to real site
3. Capture 2FA codes in real-time
4. Steal session cookies

**VNC-based** (EvilnoVNC):
- Send victim to VNC session with real browser
- Observe all interactions including MFA

### High-Touch Identity Compromise

**Help-Desk MFA Reset Attack:**
1. Recon target's personal/corporate details
2. Call help-desk impersonating target
3. Provide PII to pass verification
4. Request MFA reset or SIM-swap
5. Immediately pivot with valid credentials

**Detection:**
- Monitor for `deleteMFA` + `addMFA` within minutes
- Require step-up auth for identity recovery
- Implement call-back verification

### At-Scale Deception

**SEO Poisoning:**
- Fake search results (e.g., `chromium-update[.]site`)
- First-stage loaders (JS/HTA/ISO)
- Silent loaders deploy RAT/ransomware

**ClickFix DLL Delivery:**
- Fake CERT update pages
- Batch downloads DLL to `%TEMP%`
- Execute via `rundll32`
- C2 via base64-encoded PowerShell

### AI-Enhanced Phishing

- Generate personalized emails at scale
- Deep-fake voice for callback scams
- Autonomous domain registration and intel gathering
- Runtime JavaScript generation via LLM APIs

### Mobile Phishing

**Device-gated phishing:**
- Check for `ontouchstart` in JavaScript
- Serve 500 to desktop crawlers
- Full phishing flow only for mobile

**WhatsApp device-linking:**
- Fake QR code pages
- Victim scans, attacker gains linked device access

## Detection & Evasion

### Monitoring for Detection

- Check domain against blacklists (malwareworld.com)
- Register similar domains to detect victim monitoring
- Use Phishious to evaluate email deliverability

### Evasion Techniques

- Wait 1+ week before campaign (domain age matters)
- Use legitimate-looking content on domain
- Test with temporary emails first
- Rotate infrastructure between campaigns

## Reporting & Remediation

### Assessment Report Structure

1. **Executive Summary** - High-level findings
2. **Methodology** - Techniques used
3. **Results** - Success rates, metrics
4. **Key Findings** - Most vulnerable areas
5. **Recommendations** - Remediation steps

### Remediation Recommendations

1. **Email Security**
   - Implement DMARC with reject policy
   - Enable SPF and DKIM
   - Deploy email authentication monitoring

2. **User Awareness**
   - Regular phishing simulations
   - Training on social engineering
   - Clear reporting procedures

3. **Technical Controls**
   - MFA for all accounts
   - Help-desk verification procedures
   - Monitor for MFA reset anomalies
   - Block newly-registered domains

4. **Detection**
   - UEBA for identity anomalies
   - Monitor for unusual authentication patterns
   - Alert on MFA method changes

## Legal & Ethical Considerations

- **Written authorization** required before any testing
- **Scope definition** - Clearly define targets and methods
- **Data handling** - Securely store and delete captured credentials
- **Disclosure** - Report findings responsibly
- **Compliance** - Follow applicable laws and regulations

## References

- [Domain Name Variations in Phishing](https://zeltser.com/domain-name-variations-in-phishing/)
- [Phishing Domains](https://0xpatrik.com/phishing-domains/)
- [Unit 42 Social Engineering Report](https://unit42.paloaltonetworks.com/)
- [GoPhish Documentation](https://getgophish.com/)
- [Mail-Tester](https://www.mail-tester.com/)
- [Phishious](https://github.com/Rices/Phishious)
