---
name: lpwan-security-assessment
description: Security assessment and penetration testing for Low-Power Wide Area Network (LPWAN) systems including LoRa, LoRaWAN, and related IoT wireless protocols. Use this skill whenever the user mentions LPWAN, LoRa, LoRaWAN, wireless IoT security, gateway security, SDR-based attacks, or needs to assess/attack/defend low-power wide area networks. Also trigger for DevNonce replay, OTAA/ABP security, frame counter attacks, or any LoRaWAN protocol analysis.
---

# LPWAN Security Assessment

A comprehensive skill for assessing and testing Low-Power Wide Area Network security, including LoRa physical layer and LoRaWAN MAC/network layer vulnerabilities.

## Quick Reference

**LPWAN** = Low-Power Wide Area Network (6+ mile range, 20-year battery life)
**LoRa** = Physical layer (Chirp Spread Spectrum by Semtech)
**LoRaWAN** = MAC/Network layer (LoRa-Alliance, versions 1.0.x/1.1)

**Architecture**: `end-device → gateway (packet-forwarder) → network-server → application-server`

**Security Model**: Two AES-128 root keys (AppKey/NwkKey) derive session keys during OTAA join or are hard-coded in ABP. **Key leak = full read/write capability**.

---

## Attack Surface Assessment

When assessing a LPWAN deployment, evaluate these layers:

| Layer | Weakness | Impact |
|-------|----------|--------|
| **PHY** | Reactive/selective jamming | 100% packet loss with single SDR, <1W output |
| **MAC** | Join-Accept & data-frame replay (nonce reuse, ABP counter rollover) | Device spoofing, message injection, DoS |
| **Network-Server** | Insecure packet-forwarder, weak MQTT/UDP filters, outdated gateway firmware | RCE on gateways → pivot into OT/IT network |
| **Application** | Hard-coded or predictable AppKeys | Brute-force/decrypt traffic, impersonate sensors |

---

## Known Vulnerabilities (2023-2025)

### CVE-2024-29862 - ChirpStack Gateway Bridge
- **Affected**: ChirpStack gateway-bridge & mqtt-forwarder
- **Issue**: Accepted TCP packets bypassing stateful firewall rules on Kerlink gateways
- **Impact**: Remote management interface exposure
- **Fixed**: 4.0.11 / 4.2.1

### Dragino LG01/LG308 Series
- **CVEs**: 2022-45227 (directory traversal), 2022-45228 (CSRF)
- **Status**: Still unpatched in 2025 on thousands of public gateways
- **Impact**: Unauthenticated firmware dump or config overwrite

### Semtech Packet-Forwarder UDP Overflow
- **Advisory**: Unreleased, patched 2023-10
- **Trigger**: Crafted uplink >255 bytes
- **Impact**: Stack-smash → RCE on SX130x reference gateways
- **Source**: Black Hat EU 2023 "LoRa Exploitation Reloaded"

---

## Practical Attack Techniques

### 1. Sniff & Decrypt Traffic

Capture LoRaWAN traffic with SDR equipment:

```bash
# Capture all channels around 868.3 MHz with USRP B205
python3 lorattack/sniffer.py \
    --freq 868.3e6 --bw 125e3 --rate 1e6 --sf 7 --session smartcity

# Brute-force AppKey from captured OTAA join-request/accept pairs
python3 lorapwn/bruteforce_join.py --pcap smartcity.pcap --wordlist top1m.txt
```

**Requirements**:
- SDR hardware (HackRF One, USRP B205, RTL-SDR for receive-only)
- GNU Radio or LoRa-specific tools
- PCAP capture for analysis

### 2. OTAA Join-Replay (DevNonce Reuse)

**Prerequisites**: Capture capability, replay capability, timing precision

**Steps**:
1. Capture a legitimate **JoinRequest** frame
2. Immediately retransmit it (or increment RSSI) before the original device transmits again
3. Network-server allocates new DevAddr & session keys
4. Target device continues with old session → attacker owns vacant session
5. Inject forged uplinks using the vacant session

**Why it works**: Network-server doesn't verify the original device is still using the session after allocating new keys.

### 3. Adaptive Data-Rate (ADR) Downgrading

**Goal**: Denial-of-service via duty-cycle exhaustion

**Method**:
- Force SF12/125 kHz to maximize airtime per packet
- Send network-level MAC commands to downgrade data rate
- Gateway duty-cycle exhausts while attacker battery impact remains low

**Impact**: Legitimate devices cannot transmit during duty-cycle windows.

### 4. Reactive Jamming

