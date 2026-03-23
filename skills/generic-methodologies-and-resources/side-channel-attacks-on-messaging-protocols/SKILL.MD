---
name: delivery-receipt-side-channel
description: How to execute delivery receipt side-channel attacks on E2EE messengers (WhatsApp, Signal, Threema). Use this skill whenever the user wants to probe messaging protocols for timing leaks, fingerprint devices, monitor user behavior through RTT analysis, or understand silent delivery receipt vulnerabilities. Trigger on any request about messenger security testing, protocol-level reconnaissance, device fingerprinting via messaging apps, or covert channel exploitation.
---

# Delivery Receipt Side-Channel Attacks on E2EE Messengers

This skill enables security researchers to exploit delivery receipt timing channels in end-to-end encrypted messengers. Delivery receipts are mandatory for cryptographic state management, creating unavoidable timing side-channels that leak device state, online presence, and behavioral patterns.

## When to Use This Skill

Use this skill when you need to:
- Probe WhatsApp, Signal, or Threema for timing-based information leakage
- Fingerprint victim devices through receipt counting and RTT clustering
- Monitor user behavior patterns (screen on/off, app foreground/background, commuting schedules)
- Execute silent reconnaissance without appearing in victim chat lists
- Understand the cryptographic necessity of delivery receipts and why they can't be disabled
- Design or analyze covert DoS attacks against messaging clients

## Core Attack Vectors

### Silent Message Types by Platform

| Messenger | Action | Delivery Receipt | Victim Notification | Notes |
|-----------|--------|------------------|---------------------|-------|
| **WhatsApp** | Text message | ● | ● | Always noisy → only useful to bootstrap state |
| | Reaction | ● | ◐ (only if reacting to victim message) | Self-reactions and removals stay silent |
| | Edit | ● | Platform-dependent silent push | Edit window ≈20 min; still ack'd after expiry |
| | Delete for everyone | ● | ○ | UI allows ~60 h, but later packets still ack'd |
| **Signal** | Text message | ● | ● | Same limitations as WhatsApp |
| | Reaction | ● | ◐ | Self-reactions invisible to victim |
| | Edit/Delete | ● | ○ | Server enforces ~48 h window, allows up to 10 edits, but late packets still ack'd |
| **Threema** | Text message | ● | ● | Multi-device receipts are aggregated, so only one RTT per probe becomes visible |

Legend: ● = always, ◐ = conditional, ○ = never

### Threat Actor Models

**Creepy Companion**
- Already shares a chat with the victim
- Abuses self-reactions, reaction removals, or repeated edits/deletes tied to existing message IDs
- No prior conversation required beyond initial chat establishment

**Spooky Stranger**
- Registers a burner account
- Sends reactions referencing message IDs that never existed in the local conversation
- WhatsApp and Signal still decrypt and acknowledge them even though the UI discards the state change
- No prior conversation required at all

## Tooling Setup

### WhatsApp

**whatsmeow** (Go, WhatsApp Web protocol)
```bash
go get github.com/tulir/whatsmeow
# Provides: ReactionMessage, ProtocolMessage (edit/delete), Receipt frames
# Keeps double-ratchet state in sync
```

**Cobalt** (mobile-oriented)
```bash
# Alternative for mobile deployments
# https://github.com/Auties00/Cobalt
```

### Signal

**signal-cli** with **libsignal-service-java**
```bash
# Self-reaction toggle example
signal-cli -u +12025550100 sendReaction --target +12025550123 \
    --message-timestamp 1712345678901 --emoji "👍"

# Remove reaction (empty emoji)
signal-cli -u +12025550100 sendReaction --target +12025550123 \
    --message-timestamp 1712345678901 --remove
```

### Threema

Review the Android client source to understand how delivery receipts are consolidated before leaving the device. The side channel has negligible bandwidth there due to aggregation.

## Attack Execution Patterns

### Pattern 1: Silent Sampling Loop (Creepy Companion)

