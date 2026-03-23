---
name: ios-burp-configuration
description: Configure Burp Suite for iOS device traffic interception and SSL pinning bypass. Use this skill whenever the user needs to set up Burp proxy on iOS devices, install Burp certificates, configure iOS simulators for mobile security testing, analyze iOS network traffic, or perform iOS mobile pentesting with Burp Suite. Make sure to use this skill for any iOS security testing involving network traffic analysis, proxy configuration, or certificate installation.
---

# iOS Burp Suite Configuration

This skill guides you through configuring Burp Suite for iOS device traffic interception, SSL pinning bypass, and network analysis.

## Quick Start

1. **Choose your method**: Automated (Burp Mobile Assistant) or Manual
2. **Configure proxy**: Set up iOS device to route traffic through Burp
3. **Install certificate**: Trust the Burp CA certificate on the device
4. **Verify**: Test that traffic flows through Burp

---

## Method 1: Automated Installation (Recommended)

Use **Burp Mobile Assistant** for the simplest setup:

1. Download and install Burp Mobile Assistant from [PortSwigger](https://portswigger.net/burp/documentation/desktop/tools/mobile-assistant/installing)
2. Connect your iOS device via USB
3. Follow the assistant's guided setup for:
   - Burp certificate installation
   - Proxy configuration
   - SSL pinning bypass

**When to use**: First-time setup, non-technical users, or when you want the most reliable configuration.

---

## Method 2: Manual Installation

### Step 1: Configure Proxy on iOS

1. Connect iOS device to the same Wi-Fi network as your Burp machine
2. On iOS: **Settings** → **Wi-Fi** → tap the (i) icon for your network
3. Scroll to **HTTP Proxy** → select **Manual**
4. Enter:
   - **Server**: Your Burp machine's IP address
   - **Port**: `8080`
5. Toggle **Use Automatic Proxy Configuration** to OFF
6. Save and return

### Step 2: Download Burp Certificate

1. Open Safari on the iOS device
2. Navigate to: `http://burp` (or `http://<burp-ip>:8080`)
3. Download the certificate file (usually `cacert.der`)

### Step 3: Install and Trust Certificate

1. Go to **Settings** → **General** → **VPN & Device Management**
2. Tap the downloaded profile (PortSwigger CA)
3. Tap **Install** and enter passcode if prompted
4. Go to **Settings** → **General** → **About** → **Certificate Trust Settings**
5. Under **Enable Full Trust for Root Certificates**, toggle **PortSwigger CA** to ON
6. Confirm the warning dialog

### Step 4: Verify Configuration

1. Open Safari on iOS and visit `https://httpbin.org/ip`
2. Check Burp's **Proxy** → **HTTP history** tab
3. You should see the request appear in Burp

---

## Advanced: Jailbroken Devices

For jailbroken iOS devices, use SSH over USB for direct traffic routing:

### Prerequisites
- Jailbroken iOS device
- `iproxy` installed on your machine
- SSH access to the device (root)

### Setup Commands

```bash
# Forward SSH port from iOS to localhost
iproxy 2222 22

# Create remote port forward to Burp
ssh -R 8080:localhost:8080 root@localhost -p 2222
```

### Configure iOS Proxy

After establishing the SSH tunnel:

1. On iOS: **Settings** → **Wi-Fi** → (i) → **HTTP Proxy** → **Manual**
2. Set **Server**: `127.0.0.1`
3. Set **Port**: `8080`
4. Save

**Why this works**: The SSH tunnel routes iOS traffic directly to your Burp instance without requiring network-level proxy configuration.

---

## iOS Simulator Configuration

For testing on iOS Simulator (macOS only):

### Step 1: Export Burp Certificate

1. In Burp Suite: **Proxy** → **Options** → **Export CA certificate**
2. Select **Certificate in DER format**
3. Save as `burp.der`

### Step 2: Import to Simulator

1. Drag and drop `burp.der` into the iOS Simulator window
2. The certificate will be installed automatically

### Step 3: Trust the Certificate

1. In Simulator: **Settings** → **General** → **Profile**
2. Tap **PortSwigger CA**
3. Tap **Verify**
4. Go to **Settings** → **General** → **About** → **Certificate Trust Settings**
5. Toggle **PortSwigger CA** to ON
6. Confirm the warning

### Step 4: Configure macOS Proxy

The iOS Simulator inherits macOS proxy settings:

1. **System Preferences** → **Network** → **Advanced**
2. Select **Proxies** tab
3. Check:
   - ☑ **Web Proxy (HTTP)**
   - ☑ **Secure Web Proxy (HTTPS)**
4. For both, enter:
   - **Proxy Server**: `127.0.0.1`
   - **Port**: `8080`
5. Click **OK** → **Apply**

**Note**: The simulator will now route all traffic through Burp automatically.

---

## Network Traffic Monitoring with Wireshark

For capturing non-HTTP traffic (TCP, UDP, etc.) from iOS devices:

### Prerequisites
- macOS with Wireshark installed
- iOS device connected via USB
- `rvictl` tool available (comes with Wireshark on macOS)

### Setup Steps

1. **Get the iOS device UDID**:
   ```bash
   # List connected devices
   rvictl -l
   ```

2. **Start remote virtual interface**:
   ```bash
   rvictl -s <UDID>
   # Output: Starting device <UDID> [SUCCEEDED] with interface rvi0
   ```

3. **Open Wireshark** and select interface `rvi0`

4. **Apply capture filters** (optional):
   - For specific IP: `host 192.168.1.100`
   - For HTTP only: `tcp port 80 or tcp port 443`
   - For specific app traffic: `host <app-server-ip>`

### Useful Wireshark Filters

| Filter | Description |
|--------|-------------|
| `http` | HTTP traffic only |
| `tls` | Encrypted TLS traffic |
| `host <ip>` | Traffic to/from specific IP |
| `tcp.port == 443` | HTTPS traffic |
| `ip.addr == <ip>` | All IP traffic to/from address |

---

## Troubleshooting

### Certificate Not Trusted

**Symptom**: Apps show SSL errors or refuse to connect

**Fix**:
1. Verify you enabled full trust in **Certificate Trust Settings**
2. On iOS 15+, some apps require additional SSL pinning bypass
3. Try reinstalling the certificate (delete old profile first)

### No Traffic Appearing in Burp

**Symptom**: Burp shows no HTTP history

**Checklist**:
- [ ] iOS device and Burp machine on same network
- [ ] Proxy settings correctly configured on iOS
- [ ] Burp is listening on port 8080
- [ ] Firewall not blocking port 8080
- [ ] Certificate is trusted (not just installed)

### Simulator Not Routing Through Burp

**Symptom**: Simulator traffic doesn't appear in Burp

**Fix**:
1. Verify macOS proxy settings are applied
2. Restart the iOS Simulator after changing proxy settings
3. Check that Burp is running and listening on 8080

---

## Quick Reference

| Task | Command/Path |
|------|-------------|
| Export Burp cert | Proxy → Options → Export CA certificate |
| iOS cert install | Settings → General → VPN & Device Management |
| Trust cert | Settings → General → About → Certificate Trust Settings |
| macOS proxy | System Preferences → Network → Advanced → Proxies |
| Start rvictl | `rvictl -s <UDID>` |
| iproxy SSH | `iproxy 2222 22` |

---

## Resources

- [PortSwigger iOS Configuration Guide](https://support.portswigger.net/customer/portal/articles/1841108-configuring-an-ios-device-to-work-with-burp)
- [Burp Mobile Assistant Documentation](https://portswigger.net/burp/documentation/desktop/tools/mobile-assistant/installing)
- [Wireshark Mobile Traffic Capture](https://stackoverflow.com/questions/9555403-capturing-mobile-phone-traffic-on-wireshark)
