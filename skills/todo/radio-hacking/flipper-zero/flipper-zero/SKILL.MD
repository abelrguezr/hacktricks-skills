---
name: flipper-zero-hacking
description: Use Flipper Zero for radio frequency testing, NFC/RFID capture and emulation, infrared signal analysis, iButton operations, BadUSB attacks, and U2F security testing. Use this skill whenever the user mentions Flipper Zero, wants to test wireless protocols, capture radio signals, emulate access cards, analyze infrared remotes, or perform hardware-based security assessments. Trigger for any Flipper Zero related tasks including Sub-GHz radio work, NFC card cloning, 125kHz RFID operations, infrared signal capture, iButton reading, BadUSB payloads, or U2F key operations.
---

# Flipper Zero Security Testing Skill

A comprehensive guide for using Flipper Zero in security assessments and hardware testing.

## Overview

Flipper Zero is a multi-tool for geeks that can interact with various radio frequencies, protocols, and hardware interfaces. This skill helps you leverage its capabilities for security testing, research, and learning.

## Core Capabilities

### 1. Sub-GHz Radio (300-928 MHz)

**What it does:** Listen, capture, and replay radio frequencies in the Sub-GHz range.

**Common use cases:**
- Garage door openers
- Gate remotes
- Wireless alarms
- Weather stations
- Car key fobs (some)

**Workflow:**
1. Navigate to `Radio` → `Sub-GHz`
2. Choose mode: `Listen`, `Capture`, or `Replay`
3. For capture: Select frequency range or specific frequency
4. Save captured signals to internal storage
5. Analyze and replay as needed

**Key commands:**
- `Listen`: Monitor a frequency for activity
- `Capture`: Record signals at a specific frequency
- `Replay`: Send back captured signals
- `Brute Force`: Attempt to crack rolling codes (limited success)

**Tips:**
- Start with common frequencies: 315 MHz, 433 MHz, 868 MHz, 915 MHz
- Use an external antenna for better range
- Some modern systems use rolling codes that can't be replayed

### 2. NFC (13.56 MHz)

**What it does:** Read, capture, and emulate NFC cards and tags.

**Common use cases:**
- Access control cards
- Payment cards (testing only)
- Smart posters
- Data exchange

**Workflow:**
1. Navigate to `NFC`
2. Choose: `Read`, `Emulate`, or `Analyze`
3. For reading: Hold card near device
4. For emulation: Load a saved card and activate
5. Analyze card structure and security

**Key operations:**
- `Read`: Extract data from NFC cards
- `Emulate`: Act as an NFC card
- `Analyze`: View card structure and security features
- `Write`: Modify writable tags (if permitted)

**Important:**
- Many modern access cards use encryption (MIFARE DESFire, etc.)
- Always have authorization before testing
- Some cards can't be fully cloned due to security features

### 3. 125kHz RFID

**What it does:** Read, capture, and emulate low-frequency RFID tags.

**Common use cases:**
- Legacy access control systems
- Hotel key cards
- Employee badges
- Pet tags

**Workflow:**
1. Navigate to `iButton` → `125kHz RFID` (or similar menu)
2. Choose: `Read`, `Emulate`, or `Analyze`
3. For reading: Hold tag near device
4. For emulation: Load saved tag and activate

**Key operations:**
- `Read`: Extract UID from RFID tags
- `Emulate`: Act as an RFID tag
- `Analyze`: View tag details and type

**Limitations:**
- Can only read UID, not full card data
- Some systems use additional authentication
- Modern systems often use 13.56 MHz instead

### 4. Infrared (IR)

**What it does:** Read, capture, and send infrared signals.

**Common use cases:**
- TV remotes
- Air conditioner controls
- Audio equipment
- Home automation

**Workflow:**
1. Navigate to `Infrared`
2. Choose: `Remote`, `Analyze`, or `Send`
3. For capture: Point remote at device and press buttons
4. For sending: Select saved signal and transmit

