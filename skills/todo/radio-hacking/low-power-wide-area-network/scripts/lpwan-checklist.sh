#!/bin/bash
# LPWAN Security Assessment Checklist Generator
# Usage: ./lpwan-checklist.sh [output_file]

OUTPUT_FILE="${1:-lpwan-assessment-checklist.md}"

cat > "$OUTPUT_FILE" << 'EOF'
# LPWAN Security Assessment Checklist

## Pre-Assessment
- [ ] Define scope and rules of engagement
- [ ] Identify target frequency bands (868/915/433 MHz)
- [ ] Map gateway locations and models
- [ ] Obtain necessary authorizations

## Tooling Setup
- [ ] SDR hardware ready (HackRF One, USRP, RTL-SDR)
- [ ] LAF Docker container available
- [ ] LoRaPWN installed and configured
- [ ] LoRAttack ready for capture/replay
- [ ] GNU Radio with gr-lora blocks
- [ ] Wireshark with LoRaTap plugin

## Reconnaissance
- [ ] Identify active gateways in range
- [ ] Determine gateway models (Kerlink, Dragino, etc.)
- [ ] Map network topology
- [ ] Identify frequency channels in use
- [ ] Note spreading factors observed

## Passive Collection
- [ ] Deploy SDR for traffic capture
- [ ] Capture OTAA join procedures
- [ ] Extract DevEUI, AppEUI, DevNonce
- [ ] Identify ABP vs OTAA devices
- [ ] Log all JoinRequest/JoinAccept pairs
- [ ] Save PCAP for analysis

## Vulnerability Testing
- [ ] Test for CVE-2024-29862 (ChirpStack)
- [ ] Test for Dragino CVEs (2022-45227, 2022-45228)
- [ ] Attempt AppKey brute-force on captured joins
- [ ] Test DevNonce replay vulnerability
- [ ] Probe gateway services (MQTT, UDP 1700/1701)
- [ ] Check for unpatched firmware
- [ ] Test UDP packet-forwarder overflow (>255 bytes)

## Active Exploitation
- [ ] Attempt message injection (if keys recovered)
- [ ] Test ADR downgrading for DoS
- [ ] Attempt reactive jamming (if authorized)
- [ ] Test gateway RCE vectors
- [ ] Attempt network pivot (if gateway compromised)

## Defensive Review
- [ ] Verify OTAA with random DevNonce
- [ ] Confirm LoRaWAN 1.1 enforcement
- [ ] Check frame-counter storage (non-volatile for ABP)
- [ ] Verify secure-element deployment
- [ ] Confirm UDP ports 1700/1701 restricted
- [ ] Review gateway firmware versions
- [ ] Check traffic anomaly detection

## Reporting
- [ ] Document all findings with evidence
- [ ] Include PCAPs and logs
- [ ] Provide remediation recommendations
- [ ] Prioritize by business impact
- [ ] Create executive summary

## Post-Assessment
- [ ] Clean up test artifacts
- [ ] Return systems to baseline
- [ ] Archive evidence securely
- [ ] Debrief with stakeholders
EOF

echo "Checklist saved to $OUTPUT_FILE"
