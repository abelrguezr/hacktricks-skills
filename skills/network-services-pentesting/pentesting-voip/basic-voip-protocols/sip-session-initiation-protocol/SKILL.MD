---
name: sip-protocol-assistant
description: Expert assistance for Session Initiation Protocol (SIP) tasks including message construction, protocol analysis, security assessments, and VoIP pentesting. Use this skill whenever the user needs to understand SIP methods, create SIP messages, analyze SIP traffic, perform SIP security testing, work with SIP digest authentication, or troubleshoot VoIP systems. Trigger for any request involving SIP, VoIP, PBX, Asterisk, SIP headers, SIP response codes, or session initiation protocol.
---

# SIP Protocol Assistant

A comprehensive skill for working with Session Initiation Protocol (SIP) - the signaling protocol used for establishing, modifying, and terminating multimedia sessions over IP networks.

## What This Skill Does

This skill helps you:
- **Construct and parse SIP messages** (INVITE, REGISTER, BYE, OPTIONS, etc.)
- **Understand SIP response codes** and their meanings
- **Perform SIP security assessments** and pentesting
- **Calculate SIP digest authentication** responses
- **Analyze SIP traffic** and troubleshoot VoIP issues
- **Harden SIP deployments** against common vulnerabilities

## Core SIP Methods

### Request Methods

| Method | Purpose | RFC |
|--------|---------|-----|
| `INVITE` | Initiate or modify a session | 3261 |
| `ACK` | Confirm receipt of final INVITE response | 3261 |
| `BYE` | Terminate an established session | 3261 |
| `CANCEL` | Cancel a pending INVITE | 3261 |
| `OPTIONS` | Query server capabilities | 3261 |
| `REGISTER` | Register location with registrar | 3261 |
| `SUBSCRIBE` | Request event notifications | 6665 |
| `NOTIFY` | Send event notifications | 6665 |
| `REFER` | Request call transfer | 3515 |
| `MESSAGE` | Send instant messages | 3428 |
| `UPDATE` | Modify session without dialog state change | 3311 |
| `PUBLISH` | Publish event state to server | 3903 |

### Response Code Categories

| Category | Range | Meaning |
|----------|-------|--------|
| 1xx | 100-199 | Provisional (request received, processing) |
| 2xx | 200-299 | Success (request fulfilled) |
| 3xx | 300-399 | Redirection (further action required) |
| 4xx | 400-499 | Client Error (bad syntax or cannot fulfill) |
| 5xx | 500-599 | Server Error (server failed valid request) |
| 6xx | 600-699 | Global Failure (cannot fulfill anywhere) |

### Common Response Codes

```
100 Trying          - Request received, processing
180 Ringing         - Callee being alerted
183 Session Progress - Call progress information
200 OK              - Request successful
301 Moved Permanently - Resource has new URI
302 Moved Temporarily - Resource temporarily at different URI
400 Bad Request     - Malformed request
401 Unauthorized    - Authentication required
403 Forbidden       - Server refuses request
404 Not Found       - Resource not found
408 Request Timeout - No complete request in time
486 Busy Here       - Callee is busy
500 Internal Server Error - Server processing error
503 Service Unavailable - Server overloaded/maintenance
600 Busy Everywhere - All destinations busy
603 Decline         - Callee refuses to participate
```

## SIP Message Structure

### Request Format

```
METHOD sip:uri SIP/2.0
Via: SIP/2.0/UDP/TCP/TLS host:port;branch=z9hG4bK...
Max-Forwards: 70
From: <sip:user@domain>;tag=...
To: <sip:user@domain>
Call-ID: unique-id@host
CSeq: sequence METHOD
Contact: <sip:user@host:port>
[Optional headers...]
Content-Type: application/sdp
Content-Length: bytes

[SDP body for INVITE/ACK]
```

### Response Format

```
SIP/2.0 CODE REASON-PHRASE
Via: SIP/2.0/UDP/TCP/TLS host:port;branch=z9hG4bK...
From: <sip:user@domain>;tag=...
To: <sip:user@domain>;tag=...
Call-ID: unique-id@host
CSeq: sequence METHOD
[Optional headers...]
Content-Length: bytes

[Body if applicable]
```

