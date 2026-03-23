---
name: udp-tftp-pentest
description: How to enumerate and exploit TFTP (Trivial File Transfer Protocol) services on UDP port 69. Use this skill whenever you need to scan for TFTP services, enumerate files on TFTP servers, download or upload files via TFTP, or assess TFTP security during penetration testing. Trigger this skill for any task involving port 69/UDP, TFTP brute-forcing, file transfer via TFTP, or when you discover an open TFTP service during network reconnaissance.
---

# UDP TFTP Pentesting

This skill helps you enumerate and exploit **Trivial File Transfer Protocol (TFTP)** services running on **UDP port 69**. TFTP is a simple, authentication-less file transfer protocol that's commonly found in internal networks for distributing configuration files and ROM images to devices like VoIP handsets.

## When to Use This Skill

- You've discovered an open UDP port 69 during port scanning
- You need to enumerate files on a TFTP server
- You want to download or upload files via TFTP
- You're assessing TFTP security during penetration testing
- You need to check for default TFTP paths and files

## Quick Start

```bash
# Scan for TFTP service
nmap -sU -p69 <target-ip>

# Enumerate TFTP files
nmap -sU -p69 --script tftp-enum <target-ip>

# Download a file via TFTP
tftp <target-ip> -c get <filename> <local-path>

# Upload a file via TFTP
tftp <target-ip> -c put <local-file> <remote-path>
```

## Enumeration

### Nmap TFTP Enumeration

TFTP doesn't provide directory listing, so you need to brute-force common paths. Use Nmap's `tftp-enum` script:

```bash
# Basic TFTP enumeration
nmap -n -Pn -sU -p69 -sV --script tftp-enum <target-ip>

# With timing and verbosity
nmap -T4 -v -sU -p69 --script tftp-enum <target-ip>

# Save results
nmap -sU -p69 --script tftp-enum <target-ip> -oN tftp-enumeration.txt
```

**Common TFTP paths to try:**
- `/tftpboot/`
- `/var/lib/tftpboot/`
- `/srv/tftp/`
- `/tftp/`
- `/boot/`
- `/images/`

### Manual TFTP Enumeration

You can manually try to download common files:

```bash
# Try common configuration files
tftp <target-ip> -c get config.txt
tftp <target-ip> -c get config.cfg
tftp <target-ip> -c get config.dat

# Try common image files
tftp <target-ip> -c get image.bin
tftp <target-ip> -c get firmware.bin
tftp <target-ip> -c get rom.bin

# Try common network configs
tftp <target-ip> -c get network.cfg
tftp <target-ip> -c get voip.conf
```

## File Transfer

### Using TFTP Client

**Download files:**
```bash
tftp <target-ip> -c get <remote-filename> <local-path>
```

**Upload files:**
```bash
tftp <target-ip> -c put <local-filename> <remote-path>
```

**Interactive mode:**
```bash
tftp <target-ip>
tftp> get <filename>
tftp> put <filename>
tftp> quit
```

### Using Python (tftpy library)

For programmatic TFTP operations, use the `tftpy` library:

```python
import tftpy

# Create client
client = tftpy.TftpClient('<target-ip>', 69)

# Download a file
client.download("filename-on-server", "/tmp/local-filename", timeout=5)

# Upload a file
client.upload("/path/to/local-file", "remote-path/filename", timeout=5)
```

**Complete Python example:**
```python
import tftpy
from tftpy import tftp

def download_tftp_file(ip, port, remote_file, local_file):
    """Download a file from TFTP server"""
    client = tftpy.TftpClient(ip, port)
    try:
        client.download(remote_file, local_file, timeout=5)
        print(f"✓ Downloaded: {remote_file} -> {local_file}")
        return True
    except Exception as e:
        print(f"✗ Failed to download {remote_file}: {e}")
        return False

def upload_tftp_file(ip, port, local_file, remote_file):
    """Upload a file to TFTP server"""
    client = tftpy.TftpClient(ip, port)
    try:
        client.upload(local_file, remote_file, timeout=5)
        print(f"✓ Uploaded: {local_file} -> {remote_file}")
        return True
    except Exception as e:
        print(f"✗ Failed to upload {local_file}: {e}")
        return False

# Usage
ip = "<target-ip>"
port = 69

# Download
for filename in ["config.txt", "config.cfg", "image.bin", "firmware.bin"]:
    download_tftp_file(ip, port, filename, f"/tmp/{filename}")

# Upload
upload_tftp_file(ip, port, "/tmp/payload.bin", "payload.bin")
```

### Using Metasploit

Metasploit has a TFTP transfer utility module:

```bash
# Start Metasploit
msfconsole

# Use TFTP transfer module
use auxiliary/admin/tftp/tftp_transfer_util

# Configure options
set RHOSTS <target-ip>
set RPORT 69
set FILENAME <filename>
set TRANSFER_TYPE get  # or 'put' for upload

# Run
run
```

