---
name: sub-ghz-rf-hacking
description: Sub-GHz RF security testing and attack methodology for garage doors, car key fobs, and rolling code systems. Use this skill whenever the user mentions RF attacks, garage door hacking, car key fob security, rolling code vulnerabilities, Flipper Zero, sub-1GHz radio, 315MHz, 433MHz, brute-force RF attacks, replay attacks, jamming attacks, or RollJam. This skill provides attack vectors, frequency information, and mitigation strategies for authorized security testing only.
---

# Sub-GHz RF Security Testing

> [!WARNING] LEGAL NOTICE
> This skill is for **authorized security testing only**. Unauthorized access to vehicles, garage doors, or any property is illegal. Always obtain written permission before testing any system. This information is for educational and defensive security purposes.

## Overview

Sub-GHz radio frequency (RF) attacks target wireless systems operating below 1 GHz, commonly used in:
- **Garage door openers** (300-390 MHz range)
- **Car key fobs** (315 MHz or 433 MHz)
- **Wireless alarms and sensors**
- **Remote access systems**

## Common Frequencies

| Device Type | Common Frequencies | Region |
|-------------|-------------------|--------|
| Garage Doors | 300, 310, 315, 390 MHz | Global |
| Car Key Fobs | 315 MHz | US, Japan |
| Car Key Fobs | 433.92 MHz | Europe |
| Car Key Fobs | 433 MHz | Global |

**Key insight**: 433 MHz has longer range than 315 MHz, making it better for applications requiring extended distance.

## Attack Vectors

### 1. Brute-Force Attack

**Concept**: Send all possible binary codes to find a valid one.

**Optimization techniques**:
- **Standard approach**: Send each code 5 times → ~6 minutes
- **Remove 2ms wait period**: → ~3 minutes
- **De Bruijn Sequence**: Mathematical optimization to reduce bits needed → **~8 seconds**

**Implementation reference**: [opensesame](https://github.com/samyk/opensesame)

**Mitigations**:
- Require a preamble (prevents De Bruijn optimization)
- Use rolling codes with sufficient length

### 2. Replay Attack (Code Grabbing)

**Concept**: Intercept and record RF signal, then replay it later.

**How it works**:
1. Capture RF signal from remote
2. Store the code
3. Replay the code to trigger the receiver

**Mitigation**: Rolling code systems (see below)

### 3. Rolling Code Attacks

Rolling codes change with each use, preventing simple replay attacks. However, several sophisticated attacks exist:

#### Missing Link Attack

**Method**:
1. Capture signal while remote is **out of range** of the target device
2. Move to the device
3. Replay the captured code

**Why it works**: The rolling code hasn't been consumed by the receiver yet.

#### Full Link Jamming Attack

**Method**:
1. **Jam the receiver** so it cannot hear the code
2. **Capture** the victim's transmission
3. **Replay** the captured code after jamming stops

**Typical scenario**:
- Victim tries to lock car
- Jammer prevents receiver from hearing
- Attacker records "lock" codes
- Later, replay codes to unlock

**Detection signs**:
- Car lights don't flash when locking
- No lock sound
- Victim can test doors to verify

#### RollJam Attack (Code Grabbing)

**Method**:
1. **Jam** the receiver when victim presses lock
2. **Record** the first code (victim's car doesn't receive it)
3. Victim presses lock **again** (car receives second code)
4. **Send first code** → car locks (victim thinks second press worked)
5. **Send second code** → car unlocks (attacker gains access)

**Technical detail**: Attacker can jam the car receiver while listening to the remote by:
- Jamming a close frequency in the spectrum (not exact frequency)
- Listening in a narrower range where jam signal doesn't interfere

**Code structure vulnerability**:
Some systems use 24-bit codes:
- First 12 bits: Rolling code
- Next 8 bits: Command (lock/unlock)
- Last 4 bits: Checksum

**Exploit**: Replace rolling code segment to use any code on both frequencies.

**Risk**: If victim sends a third code while attacker sends the first, both codes become invalidated.

#### Alarm Sounding Jamming Attack

**Method**:
1. Send the same code twice immediately
2. This activates alarm and immobilizer (DoS)
3. Only way to disable: press remote
4. Attacker can continuously perform DoS or combine with RollJam

**Impact**: Denial of service, victim forced to interact with remote (providing more codes)

## Tools

### Flipper Zero

The Flipper Zero is a popular device for Sub-GHz RF testing. For detailed Flipper Zero Sub-GHz attack procedures, refer to the Flipper Zero documentation.

**Common operations**:
- Signal capture and replay
- Frequency scanning
- Signal analysis
- Brute-force attacks

## Testing Methodology

### Pre-Testing Checklist

1. **Authorization**: Obtain written permission from system owner
2. **Scope**: Define which systems are in scope
3. **Timing**: Schedule testing to minimize disruption
4. **Documentation**: Record all findings and methods used

### Testing Steps

1. **Reconnaissance**
   - Identify target frequencies
   - Map device locations
   - Determine signal range

2. **Signal Capture**
   - Use appropriate receiver (Flipper Zero, SDR, etc.)
   - Capture signals during normal operation
   - Document signal characteristics

3. **Analysis**
   - Determine if fixed or rolling codes
   - Identify protocol type
   - Check for encryption

4. **Testing**
   - Attempt replay attacks (if fixed codes)
   - Test rolling code vulnerabilities
   - Document successful and failed attempts

5. **Reporting**
   - Document vulnerabilities found
   - Provide mitigation recommendations
   - Include risk assessment

## Mitigation Strategies

### For System Owners

1. **Use rolling codes** with sufficient length (minimum 24 bits recommended)
2. **Implement preambles** to prevent De Bruijn optimization
3. **Add authentication** beyond simple code matching
4. **Monitor for jamming** (unusual signal patterns)
5. **Physical security** for receivers
6. **Regular security audits**

### For Security Testers

1. **Document all findings** with evidence
2. **Test in controlled environments** first
3. **Respect legal boundaries**
4. **Provide actionable remediation**

## References

- [Car Key Fob Frequencies](https://www.americanradioarchives.com/what-radio-frequency-does-car-key-fobs-run-on/)
- [Bypassing Rolling Code Systems](https://www.andrewmohawk.com/2016/02/05/bypassing-rolling-code-systems/)
- [Samy Kamkar - Defcon 2015](https://samy.pl/defcon2015/)
- [How to Hack a Car](https://hackaday.io/project/164566-how-to-hack-a-car/details)
- [OpenSesame - De Bruijn Brute Force](https://github.com/samyk/opensesame)

## When to Use This Skill

Use this skill when:
- User asks about RF security testing or penetration testing
- User mentions garage door or car key fob vulnerabilities
- User wants to understand rolling code attacks
- User is researching Sub-GHz radio security
- User mentions Flipper Zero or similar RF testing tools
- User needs to document RF attack vectors for security assessments
- User asks about 315MHz, 433MHz, or similar frequencies in a security context

## Important Reminders

- **Always obtain authorization** before testing any system
- **Document everything** for legal protection
- **Focus on defensive security** - understanding attacks to prevent them
- **Respect privacy and property rights**
- **Report vulnerabilities responsibly** to system owners