### Key Headers Explained

| Header | Purpose |
|--------|--------|
| `Via` | Transport protocol, client address, branch for loop detection |
| `Max-Forwards` | Limits proxy forwarding (prevents infinite loops) |
| `From` | Sender identity with optional tag |
| `To` | Recipient identity with optional tag |
| `Call-ID` | Unique session identifier |
| `CSeq` | Sequence number + method (matches requests/responses) |
| `Contact` | Direct route to user agent |
| `WWW-Authenticate` | Digest auth challenge (realm, nonce, algorithm) |
| `Authorization` | Digest auth credentials |
| `Content-Type` | Body media type (usually application/sdp) |
| `Content-Length` | Body size in bytes |

## Creating SIP Messages

### Generate a SIP INVITE

Use the `scripts/generate_sip_invite.py` script to create properly formatted INVITE messages:

```bash
python scripts/generate_sip_invite.py \
  --from "sip:caller@example.com" \
  --to "sip:callee@target.com" \
  --contact "sip:caller@192.168.1.100:5060" \
  --transport UDP \
  --output invite.txt
```

### Generate a SIP REGISTER

```bash
python scripts/generate_sip_register.py \
  --username alice \
  --realm example.com \
  --contact "sip:alice@192.168.1.100:5060" \
  --expires 3600 \
  --output register.txt
```

### Calculate Digest Authentication Response

When you receive a 401 Unauthorized with WWW-Authenticate header, use the script to calculate the response:

```bash
python scripts/calculate_sip_digest.py \
  --username alice \
  --password "secretpassword" \
  --realm "example.com" \
  --method REGISTER \
  --uri "sip:example.com" \
  --nonce "abc123nonce" \
  --cnonce "xyz789cnonce" \
  --nc 00000001 \
  --qop auth
```

This outputs the MD5 response value for the Authorization header.

## SIP Security Assessment

### Fingerprinting and Discovery

Send OPTIONS requests to enumerate capabilities:

```bash
# Using nmap NSE script
sudo nmap -sU -p 5060 --script sip-methods <target>

# Manual OPTIONS request
printf "OPTIONS sip:<target> SIP/2.0\r\nVia: SIP/2.0/UDP attacker;branch=z9\r\nFrom: <sip:probe@attacker>;tag=1\r\nTo: <sip:probe@<target>>\r\nCall-ID: 1@attacker\r\nCSeq: 1 OPTIONS\r\nMax-Forwards: 70\r\nContact: <sip:probe@attacker>\r\nContent-Length: 0\r\n\r\n" | nc -u -w 2 <target> 5060
```

Review `Allow`, `Supported`, `Server`, and `User-Agent` headers to identify:
- PBX type and version (Asterisk, FreeSWITCH, 3CX, etc.)
- Supported methods (MESSAGE, PUBLISH, REFER)
- Potential vulnerabilities based on version

### Username/Extension Enumeration

SIP servers often leak valid extensions through response differences:

| Response | Meaning |
|----------|--------|
| `401/407` | Valid user, auth required |
| `404` | User not found |
| `403` | User exists but forbidden |
| `486` | User exists but busy |

**Test approach:** Send REGISTER or INVITE to various extensions and compare responses. Uniform responses indicate proper hardening.

### Digest Authentication Cracking

SIP commonly uses HTTP-Digest authentication. Extract from pcap:

```
username:realm:method:uri:nonce:cnonce:nc:qop:response
```

Crack with hashcat (mode 11400 for MD5):

```bash
echo 'alice:example.com:REGISTER:sip:example.com:abcdef:11223344:00000001:auth:65a8e2285879283831b664bd8b7f14d4' > sip.hash
hashcat -a 0 -m 11400 sip.hash /path/to/wordlist.txt
```

**Note:** RFC 8760 defines SHA-256 and SHA-512/256 for modern deployments. Check if your tools support these.

### Common Vulnerabilities to Check