## Common TFTP Files to Enumerate

### Configuration Files
- `config.txt`, `config.cfg`, `config.dat`
- `network.cfg`, `network.conf`
- `voip.conf`, `sip.conf`
- `settings.ini`, `settings.cfg`

### Firmware/ROM Images
- `image.bin`, `firmware.bin`, `rom.bin`
- `kernel.bin`, `boot.bin`
- `update.bin`, `upgrade.bin`

### VoIP Device Files
- `phone.cfg`, `endpoint.conf`
- `provision.xml`, `provision.cfg`
- `config.xml`, `settings.xml`

### Network Device Files
- `router.cfg`, `switch.cfg`
- `config.1`, `config.2` (Cisco backup configs)
- `startup-config`, `running-config`

## Security Considerations

### Why TFTP is Dangerous

1. **No Authentication**: Anyone can read/write files
2. **No Encryption**: All data is transmitted in plaintext
3. **No Access Control**: No user permissions or ACLs
4. **Simple Protocol**: Easy to exploit and abuse

### Common Vulnerabilities

- **Information Disclosure**: Sensitive configs, credentials, firmware
- **File Upload**: Malicious firmware, backdoors, config tampering
- **Denial of Service**: Flooding TFTP server with requests
- **Man-in-the-Middle**: Intercepting and modifying transfers

### Mitigation Recommendations

- Disable TFTP if not needed
- Use firewall rules to restrict access
- Replace with SFTP or SCP for secure transfers
- Monitor TFTP traffic for anomalies
- Keep TFTP server software updated

## Shodan Reconnaissance

Search for TFTP services on the internet:

```bash
# Basic TFTP search
port:69

# With specific country
country:US port:69

# With specific organization
org:"Company Name" port:69

# With specific product
product:"TFTP" port:69
```

## Troubleshooting

### TFTP Connection Fails

```bash
# Check if port is open
nmap -sU -p69 <target-ip>

# Check firewall
sudo ufw status
sudo iptables -L -n

# Check TFTP service
sudo systemctl status tftpd
sudo netstat -ulnp | grep 69
```

### Permission Denied

```bash
# Check TFTP directory permissions
ls -la /var/lib/tftpboot/

# Fix permissions (if you own the server)
sudo chmod 777 /var/lib/tftpboot/
sudo chown -R tftp:tftp /var/lib/tftpboot/
```

### Timeout Errors

```bash
# Increase timeout in tftpy
client = tftpy.TftpClient(ip, port, timeout=30)

# Use larger block size
tftp -b 512 <target-ip>
```

## Examples

### Example 1: Quick TFTP Scan

```bash
# Scan target for TFTP
nmap -sU -p69 192.168.1.100

# Enumerate files
nmap -sU -p69 --script tftp-enum 192.168.1.100

# Download config
tftp 192.168.1.100 -c get config.txt /tmp/config.txt
```

### Example 2: Python TFTP Script

```python
#!/usr/bin/env python3
import tftpy
import sys

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <target-ip> <filename>")
        sys.exit(1)
    
    ip = sys.argv[1]
    filename = sys.argv[2]
    
    client = tftpy.TftpClient(ip, 69)
    try:
        client.download(filename, f"/tmp/{filename}", timeout=5)
        print(f"Downloaded: {filename}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
```

### Example 3: Bulk File Enumeration

```bash
#!/bin/bash
# tftp-enumerate.sh

TARGET=$1
FILES=(
    "config.txt"
    "config.cfg"
    "config.dat"
    "image.bin"
    "firmware.bin"
    "rom.bin"
    "network.cfg"
    "voip.conf"
    "settings.ini"
    "provision.xml"
)

echo "Enumerating TFTP files on $TARGET..."

for file in "${FILES[@]}"; do
    echo -n "Trying: $file ... "
    if tftp $TARGET -c get $file /tmp/$file 2>/dev/null; then
        echo "✓ FOUND"
    else
        echo "✗ not found"
    fi
done
```

## References

- [RFC 1350 - TFTP Specification](https://tools.ietf.org/html/rfc1350)
- [Nmap TFTP Scripts](https://nmap.org/nsedoc/scripts/tftp-enum.html)
- [tftpy Python Library](https://github.com/tftpy/tftpy)
- [Metasploit TFTP Module](https://www.rapid7.com/db/modules/auxiliary/admin/tftp/tftp_transfer_util/)

## Next Steps

After enumerating TFTP:

1. **Analyze downloaded files** for credentials, configs, or sensitive data
2. **Check for writable paths** to upload malicious files
3. **Look for firmware vulnerabilities** in downloaded images
4. **Map the network** based on discovered device configurations
5. **Document findings** for your penetration test report