**Key operations:**
- `Remote`: Use as a universal remote
- `Analyze`: View signal details and protocol
- `Send`: Transmit saved IR signals
- `Learn`: Capture new remote signals

**Tips:**
- Works with most consumer electronics
- Can create custom remotes
- Some devices use proprietary protocols

### 5. iButton (Dallas 1-Wire)

**What it does:** Read and emulate iButton security devices.

**Common use cases:**
- Physical access control
- Server room security
- Building entry systems

**Workflow:**
1. Navigate to `iButton`
2. Choose: `Read` or `Emulate`
3. For reading: Touch iButton to device
4. For emulation: Load saved iButton and activate

**Key operations:**
- `Read`: Extract iButton data
- `Emulate`: Act as an iButton
- `Analyze`: View iButton type and details

**Note:**
- Requires physical contact with iButton
- Some iButtons have encryption
- Check compatibility before testing

### 6. BadUSB

**What it does:** Emulate a USB keyboard to execute automated keystrokes.

**Common use cases:**
- Security testing
- Automation
- Penetration testing

**Workflow:**
1. Navigate to `USB` → `BadUSB`
2. Load or create a payload script
3. Connect to target system
4. Execute payload

**Payload examples:**
```bash
# Open terminal and run command
delay 1000
type sudo whoami

# Create a file
delay 500
type echo "test" > /tmp/test.txt
```

**Important:**
- Only use on systems you own or have authorization to test
- Can be detected by security software
- Modern systems may have USB device control

### 7. U2F Security Key

**What it does:** Act as a U2F/FIDO2 security key.

**Common use cases:**
- Testing 2FA implementations
- Security research
- Backup key functionality

**Workflow:**
1. Navigate to `USB` → `U2F`
2. Configure key settings
3. Register with services
4. Use for authentication

**Note:**
- Primarily for testing and research
- Don't use for production security
- Understand the security implications

## Safety and Ethics

**Always:**
- Have explicit authorization before testing
- Document your testing scope
- Respect privacy and security
- Follow applicable laws and regulations

**Never:**
- Test systems without permission
- Use captured data for unauthorized access
- Share sensitive information
- Bypass security controls without authorization

## Best Practices

1. **Start with documentation:** Understand the target system before testing
2. **Use in controlled environments:** Test on systems you own first
3. **Document findings:** Keep records of what you test and discover
4. **Stay updated:** Flipper Zero firmware and capabilities evolve
5. **Join the community:** Learn from other users and researchers

## Troubleshooting

**Device not responding:**
- Check battery level
- Update firmware
- Reset device if needed

**Signal not captured:**
- Move closer to source
- Try different frequencies
- Check antenna connection

**Emulation not working:**
- Verify signal was captured correctly
- Check target system compatibility
- Some systems use encryption or rolling codes

## Resources

- **Official:** https://flipperzero.one/
- **Community:** https://github.com/djsime1/awesome-flipperzero
- **Documentation:** https://docs.flipperzero.one/
- **Firmware updates:** Check official channels

## Quick Reference

| Capability | Frequency/Protocol | Common Uses |
|------------|-------------------|-------------|
| Sub-GHz | 300-928 MHz | Garage doors, gates, alarms |
| NFC | 13.56 MHz | Access cards, payments |
| 125kHz RFID | 125 kHz | Legacy access, hotel keys |
| Infrared | IR signals | Remotes, home automation |
| iButton | 1-Wire | Physical access control |
| BadUSB | USB HID | Automation, testing |
| U2F | USB/FIDO2 | 2FA testing |

## Getting Started

1. **Power on** the Flipper Zero
2. **Navigate** to the desired tool using the joystick
3. **Select** the operation mode (Read, Capture, Emulate, etc.)
4. **Execute** the operation following on-screen prompts
5. **Save** results to internal storage or export via USB

Remember: This tool is powerful. Use it responsibly and ethically.
