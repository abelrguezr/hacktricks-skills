---
name: flipper-zero-subghz
description: Use Flipper Zero to analyze, capture, and replay Sub-GHz radio signals (300-928 MHz) for testing gates, barriers, remote controls, doorbells, and wireless devices. Use this skill whenever the user mentions Flipper Zero, Sub-GHz, radio frequencies, remote controls, garage doors, gate openers, or wireless signal analysis. Also trigger for any request about reading, capturing, or replaying radio signals with Flipper Zero.
---

# Flipper Zero Sub-GHz Operations

This skill guides you through using Flipper Zero's Sub-GHz module to analyze, capture, and replay radio signals in the 300-928 MHz range.

## Quick Reference

| Operation | Use Case |
|-----------|----------|
| **Frequency Analyzer** | Find what frequency a remote uses |
| **Read** | Decode signal and get protocol info |
| **Read Raw** | Capture raw signal for replay |
| **Add Manually** | Add known protocols from list |
| **Brute-Force** | Test static code systems (advanced) |

---

## 1. Frequency Analyzer - Find Remote Frequency

Use this when you don't know what frequency a remote control operates on.

### Steps

1. Place the remote control very close to the left side of Flipper Zero
2. Navigate: **Main Menu → Sub-GHz → Frequency Analyzer**
3. Press and hold the button on the remote control
4. Observe the frequency value displayed on screen

### What to expect

- Flipper scans all available frequencies in your region's configuration
- Displays the frequency with highest RSSI (signal strength)
- Only shows signals stronger than -90 dBm
- Common frequencies: 315 MHz, 433.92 MHz, 390 MHz

### Pro tip

If no frequency appears, try:
- Moving the remote closer to Flipper
- Pressing the button multiple times
- Checking if the remote has a working battery

---

## 2. Read - Decode Signal Protocol

Use this to identify the protocol and modulation of a signal.

### Steps

1. Navigate: **Main Menu → Sub-GHz → Read**
2. Press the **left button** to configure frequency/modulation
3. Select the frequency you found (or use default 433.92 AM)
4. Press the remote button to transmit
5. Review the protocol information displayed

### Configuration options

**Modulations available:**
- AM270
- AM650 (default)
- FM328
- FM476

**Common frequencies:**
- 300.00 MHz
- 310.00 MHz
- 315.00 MHz
- 390.00 MHz
- 433.92 MHz

### Hopping mode

If you're unsure which frequency to use:
1. Press left button in Read mode
2. Set **Hopping to ON**
3. Press the remote button several times
4. Flipper will cycle through frequencies and capture the signal

> **Note:** Switching between frequencies takes time. For best results, use Frequency Analyzer first to find the exact frequency, then use a fixed frequency in Read mode.

---

## 3. Read Raw - Capture for Replay

Use this to steal and replay a signal exactly as transmitted.

### Steps

1. Navigate: **Main Menu → Sub-GHz → Read Raw**
2. Press **left button** to configure if needed
3. Set the correct frequency and modulation (from Read step)
4. Press the remote button
5. Flipper captures the raw signal
6. Save the signal to your library
7. Replay by selecting the saved signal and pressing **Send**

### When to use Read Raw vs Read

| Read | Read Raw |
|------|----------|
| Decodes protocol info | Captures exact signal |
| Good for understanding | Good for replay |
| May not work with rolling codes | Works with any signal |
| Can add to library as protocol | Saves as raw waveform |

---

## 4. Add Manually - Known Protocols

Use this when you know the protocol type and want to add it directly.

### Supported Static Code Protocols

| Protocol | Frequency | Type |
|----------|-----------|------|
| Princeton_433 | 433.92 | Static |
| Nice Flo 12bit_433 | 433.92 | Static |
| Nice Flo 24bit_433 | 433.92 | Static |
| CAME 12bit_433 | 433.92 | Static |
| CAME 24bit_433 | 433.92 | Static |
| Linear_300 | 300.00 | Static |
| CAME TWEE | 433.92 | Static |
| Gate TX_433 | 433.92 | Static |

