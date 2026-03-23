---
name: webrtc-dos-testing
description: Security testing skill for WebRTC DoS vulnerabilities involving race conditions between ICE consent verification and DTLS handshake. Use this skill whenever you need to test WebRTC media servers for the null cipher suite vulnerability, analyze WebRTC security configurations, or implement mitigations for DTLS handshake attacks. Trigger this skill for any WebRTC security assessment, media server hardening, or when investigating WebRTC-related DoS issues.
---

# WebRTC DoS Vulnerability Testing

This skill helps security professionals test for and mitigate the WebRTC DoS vulnerability that exploits a race condition between ICE media consent verification and DTLS traffic initiation.

## What This Skill Does

- Tests WebRTC media servers for the null cipher suite DoS vulnerability
- Analyzes WebRTC configurations for security weaknesses
- Provides mitigation strategies and implementation guidance
- Generates test reports documenting findings

## When to Use This Skill

Use this skill when:
- You need to assess WebRTC media server security
- You're investigating WebRTC-related DoS incidents
- You want to harden WebRTC infrastructure against handshake attacks
- You're performing security audits on real-time communication systems
- You need to understand the ICE/DTLS race condition vulnerability

## Vulnerability Overview

The vulnerability exploits a race condition during WebRTC media session initialization:

1. **UDP Port Allocation**: Media server allocates UDP ports for media streams
2. **ICE/STUN Process**: Browser uses ICE for media consent verification via STUN
3. **DTLS Session**: After STUN verification, DTLS establishes SRTP master keys

**Attack Vector**: An attacker sends a DTLS ClientHello with an invalid cipher suite (e.g., `TLS_NULL_WITH_NULL_NULL`) before the legitimate user, causing a DTLS error that prevents SRTP session establishment.

## Testing Procedures

### Prerequisites

- Authorization to test the target infrastructure
- Network access to the WebRTC media server
- Python 3.7+ with Scapy installed
- Understanding of WebRTC protocols (ICE, STUN, DTLS, SRTP)

### Step 1: Identify Media Ports

WebRTC media servers typically use ephemeral UDP ports. Identify the port range:

```bash
# Check for open UDP ports on the media server
nmap -sU -p 10000-65535 <media-server-ip>

# Or check server configuration files
# Look for port ranges in config files like:
# - /etc/janus/janus.conf
# - /etc/mediasoup/mediasoup-config.json
# - /etc/jitsi/jicofo/config.properties
```

### Step 2: Run the Test Script

Use the bundled `webrtc-dos-test.py` script to test for the vulnerability:

```bash
python scripts/webrtc-dos-test.py \
  --target <media-server-ip> \
  --ports <port-range> \
  --output results.json
```

**Important**: Only run this test on systems you own or have explicit authorization to test.

### Step 3: Analyze Results

The test script will:
- Send DTLS ClientHello messages with null cipher suites
- Monitor for handshake failures
- Document which ports are vulnerable
- Generate a detailed report

## Mitigation Strategies

### Server-Side Mitigations

1. **Drop Packets from Unverified Addresses**
   - Only process packets from IP/port combinations that passed ICE verification
   - Implement this in the media server configuration

2. **Update Libraries**
   - Ensure `libnice` is updated to versions that implement proper ICE verification
   - Check for security patches in your WebRTC stack

3. **DTLS Configuration**
   - Reject invalid cipher suites immediately
   - Implement rate limiting on DTLS handshake attempts

### Configuration Examples

**For Janus Gateway:**
```ini
[ice]
; Enable ICE consent verification
ice-consent = true
; Drop packets from unverified sources
ice-drop-unverified = true
```

**For Mediasoup:**
```json
{
  "rtcpMux": true,
  "iceServers": [
    {
      "urls": "stun:stun.l.google.com:19302"
    }
  ],
  "iceCandidatePoolSize": 10,
  "dtlsSettings": {
    "rejectInvalidCiphers": true
  }
}
```

### Network-Level Mitigations

1. **Firewall Rules**
   - Restrict UDP port access to known signaling servers
   - Implement rate limiting on DTLS handshake traffic

2. **Monitoring**
   - Alert on unusual DTLS handshake failure rates
   - Monitor for port scanning activity on media ports

## Non-Vulnerable Configurations

These configurations are NOT susceptible to this vulnerability:

- **DTLS Server Mode**: When the browser acts as a DTLS server (not client)
- **Fixed Ports**: Media servers that don't use ephemeral ports for media sessions
- **Pre-verified Connections**: Systems that complete ICE verification before accepting any DTLS traffic

## Testing Checklist

Before deploying mitigations, verify:

- [ ] All media servers are updated to patched versions
- [ ] ICE consent verification is enabled
- [ ] Invalid cipher suites are rejected
- [ ] Rate limiting is configured for DTLS handshakes
- [ ] Monitoring is in place for handshake failures
- [ ] Firewall rules restrict media port access
- [ ] Test results are documented

## Reporting

When documenting findings:

1. **Vulnerability Details**
   - Affected systems and versions
   - Port ranges tested
   - Success rate of exploitation attempts

2. **Risk Assessment**
   - Impact: Service disruption for WebRTC users
   - Likelihood: Medium (requires network access and port knowledge)
   - Exploitability: Medium (requires timing precision)

3. **Remediation Status**
   - Mitigations implemented
   - Remaining risks
   - Follow-up testing scheduled

## References

- [Original Research](https://www.rtcsec.com/article/novel-dos-vulnerability-affecting-webrtc-media-servers/)
- [WebRTC Security Best Practices](https://www.w3.org/TR/webrtc-security/)
- [DTLS Specification](https://datatracker.ietf.org/doc/html/rfc6347)
- [ICE Specification](https://datatracker.ietf.org/doc/html/rfc8445)

## Safety Notice

**This skill is for authorized security testing only.** Unauthorized testing of WebRTC infrastructure may:
- Violate terms of service
- Trigger security incidents
- Be illegal in many jurisdictions

Always obtain written authorization before testing any system you don't own.
