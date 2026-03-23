---
name: homograph-detection
description: Detect and analyze homograph/homoglyph attacks in phishing emails, URLs, and domains. Use this skill whenever the user mentions phishing analysis, email security, domain impersonation, Unicode attacks, homoglyph detection, or needs to inspect suspicious sender names, subjects, or URLs for character substitution attacks. Trigger even if the user just says "check this email" or "analyze this URL" if there's any suspicion of spoofing or impersonation.
---

# Homograph/Homoglyph Attack Detection

A skill for detecting and analyzing homograph attacks where attackers substitute Latin characters with visually identical Unicode characters from other scripts (Greek, Cyrillic, Armenian, Cherokee, etc.) to bypass security controls and fool victims.

## When to Use This Skill

Use this skill when:
- Analyzing suspicious emails for character substitution attacks
- Investigating domain impersonation or lookalike domains
- Checking sender display names, subject lines, or URLs for homoglyphs
- Building email security detection rules
- Auditing URLs or domains for potential phishing infrastructure
- The user mentions "phishing", "spoofing", "impersonation", "Unicode attack", or "homoglyph"

## Quick Start

```bash
# Detect mixed scripts in email fields
python scripts/detect_homoglyphs.py --field "display_name" --value "Ηеlрdеѕk"

# Analyze a full email
python scripts/detect_homoglyphs.py --email-file suspicious_email.eml

# Check a domain for homoglyph variants
python scripts/check_domain.py --domain "Paypal.com"
```

## Understanding Homograph Attacks

### What Are They?

Homograph attacks exploit the fact that many Unicode code points from non-Latin scripts are visually identical to ASCII characters. For example:

| Latin | Unicode Lookalike | Script | Code Point |
|-------|-------------------|--------|------------|
| H | Η | Greek | U+0397 |
| p | ρ | Greek | U+03C1 |
| a | а | Cyrillic | U+0430 |
| e | е | Cyrillic | U+0435 |
| o | օ | Armenian | U+0585 |
| T | Ꭲ | Cherokee | U+13A2 |

A single substituted character defeats naive string comparisons: `"Παypal.com"` ≠ `"Paypal.com"` but looks identical.

### Attack Workflow

1. **Craft message content** – Replace Latin letters with lookalikes from other scripts
2. **Register infrastructure** – Optionally register homoglyph domains (most CAs don't check visual similarity)
3. **Send phishing** – Use homoglyphs in sender name, subject, or URL
4. **Redirect** – Bounce victims through benign sites before landing on malicious hosts

## Detection Techniques

### 1. Mixed-Script Inspection

Phishing emails to English-speaking organizations should rarely mix scripts. Check for:
- Multiple Unicode blocks in a single field
- Non-Latin scripts in display names, domains, subjects, or URLs

**Run the detection script:**

```bash
python scripts/detect_homoglyphs.py --help
```

### 2. Punycode Normalization

Internationalized Domain Names (IDNs) use punycode (`xn--`). Convert hostnames to punycode to expose hidden homoglyphs:

```bash
python scripts/check_domain.py --domain "Ρаypal.com"
# Output: xn--yl8hpyal.com (reveals the substitution)
```

### 3. Domain Permutation Analysis

Use tools like `dnstwist` or `urlcrazy` to enumerate visually-similar domain variants:

```bash
dnstwist --homoglyph paypal.com
```

## Scripts Reference

### `scripts/detect_homoglyphs.py`

Detects mixed scripts and homoglyph substitutions in text fields.

**Usage:**
```bash
# Check a single field
python scripts/detect_homoglyphs.py --field "subject" --value "Urgеnt Аctіon Rеquіrеd"

# Analyze an email file
python scripts/detect_homoglyphs.py --email-file email.eml

# Check multiple fields at once
python scripts/detect_homoglyphs.py --json '{"display_name": "Ηеlрdеѕk", "subject": "Test"}'
```

**Output:**
- Lists each character with its Unicode name and block
- Flags mixed-script fields
- Shows ASCII vs non-ASCII character counts

### `scripts/check_domain.py`

Analyzes domains for homoglyph attacks and punycode encoding.

**Usage:**
```bash
# Check a single domain
python scripts/check_domain.py --domain "bestseoservices.com"

# Generate homoglyph variants
python scripts/check_domain.py --domain "paypal.com" --generate-variants
```

## Prevention & Mitigation

### Technical Controls

1. **Enforce DMARC/DKIM/SPF** – Prevent unauthorized domain spoofing
2. **Implement detection in email gateways** – Use the scripts above in SIEM/XSOAR playbooks
3. **Flag mismatched domains** – Alert when display name domain ≠ sender domain
4. **Normalize URLs** – Convert to punycode before comparison

### User Education

- Copy-paste suspicious text into a Unicode inspector
- Hover over links before clicking
- Never trust URL shorteners
- Check sender addresses, not just display names

## Real-World Examples

### Example 1: Display Name Attack
```
Sender: Сonfidеntiаl Ꭲiꮯkеt
Breakdown:
- С = Cyrillic (U+0421) not Latin C
- е = Cyrillic (U+0435) not Latin e  
- а = Cyrillic (U+0430) not Latin a
- Ꭲ = Cherokee (U+13A2) not Latin T
- ꮯ = Latin small capital (U+A7EF) not Latin I
```

### Example 2: Domain Chain Attack
```
bestseoservices.com 
  → /templates directory
  → kig.skyvaulyt.ru
  → mlcorsftpsswddprotcct.approaches.it.com (fake Microsoft login)
```

### Example 3: Spotify Impersonation
```
Sender: Sρօtifս (Greek ρ, Armenian օ, Armenian ս)
Link: Hidden behind redirects.ca
```

## Integration Guide

### Email Gateway Integration

Add this detection logic to your email filtering rules:

```python
# Pseudocode for email gateway
for field in [display_name, subject, sender_domain, url]:
    if has_mixed_scripts(field):
        quarantine_email(reason="homograph_attack_detected")
    if has_non_latin_in_expected_latin_field(field):
        flag_for_review(reason="suspicious_unicode")
```

### SIEM/XSOAR Playbook

1. Extract sender name, subject, URLs from email
2. Run `detect_homoglyphs.py` on each field
3. If mixed scripts detected → escalate to security team
4. Log Unicode breakdown for forensics

## References

- [The Homograph Illusion: Not Everything Is As It Seems](https://unit42.paloaltonetworks.com/homograph-attacks/)
- [Unicode Character Database](https://home.unicode.org/)
- [dnstwist – domain permutation engine](https://github.com/elceef/dnstwist)
- [IDNA Library Documentation](https://github.com/kjd/idna)

## Troubleshooting

**Q: Script says "no homoglyphs" but I see suspicious characters**
A: Some homoglyphs are in the Latin Extended blocks. Check the full Unicode name output.

**Q: Punycode conversion fails**
A: The domain may already be punycode. Try decoding first, then re-encoding.

**Q: False positives on legitimate international domains**
A: Whitelist known legitimate IDNs. Consider context (is this email to an English-speaking org?).