**Setup**: HackRF One + GNU Radio flowgraph

**Mechanism**:
- Detect preamble on target frequency
- Trigger wide-band chirp immediately
- Blocks all spreading factors

**Performance**: ≤200 mW TX achieves full outage at 2 km range.

---

## Offensive Tooling (2025)

| Tool | Purpose | Notes |
|------|---------|-------|
| **LoRaWAN Auditing Framework (LAF)** | Craft/parse/attack LoRaWAN frames, DB-backed analyzers, brute-forcer | Docker image, supports Semtech UDP input |
| **LoRaPWN** | Trend Micro Python utility to brute OTAA, generate downlinks, decrypt payloads | Demo released 2023, SDR-agnostic |
| **LoRAttack** | Multi-channel sniffer + replay with USRP; exports PCAP/LoRaTap | Good Wireshark integration |
| **gr-lora / gr-lorawan** | GNU Radio OOT blocks for baseband TX/RX | Foundation for custom attacks |

**Installation**:
```bash
# LAF (Docker)
docker pull ioactive/laf

# LoRaPWN
git clone https://github.com/TrendMicro/lorapwn
cd lorapwn && pip install -r requirements.txt

# LoRAttack
git clone https://github.com/IOActive/lorattack
cd lorattack && pip install -e .
```

---

## Defensive Recommendations (Pentester Checklist)

Use this checklist when providing remediation guidance:

### Device Configuration
- [ ] Prefer **OTAA** devices with truly random DevNonce; monitor for duplicates
- [ ] Enforce **LoRaWAN 1.1**: 32-bit frame counters, distinct FNwkSIntKey / SNwkSIntKey
- [ ] Store frame-counter in non-volatile memory (**ABP**) or migrate to OTAA
- [ ] Deploy **secure-element** (ATECC608A/SX1262-TRX-SE) to protect root keys against firmware extraction

### Network Infrastructure
- [ ] Disable remote UDP packet-forwarder ports (1700/1701) or restrict with WireGuard/VPN
- [ ] Keep gateways updated; Kerlink/Dragino provide 2024-patched images
- [ ] Implement **traffic anomaly detection** (e.g., LAF analyzer) – flag:
  - Counter resets
  - Duplicate joins
  - Sudden ADR changes
  - Unusual RSSI patterns

### Monitoring
- [ ] Log all JoinRequest/JoinAccept pairs
- [ ] Alert on DevNonce reuse
- [ ] Monitor for frame counter anomalies
- [ ] Track gateway firmware versions

---

## Quick Assessment Workflow

When starting a LPWAN security assessment:

1. **Reconnaissance**
   - Identify gateway locations and models
   - Determine frequency bands (868 MHz EU, 915 MHz US, 433 MHz Asia)
   - Map network topology (devices → gateways → servers)

2. **Passive Collection**
   - Deploy SDR to capture traffic
   - Identify active devices and join procedures
   - Extract DevEUI, AppEUI, DevNonce from OTAA joins

3. **Active Testing**
   - Attempt AppKey brute-force on captured joins
   - Test for DevNonce replay vulnerability
   - Probe gateway services (MQTT, UDP 1700/1701, web interfaces)
   - Check for known CVEs (CVE-2024-29862, Dragino vulnerabilities)

4. **Exploitation**
   - If keys recovered: decrypt traffic, inject messages
   - If gateway vulnerable: attempt RCE, pivot to internal network
   - If MAC layer vulnerable: replay attacks, DoS via ADR

5. **Reporting**
   - Document all findings with evidence (PCAPs, logs)
   - Provide remediation using defensive checklist
   - Prioritize by business impact

---

## References

- **LoRaWAN Auditing Framework (LAF)**: https://github.com/IOActive/laf
- **Trend Micro LoRaPWN**: https://www.hackster.io/news/trend-micro-finds-lorawan-security-lacking-develops-lorapwn-python-utility-bba60c27d57a
- **LoRaWAN Specification**: https://lora-alliance.org/resource-hub/lorawan-specification
- **Semtech SX130x Documentation**: https://www.semtech.com/products/wireless-rf/lora-gateways/sx130x

---

## When to Use This Skill

Trigger this skill for:
- LPWAN/LoRa/LoRaWAN security assessments
- IoT wireless protocol analysis
- SDR-based wireless attacks
- Gateway security testing
- Frame counter/DevNonce vulnerability analysis
- OTAA/ABP security evaluation
- Wireless IoT penetration testing
- LoRaWAN protocol exploitation
- Any request involving low-power wide area network security