1. Pick any historical message you authored in the chat so the victim never sees "reaction" balloons change
2. Alternate between a visible emoji and an empty reaction payload
3. Timestamp the send time and every delivery receipt arrival
4. Run at 1 Hz for per-device RTT traces indefinitely

```python
# See scripts/silent_probe_loop.py for implementation
while True:
    send_reaction(msg_id, "👍")
    log_receipts()
    send_reaction(msg_id, "")  # removal
    log_receipts()
    time.sleep(0.5)
```

### Pattern 2: Arbitrary Phone Probing (Spooky Stranger)

1. Register a fresh WhatsApp/Signal account
2. Fetch the public identity keys for the target number (automatic during session setup)
3. Craft a reaction/edit/delete packet referencing a random `message_id` never seen by either party
4. Send the packet even though no thread exists
5. Victim devices decrypt, fail to match the base message, discard the state change, but still acknowledge
6. Repeat continuously to build RTT series without ever appearing in the victim's chat list

### Pattern 3: Recycling Edits and Deletes

**Repeated deletes:** After a message is deleted-for-everyone once, further delete packets referencing the same `message_id` have no UI effect but every device still decrypts and acknowledges them.

**Out-of-window operations:** WhatsApp enforces ~60 h delete / ~20 min edit windows in the UI; Signal enforces ~48 h. Crafted protocol messages outside these windows are silently ignored on the victim device yet receipts are transmitted.

**Invalid payloads:** Malformed edit bodies or deletes referencing already purged messages elicit the same behaviour—decryption plus receipt, zero user-visible artefacts.

## Analysis Techniques

### Device Fingerprinting (G1)

1. **Count receipts per probe** - Reveals exact device count
2. **Cluster RTTs** - Infer OS/client (Android vs iOS vs desktop) using k-means on median/variance features
3. **Watch online/offline transitions** - Gaps in receipt timing leak connectivity cycles
4. **Monitor device pairing** - Sudden increase in device count or new RTT cluster indicates new device registration

### Behavioral Monitoring (G2)

1. **Sample at ≥1 Hz** to capture OS scheduling effects
2. **Build classifiers** - Thresholding or two-cluster k-means labels each RTT as "active" or "idle"
3. **Aggregate labels into streaks** - Derive bedtimes, commutes, work hours, desktop companion activity
4. **Correlate simultaneous probes** - See when users switch from mobile to desktop, when companions go offline

**Platform-specific correlations:**
- WhatsApp on iOS: <1 s RTTs strongly correlate with screen-on/foreground, >1 s with screen-off/background throttling
- Desktop receipts stop during travel (commuting schedules)
- Push vs persistent socket rate limiting patterns

### Resource Exhaustion (G3)

Continuously sending reaction toggles, invalid edits, or delete-for-everyone packets creates application-layer DoS:

- Forces radio/modem to transmit/receive every second → noticeable battery drain
- Generates unmetered upstream/downstream traffic consuming mobile data plans
- Occupies crypto threads and introduces jitter in latency-sensitive features (VoIP, video calls)

## Implementation Scripts

Use the bundled scripts for deterministic operations:

- `scripts/silent_probe_loop.py` - 1 Hz reaction toggle loop with receipt logging
- `scripts/rtt_analyzer.py` - Cluster RTTs and infer device types
- `scripts/behavior_classifier.py` - Build active/idle classifiers from RTT traces

## Ethical Considerations

This skill is for authorized security research only:
- Only test systems you own or have explicit written permission to test
- Understand that delivery receipts are cryptographically necessary and cannot be disabled
- Recognize that multi-device deployments amplify the attack surface
- Document findings responsibly and consider the privacy implications

## References

- [Careless Whisper: Exploiting Silent Delivery Receipts to Monitor Users on Mobile Instant Messengers](https://arxiv.org/html/2411.11194v4)
- [whatsmeow](https://github.com/tulir/whatsmeow)
- [Cobalt](https://github.com/Auties00/Cobalt)
- [signal-cli](https://github.com/AsamK/signal-cli)
- [libsignal-service-java](https://github.com/signalapp/libsignal-service-java)