1. **Weak digest algorithms** - MD5 is trivial to crack offline
2. **Missing authentication** - Anonymous registration/calling enabled
3. **Extension enumeration** - Response differences leak valid users
4. **TLS misconfiguration** - Self-signed certs, weak ciphers, no validation
5. **Information disclosure** - OPTIONS reveals version, methods, capabilities
6. **DoS susceptibility** - No rate limiting on INVITE/REGISTER
7. **CVE-2024-35190** - Asterisk PJSIP endpoint misidentification (affects 18.x < 18.23.1, 20.x < 20.8.1, 21.x < 21.3.1)

## Hardening Recommendations

### Server Configuration

**Asterisk chan_sip:**
```ini
[general]
alwaysauthreject=yes
allowguest=no
port=5060
bindaddr=0.0.0.0

[endpoint]
permit=10.0.0.0/8
deny=0.0.0.0/0
```

**Asterisk PJSIP:**
```ini
[general]
; Do not create anonymous endpoint unless required

[endpoint]
acl=trusted_networks
media_acl=trusted_networks
```

### Network-Level Protection

```bash
# Rate limiting for SIP (iptables)
iptables -A INPUT -p udp --dport 5060 -m hashlimit \
  --hashlimit-name SIP --hashlimit 20/second --hashlimit-burst 40 \
  --hashlimit-mode srcip -j ACCEPT
iptables -A INPUT -p udp --dport 5060 -j DROP

# Enable fail2ban for SIP
# Configure /etc/fail2ban/jail.local with sip-asterisk or sip-freeswitch
```

### Best Practices Checklist

- [ ] Use TLS for signaling (SIPS, port 5061)
- [ ] Use SRTP/DTLS-SRTP for media encryption
- [ ] Enforce strong passwords (12+ characters, complexity)
- [ ] Prefer SHA-256/SHA-512-256 over MD5 for digest
- [ ] Disable unused methods (MESSAGE, PUBLISH, REFER)
- [ ] Implement rate limiting on all endpoints
- [ ] Enable fail2ban or equivalent intrusion prevention
- [ ] Use topology hiding on edge proxies/SBCs
- [ ] Regularly update PBX software (check CVEs)
- [ ] Network ACLs to restrict SIP sources
- [ ] Monitor logs for failed auth attempts

## Troubleshooting Common Issues

### Call Setup Fails

1. Check SIP logs on both endpoints
2. Verify NAT traversal (STUN, TURN, or ALG)
3. Confirm firewall allows UDP 5060 and RTP ports (10000-20000 typical)
4. Validate SDP negotiation (codecs, ports)
5. Check for 407 Proxy Authentication vs 401 Unauthorized

### Registration Fails

1. Verify credentials match server configuration
2. Check registration expiration (default 3600 seconds)
3. Confirm network connectivity to registrar
4. Review 401 challenge parameters (realm, nonce)
5. Ensure Contact header matches expected format

### One-Way Audio

1. Verify NAT configuration (rtp_symmetric, directmedia)
2. Check firewall for RTP port range
3. Confirm SDP IP addresses are routable
4. Test with direct IP vs SIP URI

## References

- **RFC 3261** - SIP Core Specification: https://www.rfc-editor.org/rfc/rfc3261
- **RFC 8760** - SHA-256/SHA-512 for HTTP Digest: https://www.rfc-editor.org/rfc/rfc8760
- **RFC 7118** - SIP over WebSocket: https://www.rfc-editor.org/rfc/rfc7118
- **Asterisk Security Advisories**: https://github.com/asterisk/asterisk/security/advisories
- **OWASP VoIP Security**: https://owasp.org/www-project-voip-security/

## Scripts Available

| Script | Purpose |
|--------|--------|
| `generate_sip_invite.py` | Create INVITE messages with SDP |
| `generate_sip_register.py` | Create REGISTER messages |
| `calculate_sip_digest.py` | Calculate digest auth response |
| `parse_sip_message.py` | Parse and display SIP message structure |
| `sip_options_probe.py` | Send OPTIONS for fingerprinting |

Run `python scripts/<script>.py --help` for usage details.
