---
name: infrared-security
description: Analyze infrared (IR) protocols, assess IR-based attack vectors, and provide security guidance for IR-enabled devices. Use this skill whenever the user asks about infrared remote control security, IR protocol analysis, Flipper Zero IR capabilities, smart TV/AC IR vulnerabilities, or IR-based data exfiltration attacks. Trigger for any IR-related security assessment, protocol reverse engineering, or defensive hardening questions.
---

# Infrared Security Analysis

A skill for analyzing IR protocols, understanding attack vectors, and providing security guidance for infrared-enabled devices.

## When to Use This Skill

Use this skill when the user needs help with:
- Understanding IR protocol structures and encoding methods
- Assessing IR-based attack vectors (EvilScreen, aIR-Jumper, brute-force)
- Analyzing IR signals from remotes, smart TVs, air conditioners, or IoT devices
- Setting up IR capture/analysis tooling (Flipper Zero, Arduino, LIRC)
- Developing defensive measures for IR-enabled systems
- Reverse engineering unknown IR protocols

## IR Protocol Fundamentals

### Core Concepts

**IR Wavelength Range**: 0.7 to 1000 microns (household remotes: 0.75-1.4 microns)

**Signal Flow**:
1. Microcontroller modulates IR LED with specific frequency
2. Digital signal → IR light pulses
3. Photoreceiver converts IR light → voltage pulses (digital)
4. Dark light filter removes noise, passes only desired wavelength

### Bit Encoding Methods

| Encoding Type | How It Works | Key Characteristic |
|--------------|--------------|-------------------|
| **Pulse Distance** | Modulate space duration between pulses | Pulse width constant |
| **Pulse Width** | Modulate pulse width | Space after pulse constant |
| **Phase (Manchester)** | Transition polarity defines value | Space→pulse = 0, pulse→space = 1 |
| **Hybrid** | Combination of above | Protocol-specific |

### Common Protocols

**NEC Protocol** (most common):
- Preamble → Address byte → Command byte → Inverted address → Inverted command → Stop bit
- Uses Pulse Distance Encoding
- Includes repeat code for held buttons
- 32-bit structure with integrity checking

**RC5 Protocol**:
- Universal protocol attempt
- Less common in practice
- Uses Manchester encoding

**Sharp Protocol**:
- No preamble
- Protocol-specific structure

**Important**: Manufacturers often use proprietary protocols even within same device category. Universal protocols are not universal.

## Attack Vectors

### 1. Smart TV/STB Takeover (EvilScreen)

**Mechanism**: Multi-channel remotes combining IR + Bluetooth/Wi-Fi enable full device hijacking

**Impact**:
- Arbitrary app launches
- Microphone activation
- Factory reset
- Bypasses channel isolation

**Affected**: 8+ mainstream TV vendors (including ISO 27001 certified)

**Mitigation**:
- Vendor firmware patches
- Disable unused IR receivers
- Isolate privileged service codes

### 2. Air-Gapped Data Exfiltration (aIR-Jumper)

**Mechanism**: Malware modulates IR LEDs (night-vision, cameras, routers) to exfiltrate data

**Characteristics**:
- Rate: 10-20 kbit/s with simple OOK
- Range: Tens of meters through walls/windows
- Invisible to human eye
- Can also infiltrate commands via IR projectors

**Countermeasures**:
- Physically shield/remove IR LEDs in sensitive areas
- Monitor LED duty-cycle and firmware integrity
- Deploy IR-cut filters on windows and cameras

### 3. Long-Range Brute-Force

**Flipper Zero 1.0+**:
- Dozens of additional IR protocols
- External amplifier modules
- Universal remote brute-force mode
- Range: Up to 30m with high-power diode
- Targets: Public TVs, ACs, set-top boxes

## Tooling Setup

### Hardware Options

| Tool | Use Case | Notes |
|------|----------|-------|
| **Flipper Zero** | Learning, replay, dictionary brute-force | Portable, firmware 1.0+ recommended |
| **Arduino/ESP32 + IR LED/TSOP38xx** | DIY analyzer/transmitter | Use Arduino-IRremote v4.x (40+ protocols) |
| **Logic Analyzer** (Saleae/FX2) | Raw timing capture for unknown protocols | Essential for reverse engineering |
| **Smartphone IR Blaster** (Xiaomi) | Quick field testing | Limited range |

