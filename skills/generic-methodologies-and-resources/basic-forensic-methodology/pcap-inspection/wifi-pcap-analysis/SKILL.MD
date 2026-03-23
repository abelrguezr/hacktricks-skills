---
name: wifi-pcap-analysis
description: Analyze WiFi PCAP files for forensic investigation. Use this skill whenever the user needs to examine WiFi network captures, extract authentication data, find unknown devices, decrypt traffic, or investigate potential data leaks in beacon frames. Trigger on any request involving WiFi PCAP analysis, wireless forensics, network capture investigation, or when the user mentions .pcap files with WiFi traffic.
---

# WiFi PCAP Analysis

A skill for forensic analysis of WiFi network captures using Wireshark and related tools.

## When to Use This Skill

Use this skill when:
- You need to analyze a PCAP file containing WiFi traffic
- You want to extract authentication credentials from WiFi captures
- You need to identify unknown devices on a WiFi network
- You suspect data leakage in beacon frames
- You need to decrypt WiFi traffic for investigation
- The user mentions WiFi forensics, wireless captures, or .pcap files with WLAN data

## Prerequisites

- Wireshark installed
- aircrack-ng suite installed
- PCAP file with WiFi traffic
- Optional: password list for brute force attacks

## Analysis Workflow

### 1. Check BSSIDs and Authentication Status

Start by examining all wireless networks in the capture:

1. Open the PCAP in Wireshark
2. Navigate to **Wireless → WLAN Traffic**
3. Review the BSSID list to identify all networks present
4. Check the "Authentication" column to see if any authentication handshakes were captured

**If authentication was found:**

You can attempt to crack the WPA/WPA2 passphrase using aircrack-ng:

```bash
aircrack-ng -w <password-list> -b <BSSID> <capture-file.pcap>
```

**Parameters:**
- `-w`: Path to wordlist file containing potential passwords
- `-b`: Target BSSID (MAC address of the access point)
- `<capture-file.pcap>`: The PCAP file containing the handshake

**Example:**
```bash
aircrack-ng -w /usr/share/wordlists/rockyou.txt -b 00:11:22:33:44:55 capture.pcap
```

This retrieves the WPA passphrase protecting a PSK (pre-shared key), which is required to decrypt the traffic.

### 2. Check for Data Leaks in Beacon Frames

If you suspect data is being leaked inside WiFi beacon frames:

1. Apply a filter to isolate beacons from a specific network:
   ```
   wlan.ssid == "NETWORK_NAME"
   ```
   or
   ```
   wlan contains NETWORK_NAME
   ```

2. Search within the filtered packets for suspicious strings or patterns
3. Look for unusual data in the beacon payload that shouldn't be there

**Common indicators of beacon data leakage:**
- Unusual strings in beacon frames
- Base64-encoded data
- URLs or IP addresses in beacon payloads
- Custom information elements with unexpected content

### 3. Find Unknown MAC Addresses

To identify machines sending data inside a WiFi network, use this comprehensive filter:

```wireshark
((wlan.ta == <BSSID>) && !(wlan.fc == 0x8000)) && 
!(wlan.fc.type_subtype == 0x0005) && 
!(wlan.fc.type_subtype == 0x0004) && 
!(wlan.addr == ff:ff:ff:ff:ff:ff) && 
wlan.fc.type == 2
```

**Filter breakdown:**
- `wlan.ta == <BSSID>`: Traffic addressed to the access point
- `!(wlan.fc == 0x8000)`: Exclude beacon frames
- `!(wlan.fc.type_subtype == 0x0005)`: Exclude probe responses
- `!(wlan.fc.type_subtype == 0x0004)`: Exclude probe requests
- `!(wlan.addr == ff:ff:ff:ff:ff:ff)`: Exclude broadcast addresses
- `wlan.fc.type == 2`: Management frames only

**To exclude known MAC addresses:**

Add exclusions for devices you already know about:

```wireshark
&& !(wlan.addr == <KNOWN_MAC_1>) && !(wlan.addr == <KNOWN_MAC_2>)
```

**Once unknown MACs are identified:**

Filter their traffic to investigate further:

```wireshark
wlan.addr == <UNKNOWN_MAC> && (ftp || http || ssh || telnet)
```

**Note:** Protocol filters (ftp, http, ssh, telnet) only work on decrypted traffic.

### 4. Decrypt WiFi Traffic

To decrypt captured WiFi traffic in Wireshark:

1. Go to **Edit → Preferences → Protocols → IEEE 802.11**
2. Click **Edit** in the IEEE 802.11 section
3. Add the encryption key:
   - For WEP: Enter the WEP key
   - For WPA/WPA2: Enter the passphrase (not the derived key)
4. Select the appropriate key type (WEP, WPA-Personal, WPA2-Personal)
5. Click OK and reload the capture

**Alternative method using aircrack-ng:**

If you've cracked the password with aircrack-ng, you can also use:

```bash
airdecap-ng -w <password> -b <BSSID> <capture-file.pcap>
```

This creates a decrypted PCAP file that can be opened in Wireshark.

## Common Analysis Patterns

### Pattern 1: Quick Network Overview

```wireshark
wlan.fc.type == 0
```

Shows all management frames (beacons, probes, associations).

### Pattern 2: Data Traffic Only

```wireshark
wlan.fc.type == 2
```

Shows only data frames, filtering out management and control frames.

### Pattern 3: Authentication Handshakes

```wireshark
eap || wlan.fc.type_subtype == 0x000b
```

Focuses on authentication-related frames.

### Pattern 4: All Traffic from Specific Device

```wireshark
wlan.addr == <MAC_ADDRESS>
```

Shows all packets involving a specific MAC address.

## Output Format

When presenting analysis results, structure them as follows:

```
## WiFi PCAP Analysis Results

### Networks Found
- BSSID: <MAC> | SSID: <name> | Authentication: <yes/no>

### Unknown Devices
- MAC: <address> | First Seen: <timestamp> | Traffic Volume: <packets>

### Security Findings
- Authentication captured: <yes/no>
- Decryption status: <decrypted/encrypted>
- Potential data leaks: <none/identified>

### Recommendations
<actionable next steps>
```

## Tips and Best Practices

1. **Always check for authentication first** - If a handshake is present, cracking the password unlocks the entire capture
2. **Document known MACs** - Keep a list of expected devices to filter them out when hunting for unknowns
3. **Use time filters** - WiFi captures can be large; focus on relevant time windows
4. **Export findings** - Save filtered views as new PCAP files for further analysis
5. **Verify decryption** - After decrypting, confirm by checking if previously encrypted packets now show readable payloads

## Troubleshooting

**Issue:** No authentication found in capture
- **Solution:** The handshake wasn't captured. You may need to capture again or use a deauthentication attack to force a new handshake.

**Issue:** Decryption fails
- **Solution:** Verify the key type matches the encryption method. WPA2 requires the passphrase, not the derived key.

**Issue:** Too many unknown MACs
- **Solution:** Apply additional filters to exclude broadcast/multicast traffic and focus on unicast communications.

## Related Tools

- **Wireshark** - Primary analysis tool
- **aircrack-ng** - Password cracking and decryption
- **tshark** - Command-line Wireshark for scripting
- **pcapedit** - PCAP file manipulation

## References

- [Wireshark WiFi Analysis Guide](https://wiki.wireshark.org/WiFi)
- [aircrack-ng Documentation](https://www.aircrack-ng.org/)
- [802.11 Frame Types](https://en.wikipedia.org/wiki/IEEE_802.11#Frame_types)
