---
name: voip-protocols-reference
description: Reference guide for VoIP protocols in pentesting. Use this skill when analyzing VoIP infrastructure, identifying protocols in network traffic, or understanding VoIP attack surfaces. Covers SIP, MGCP, SCCP, H.323, IAX, SDP, RTP, RTCP, SRTP, and ZRTP. Make sure to use this skill whenever the user mentions VoIP, SIP, phone systems, PBX, Asterisk, Cisco Unified Communications, or any voice-over-IP related pentesting or analysis.
---

# VoIP Protocols Reference for Pentesting

This skill provides comprehensive reference information about VoIP protocols commonly encountered during network security assessments and penetration testing.

## Quick Protocol Identification

| Protocol | Port(s) | Type | Primary Use |
|----------|---------|------|-------------|
| SIP | 5060/5061 (TCP/UDP/TLS) | Signaling | Call setup/teardown |
| MGCP | 2427 (UDP) | Signaling | Gateway control |
| SCCP | 2000 (TCP) | Signaling | Cisco IP phones |
| H.323 | 1720 (TCP) | Signaling | Video/audio conferencing |
| IAX | 4569 (UDP) | Signaling | Asterisk trunking |
| RTP | 10000-20000 (UDP) | Media | Audio/video transport |
| RTCP | +1 from RTP (UDP) | Control | Quality monitoring |
| SDP | N/A (embedded) | Description | Session negotiation |

## Signaling Protocols

### SIP (Session Initiation Protocol)

**Overview**: Industry standard for VoIP call signaling. Text-based protocol using methods like INVITE, ACK, BYE, REGISTER.

**Key Characteristics**:
- Uses ports 5060 (UDP/TCP) and 5061 (TLS)
- Text-based (human-readable)
- Decentralized architecture
- Widely supported across vendors

**Pentesting Considerations**:
- Check for authentication bypass vulnerabilities
- Test for SIP flooding attacks
- Verify TLS encryption on port 5061
- Look for registration hijacking opportunities
- Examine INVITE message handling

**Common Attack Vectors**:
- SIP INVITE flooding (DoS)
- Registration hijacking
- Call interception
- Eavesdropping on unencrypted traffic
- Malicious REGISTER requests

### MGCP (Media Gateway Control Protocol)

**Overview**: Centralized call control protocol (RFC 3435) for managing media gateways.

**Architecture**:
1. **Call Agent/MGC**: Master controller managing call setup, modification, termination
2. **Media Gateways (MGs)**: Convert media between circuit-switched and packet-switched networks
3. **Signaling Gateways (SGs)**: Convert signaling between SS7 and IP networks

**Key Characteristics**:
- Uses port 2427 (UDP)
- Centralized control model
- Text-based protocol
- Common in carrier networks

**Pentesting Considerations**:
- Target the Call Agent (single point of control)
- Test gateway command injection
- Verify authentication between MGC and gateways
- Check for unauthorized gateway registration

### SCCP (Skinny Client Control Protocol)

**Overview**: Cisco proprietary protocol for IP phone communication with CallManager.

**Architecture**:
1. **Call Control Server**: Cisco Unified Communications Manager
2. **SCCP Endpoints**: Cisco IP phones, video endpoints
3. **Gateways**: Media conversion devices

**Key Characteristics**:
- Uses port 2000 (TCP)
- Binary protocol (not human-readable)
- Lightweight, minimal bandwidth
- Cisco-only ecosystem

**Pentesting Considerations**:
- Requires Cisco environment knowledge
- Binary protocol needs specialized tools
- Focus on CallManager vulnerabilities
- Check for rogue device registration
- Examine SCCP message integrity

### H.323

**Overview**: ITU-T protocol suite for multimedia communication over packet networks.

**Components**:
1. **Terminals**: IP phones, video conferencing systems
2. **Gateways**: Network conversion devices
3. **Gatekeepers**: Optional call control and management
4. **MCUs**: Multipoint conference management

**Key Characteristics**:
- Uses port 1720 (TCP) for call signaling
- Complex protocol suite
- Legacy systems still in use
- Supports audio/video codecs

**Pentesting Considerations**:
- Target gatekeeper services
- Test H.225/H.245 message handling
- Check for buffer overflow vulnerabilities
- Verify encryption implementation
- Examine MCU configuration

### IAX (Inter-Asterisk eXchange)

**Overview**: Binary protocol for Asterisk PBX communication.

**Key Features**:
- Single UDP port 4569 for signaling and media
- Binary protocol (efficient)
- Built-in trunking support
- Native encryption (RSA/AES)
- Peer-to-peer capable

