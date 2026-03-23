---
name: ios-corellium-connect
description: How to connect to Corellium iOS VMs for exploitation and testing. Use this skill whenever the user mentions Corellium, iOS virtual machines, connecting to iOS devices, uploading binaries to iOS, installing .ipa files, SSH to iOS VMs, or any iOS exploitation/testing workflow involving Corellium. This includes Quick Connect, VPN setup, file transfers, app installation, port forwarding, and remote debugging.
---

# iOS Corellium Connection Guide

This skill helps you connect to and interact with Corellium iOS virtual machines for security testing, exploitation, and development.

## Quick Start

### Method 1: Quick Connect (Recommended for most cases)

1. **Add your SSH key** to Corellium at `/admin/projects` (recommended for passwordless login)
2. **Open the device page** and click **Connect**
3. **Copy the Quick Connect SSH command** displayed by Corellium
4. **Paste in your terminal** and execute

```bash
# Example Quick Connect command (format varies)
ssh -J <domain> root@<quick-connect-host>
```

### Method 2: VPN Connection (Use when you need local network access)

1. **Add your SSH key** to Corellium at `/admin/projects`
2. **Navigate to device page** → **CONNECT** → **VPN**
3. **Download the `.ovpn` file** and connect with any TAP-mode VPN client
4. **SSH to the VM's internal IP**:

```bash
ssh root@10.11.1.1
```

> **When to use VPN**: Choose VPN when you need the device on your local network for tools like proxies, network analyzers, or when Quick Connect doesn't work.

## File Transfer Operations

### Upload a Native Binary

**With Quick Connect (jump host):**
```bash
scp -J <domain> ./mytool root@10.11.1.1:/var/root/mytool
```

**With VPN (direct IP):**
```bash
scp ./mytool root@10.11.1.1:/var/root/mytool
```

### Upload and Install an iOS App (.ipa)

**Option A: Web UI (Fastest)**
1. Device page → **Apps** tab → **Install App**
2. Select your `.ipa` file
3. Use the same tab to **launch**, **kill**, or **uninstall**

**Option B: Scripted via Corellium Agent**

Use the Corellium API Agent for automated workflows:

```javascript
// Node.js example using Corellium Agent
await agent.upload("./app.ipa", "/var/tmp/app.ipa");
await agent.install("/var/tmp/app.ipa", (progress, status) => {
  console.log(`Progress: ${progress}, Status: ${status}`);
});
```

**Option C: Non-Jailbroken Devices (Requires Signing)**

- **Use Sideloadly** to re-sign with your Apple ID
- **Or sign in Xcode** with a valid provisioning profile
- **Unsigned IPAs will not launch** on non-jailbroken devices

## Advanced Operations

### Port Forwarding

Make the VM accessible locally for other tools:

```bash
# Forward local port 2222 to device port 22
ssh -N -L 2222:127.0.0.1:22 root@10.11.1.1

# Now use the forwarded port
scp -P 2222 file root@localhost:/var/root/
```

### Remote Debugging with LLDB

1. **Navigate to device page** → **CONNECT** → **LLDB**
2. **Copy the LLDB/GDB stub address** shown at the bottom
3. **Connect from your local LLDB**:

```bash
lldb
(lldb) platform select remote-ios
(lldb) process connect connect://<stub-address>
```

### USBFlux (macOS/Linux)

Present the VM to Xcode or Sideloadly as if it were physically connected:

```bash
# Install USBFlux
brew install usbfluxd

# Run to expose the device
usbfluxd
```

Now Xcode and Sideloadly will detect the Corellium VM as a connected device.

## Quick Reference

| Task | Command/Method |
|------|----------------|
| Quick SSH | Copy command from device page |
| VPN SSH | `ssh root@10.11.x.x` |
| Upload binary | `scp -J <domain> ./file root@10.11.1.1:/path/` |
| Install .ipa | Web UI Apps tab or Agent API |
| Port forward | `ssh -N -L 2222:127.0.0.1:22 root@10.11.1.1` |
| View logs | Device Console in UI |

## Common Pitfalls

- **Signing required**: Non-jailbroken devices need properly signed IPAs. Unsigned apps won't launch.
- **Quick Connect vs VPN**: Quick Connect is simpler; use VPN for local network tools.
- **No App Store**: Corellium devices don't have App Store access. Bring your own signed IPAs.
- **SSH keys**: Add keys to `/admin/projects` to avoid password prompts.
- **Path differences**: Quick Connect uses jump host (`-J`), VPN uses direct IP.

## Troubleshooting

**Can't connect via Quick Connect?**
- Try VPN method instead
- Verify SSH key is added to project
- Check Corellium status page for outages

**VPN won't connect?**
- Ensure VPN client supports TAP mode
- Check [Corellium VPN docs](https://support.corellium.com/features/connect/vpn)
- Try different VPN client (OpenVPN Connect, Tunnelblick, etc.)

**App won't launch?**
- On non-jailbroken: re-sign with Sideloadly or Xcode
- Check provisioning profile validity
- Verify app architecture matches device (arm64)

**SCP fails?**
- Quick Connect: include `-J <domain>` flag
- VPN: use direct IP without jump host
- Verify SSH key authentication is working