### Software Stack

**Arduino-IRremote Library**:
```cpp
#include <IRremote.hpp>
IRsend sender;
void setup(){ sender.begin(); }
void loop(){
  sender.sendNEC(0x20DF10EF, 32); // Samsung TV Power
  delay(5000);
}
```

**Linux IR Tools**:
```bash
# Live decode scancodes
sudo ir-keytable -p nec,rc5 -t

# Send IR command
irsend SEND_ONCE samsung KEY_POWER
```

**GUI Decoders**:
- IRscrutinizer / AnalysIR: Import raw captures, auto-identify protocol, generate Pronto/Arduino code

## Analysis Workflow

### Step 1: Signal Capture

1. **With oscilloscope**: View raw signal "as is" (no demodulation)
2. **With logic analyzer**: Capture timing for unknown protocols
3. **With Flipper Zero**: Learn mode for known protocols

### Step 2: Protocol Identification

Look for:
- **Preamble**: Most protocols have one (Sharp is exception)
- **Bit encoding**: Measure pulse/space durations
- **Data structure**: Address/command bytes, checksums
- **Repeat codes**: Sent while button held (NEC)

### Step 3: Decode and Document

Use `scripts/analyze_ir_timing.py` to parse raw timing data and identify protocol characteristics.

### Step 4: Security Assessment

Evaluate:
- Is device in public space? (IR receiver exposure)
- Does it use service codes? (privilege escalation risk)
- Is it paired/authenticated? (EvilScreen vulnerability)
- Are IR LEDs controllable? (aIR-Jumper risk)

## Defensive Recommendations

### Device Hardening

1. **Disable IR receivers** on devices in public spaces when not required
2. **Enforce pairing** or cryptographic checks between remotes and devices
3. **Isolate privileged service codes** from standard user commands
4. **Monitor firmware integrity** of cameras/IoT with controllable IR LEDs

### Physical Security

1. **IR-cut filters** on windows in classified areas
2. **Continuous-wave IR detectors** to detect covert channels
3. **Physical shielding** or removal of IR LEDs in sensitive zones
4. **Monitor LED duty-cycle** for anomalous modulation

### Network Security

1. **Disable unused IR receivers** on smart TVs
2. **Patch vendor firmware** for known vulnerabilities (EvilScreen)
3. **Segment IR-enabled devices** from critical systems

## Common Use Cases

### Analyzing Unknown Remote

1. Capture signal with logic analyzer or Flipper Zero
2. Run timing analysis to identify encoding method
3. Compare against known protocols (NEC, RC5, Sharp)
4. Document address/command structure
5. Test with Arduino-IRremote or LIRC

### Assessing Smart TV Security

1. Check if TV uses multi-channel remote (IR + Bluetooth/Wi-Fi)
2. Test for service code exposure
3. Verify firmware is patched for EvilScreen
4. Consider disabling IR if not needed
5. Document findings and remediation steps

### Setting Up IR Capture Lab

1. Acquire hardware (Flipper Zero or Arduino + TSOP38xx)
2. Install software stack (Arduino-IRremote, LIRC)
3. Calibrate with known remotes
4. Document protocol library
5. Establish baseline for anomaly detection

## References

- Flipper Zero Infrared: https://blog.flipperzero.one/infrared/
- EvilScreen (arXiv 2210.03014): Smart TV hijacking via remote control mimicry
- Arduino-IRremote: https://github.com/Arduino-IRremote/Arduino-IRremote
- LIRC: https://lirc.org/

## Scripts

Use bundled scripts for common tasks:
- `scripts/analyze_ir_timing.py` - Parse raw timing data, identify protocol
- `scripts/generate_ir_code.py` - Generate Arduino/LIRC code from protocol data
- `scripts/ir_security_checklist.md` - Security assessment template

Run scripts with: `python scripts/<script-name>.py [args]`