**Pentesting Considerations**:
- Focus on Asterisk-specific vulnerabilities
- Test IAX2 authentication mechanisms
- Verify encryption implementation
- Check for trunking abuse
- Examine peer-to-peer routing

## Transmission & Transport Protocols

### SDP (Session Description Protocol)

**Overview**: Text format (RFC 4566) for describing multimedia sessions.

**Key Elements**:
- Session information (name, timing)
- Media stream characteristics
- Connection information (IP, port)
- Attributes (encryption, bandwidth)

**Usage Pattern**:
1. Initiator creates SDP description
2. SDP sent via signaling protocol (SIP, RTSP)
3. Receiver processes and responds
4. Negotiation completes

**Pentesting Considerations**:
- Analyze SDP for information disclosure
- Check for IP address leakage
- Verify codec negotiation security
- Examine encryption attribute handling

### RTP / RTCP / SRTP / ZRTP

#### RTP (Real-time Transport Protocol)
- **Purpose**: Audio/video delivery over IP
- **RFC**: 3550
- **Features**: Synchronization, sequencing, timestamping
- **Ports**: Typically 10000-20000 (UDP)

#### RTCP (Real-time Transport Control Protocol)
- **Purpose**: QoS monitoring and feedback
- **RFC**: 3550
- **Features**: Packet loss, jitter, round-trip time reporting
- **Ports**: RTP port + 1 (UDP)

#### SRTP (Secure Real-time Transport Protocol)
- **Purpose**: Encrypted media transmission
- **RFC**: 3711
- **Features**: AES encryption, HMAC-SHA1 authentication, replay protection
- **Usage**: Combined with SIP over TLS for end-to-end security

#### ZRTP (Zimmermann Real-time Transport Protocol)
- **Purpose**: End-to-end encryption without PKI
- **RFC**: 6189
- **Features**: Diffie-Hellman key exchange, Short Authentication Strings (SAS)
- **Advantage**: Works independently of signaling protocol

**Pentesting Considerations**:
- Capture and analyze RTP streams for eavesdropping
- Test for weak encryption implementation
- Verify SRTP key exchange mechanisms
- Check for RTCP information disclosure
- Examine ZRTP SAS verification

## Protocol Analysis Workflow

### Step 1: Identify Active Protocols

1. **Port Scanning**: Check common VoIP ports
   ```
   nmap -p 5060,5061,2427,2000,1720,4569,10000-20000 <target>
   ```

2. **Service Detection**: Identify running services
   ```
   nmap -sV -p 5060,5061 <target>
   ```

3. **Traffic Analysis**: Use Wireshark/tcpdump to identify protocols
   ```
   tcpdump -i <interface> -s 0 -w voip.pcap port 5060 or port 4569
   ```

### Step 2: Enumerate Services

- **SIP**: Send OPTIONS request to enumerate endpoints
- **MGCP**: Query Call Agent for gateway information
- **SCCP**: Analyze Cisco phone registration patterns
- **H.323**: Query gatekeeper for terminal information
- **IAX**: Check Asterisk peer configurations

### Step 3: Test Security Controls

1. **Authentication**: Test credential validation
2. **Encryption**: Verify TLS/SRTP implementation
3. **Authorization**: Check access control mechanisms
4. **Integrity**: Test message tampering detection

### Step 4: Document Findings

- Protocol versions and configurations
- Encryption status and implementation
- Authentication mechanisms
- Identified vulnerabilities
- Risk assessment

## Common Tools

| Tool | Purpose | Protocols |
|------|---------|----------|
| Wireshark | Packet capture/analysis | All |
| SIPVicious | SIP testing | SIP |
| Responder | LLMNR/NBT-NS spoofing | Network |
| tcpdump | Packet capture | All |
| Asterisk CLI | Asterisk management | IAX, SIP |
| VoIPcrack | SIP password cracking | SIP |

## Security Best Practices

1. **Encryption**: Use TLS for signaling (SIPS) and SRTP for media
2. **Authentication**: Strong credentials, certificate-based where possible
3. **Network Segmentation**: Isolate VoIP traffic from general network
4. **Firewall Rules**: Restrict VoIP ports to necessary sources
5. **Monitoring**: Log and monitor VoIP traffic for anomalies
6. **Updates**: Keep PBX and endpoint firmware current
7. **VLANs**: Separate voice and data traffic
8. **QoS**: Prioritize voice traffic appropriately

## References

- RFC 3261: SIP Specification
- RFC 3435: MGCP Specification
- RFC 4566: SDP Specification
- RFC 3550: RTP/RTCP Specification
- RFC 3711: SRTP Specification
- RFC 6189: ZRTP Specification
