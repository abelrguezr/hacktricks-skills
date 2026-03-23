---
name: smtp-pentesting
description: SMTP enumeration and security testing skill. Use this skill whenever you need to test SMTP servers, enumerate email addresses, check SMTP configurations, or perform security assessments on mail servers. This includes tasks like verifying email addresses, testing SMTP commands, checking for open relays, analyzing SMTP server responses, or documenting SMTP security findings. Make sure to use this skill when the user mentions SMTP, email servers, mail enumeration, or any email-related security testing.
---

# SMTP Pentesting

A skill for testing and enumerating SMTP servers during security assessments.

## Overview

SMTP (Simple Mail Transfer Protocol) is the standard protocol for email transmission. This skill helps you enumerate SMTP servers, test their configurations, and identify potential security issues.

## Common SMTP Commands

### Connection Commands

**HELO** - Initiates SMTP conversation with sender's domain
```
HELO example.com
```

**EHLO** - Extended SMTP, requests server capabilities
```
EHLO example.com
```

### Email Transfer Commands

**MAIL FROM** - Specifies sender address
```
MAIL FROM:<sender@example.com>
```

**RCPT TO** - Specifies recipient address (repeat for multiple recipients)
```
RCPT TO:<recipient@example.com>
```

**DATA** - Begins email content transfer
```
DATA
```

### Information Gathering Commands

**VRFY** - Verifies if email/username exists
```
VRFY username
```

**EXPN** - Expands mailing list members
```
EXPN listname
```

**HELP** - Requests server information
```
HELP
```

### Control Commands

**RSET** - Resets current transaction
```
RSET
```

**QUIT** - Terminates SMTP session
```
QUIT
```

## Testing Workflow

### 1. Connect to SMTP Server

Use telnet or netcat to establish a connection:

```bash
# Standard SMTP (port 25)
telnet target.com 25

# Or with netcat
nc target.com 25

# SMTPS (port 465)
openssl s_client -connect target.com:465

# Submission (port 587)
telnet target.com 587
```

### 2. Gather Server Information

Send EHLO to see supported extensions:

```bash
EHLO yourdomain.com
```

Look for:
- Supported authentication methods (AUTH)
- Maximum message size (SIZE)
- TLS/SSL support (STARTTLS)
- Server banner information

### 3. Test Email Verification

Use VRFY to check if specific addresses exist:

```bash
VRFY admin
VRFY root
VRFY postmaster
VRFY user@domain.com
```

**Note:** Many servers disable VRFY for security. If VRFY returns 252 or 550, try RCPT TO with DATA to verify.

### 4. Check for Open Relay

Test if the server accepts mail for external domains:

```bash
MAIL FROM:<test@external.com>
RCPT TO:<victim@external.com>
DATA
Subject: Test

.
```

If the server accepts this, it may be an open relay.

### 5. Test Authentication

Check AUTH capabilities:

```bash
EHLO yourdomain.com
# Look for AUTH line in response
AUTH LOGIN
AUTH PLAIN
AUTH CRAM-MD5
```

### 6. Analyze Responses

Common SMTP response codes:
- **2xx** - Success
- **3xx** - Intermediate, continue
- **4xx** - Temporary failure
- **5xx** - Permanent failure

## Security Considerations

- **Always obtain authorization** before testing SMTP servers
- **Be aware of rate limiting** and potential blocking
- **Document findings responsibly**
- **Follow responsible disclosure practices**

## Example Session

```
$ telnet mail.example.com 25
Trying 192.168.1.100...
Connected to mail.example.com.
220 mail.example.com ESMTP Postfix

EHLO test.local
250-mail.example.com Hello
250-SIZE 10240000
250-AUTH LOGIN PLAIN
250 OK

VRFY admin
250 admin <admin@example.com>

MAIL FROM:<pentester@company.com>
250 Ok

RCPT TO:<admin@example.com>
250 Ok

QUIT
221 Bye
```

## Common Findings

1. **VRFY enabled** - Allows email enumeration
2. **EXPN enabled** - Reveals mailing list members
3. **Open relay** - Server accepts mail for any domain
4. **Weak authentication** - No AUTH required or weak methods
5. **Banner information** - Server version exposed
6. **No TLS/SSL** - Unencrypted transmission

## Best Practices

- Test from authorized networks only
- Use proper sender addresses
- Don't send actual spam or malicious content
- Document all findings with timestamps
- Report vulnerabilities through proper channels