### Supported Dynamic Code Protocols

| Protocol | Frequency | Type |
|----------|-----------|------|
| DoorHan_315 | 315.00 | Dynamic |
| DoorHan_433 | 433.92 | Dynamic |
| LiftMaster_315 | 315.00 | Dynamic |
| LiftMaster_390 | 390.00 | Dynamic |
| Security+2.0_310 | 310.00 | Dynamic |
| Security+2.0_315 | 315.00 | Dynamic |
| Security+2.0_390 | 390.00 | Dynamic |

### Steps to add manually

1. Navigate: **Main Menu → Sub-GHz → Add Manually**
2. Select the protocol from the list
3. Enter the required code (varies by protocol)
4. Save to your library
5. Test by sending the signal

---

## 5. Brute-Force - Test Static Code Systems

Use this for testing security of static code garage door systems.

### Requirements

- Know the protocol used by the target system
- System must use static codes (not rolling codes)
- Have the brute-force tool installed

### Recommended tool

[tobiabocchi/flipperzero-bruteforce](https://github.com/tobiabocchi/flipperzero-bruteforce)

This tool generates and sends all possible codes for common garage door protocols.

### Steps

1. Install the brute-force tool on Flipper Zero
2. Identify the protocol of the target system
3. Run the brute-force attack for that protocol
4. Monitor for successful responses

> **Warning:** Only use brute-force on systems you own or have explicit permission to test.

---

## 6. Test - Verify Signal Strength

Use this to check the dBm values of saved frequencies.

### Steps

1. Navigate: **Main Menu → Sub-GHz → Test**
2. Select a saved signal
3. Send the signal
4. Observe the dBm reading

### Interpreting dBm values

| dBm | Signal Quality |
|-----|----------------|
| -30 to -50 | Excellent |
| -50 to -70 | Good |
| -70 to -90 | Fair |
| Below -90 | Poor/Unreliable |

---

## Regional Frequency Support

Flipper Zero supports different frequency bands by region:

- **300-348 MHz** - Available in most regions
- **387-464 MHz** - Available in most regions  
- **779-928 MHz** - Available in most regions

Check your region's supported frequencies at: https://docs.flipperzero.one/sub-ghz/frequencies

---

## Hardware Specifications

- **Chip:** CC1101 (Texas Instruments)
- **Range:** Up to 50 meters (line of sight)
- **Frequency range:** 300-928 MHz
- **Modulations:** AM270, AM650, FM328, FM476

---

## Troubleshooting

### No signal detected

1. Verify the remote has a working battery
2. Move the remote closer to Flipper Zero
3. Use Frequency Analyzer to find the correct frequency
4. Try Hopping mode in Read
5. Check if the frequency is supported in your region

### Signal captured but won't replay

1. Verify you're using the correct modulation
2. Check signal strength with Test mode
3. Try Read Raw instead of Read for exact capture
4. Ensure you're within range of the receiver

### Rolling codes won't work

- Rolling codes change with each transmission
- Read Raw captures only one instance
- You need to capture and replay in real-time
- Some systems require learning mode on the receiver

---

## Safety and Legal Considerations

⚠️ **Important:** Only use Flipper Zero Sub-GHz features on:

- Systems you own
- Systems you have explicit written permission to test
- Your own security research in controlled environments

**Do not:**
- Test systems without authorization
- Use captured signals to gain unauthorized access
- Interfere with emergency services frequencies
- Violate local radio frequency regulations

---

## References

- [Flipper Zero Sub-GHz Documentation](https://docs.flipperzero.one/sub-ghz)
- [Supported Vendors](https://docs.flipperzero.one/sub-ghz/supported-vendors)
- [Add New Remote Guide](https://docs.flipperzero.one/sub-ghz/add-new-remote)
- [CC1101 Chip Datasheet](https://www.ti.com/lit/ds/symlink/cc1101.pdf)
- [Brute-Force Tool](https://github.com/tobiabocchi/flipperzero-bruteforce)
