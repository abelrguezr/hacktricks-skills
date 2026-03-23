---
name: ftp-bounce-scan
description: Perform FTP bounce attacks to scan ports on internal or otherwise inaccessible networks. Use this skill whenever the user needs to scan ports through an FTP server, mentions FTP bounce, PORT/EPRT commands, or wants to check if ports are open on a target that the FTP server can reach. This is especially useful in penetration testing scenarios where you have access to an FTP server but need to scan internal networks or specific hosts.
---

# FTP Bounce Port Scanning

This skill helps you perform FTP bounce attacks to scan ports on targets that the FTP server can reach but you cannot directly access.

## When to Use This Skill

Use this skill when:
- You have access to an FTP server and need to scan ports on internal networks
- You want to check if specific ports are open on a target through an FTP server
- You're performing penetration testing and need to bypass network restrictions
- The user mentions "FTP bounce", "PORT command", "EPRT", or similar concepts

## How FTP Bounce Works

FTP bounce attacks exploit the FTP server's ability to establish data connections to arbitrary IP addresses. By using the `PORT` or `EPRT` command, you can make the FTP server connect to any IP:Port you specify. Then, by issuing a `LIST` or `RETR` command, you can determine if that port is open based on the server's response.

## Quick Start

### Using the Automated Script

The easiest way to perform FTP bounce scanning is using the included script:

```bash
python scripts/ftp-bounce-scan.py --host <ftp_server> --user <username> --pass <password> --target <target_ip> --ports <port_list>
```

Example:
```bash
python scripts/ftp-bounce-scan.py --host 10.2.1.5 --user ftp --pass ftp --target 192.168.1.100 --ports 21,22,80,443,8080
```

### Manual FTP Bounce

If you prefer to do it manually or need more control:

1. **Connect to the vulnerable FTP server**
   ```bash
   ftp <ftp_server>
   # or
   nc <ftp_server> 21
   ```

2. **Authenticate** (if required)
   ```
   USER <username>
   PASS <password>
   ```

3. **Use PORT or EPRT to specify the target**
   
   **PORT format** (IP in octets, port split into two bytes):
   ```
   PORT 172,32,80,80,0,8080
   # Format: h1,h2,h3,h4,p1,p2 where port = p1*256 + p2
   # For port 8080: 8080/256=31, 8080%256=24 → PORT 172,32,80,80,31,24
   ```
   
   **EPRT format** (easier, uses standard IP notation):
   ```
   EPRT |2|172.32.80.80|8080|
   # Format: EPRT |2|IP|PORT|
   ```

4. **Send LIST or RETR to test the port**
   ```
   LIST
   # or
   RETR /some/file
   ```

5. **Interpret the response**
   - `150 File status okay` or similar success code → **Port is OPEN**
   - `425 No connection established` or similar error → **Port is CLOSED**

## Examples

### Example 1: Scan a single port

```bash
# Using PORT command
ftp 10.2.1.5
USER ftp
PASS ftp
PORT 192,168,1,100,0,80
LIST
# Response: 150 File status okay → Port 80 is OPEN
```

### Example 2: Scan multiple ports with nmap

```bash
# Scan specific ports on a single host
nmap -Pn -v -p 21,80 -b ftp:ftp@10.2.1.5 127.0.0.1

# Scan a subnet
nmap -v -p 21,22,445,80,443 -b ftp:ftp@192.168.0.1/24
```

### Example 3: Using EPRT (more reliable)

```bash
ftp 10.2.1.5
USER ftp
PASS ftp
EPRT |2|192.168.1.100|443|
LIST
# Response: 150 File status okay → Port 443 is OPEN
```

## Important Notes

1. **Only use PORT or EPRT, not both** - Choose one method per scan
2. **Authentication may be required** - Some FTP servers require login before accepting PORT/EPRT commands
3. **Firewall considerations** - The FTP server must be able to reach the target network
4. **Legal considerations** - Only use this technique on systems you have authorization to test
5. **EPRT is preferred** - EPRT is more reliable and easier to use than PORT

## Troubleshooting

- **"500 Syntax error"** - The FTP server may not support PORT/EPRT commands
- **"425 Can't open data connection"** - The port is closed or firewall is blocking
- **Connection timeout** - The target may not be reachable from the FTP server
- **"530 Login incorrect"** - Check your credentials or try anonymous login

## Script Usage

The `ftp-bounce-scan.py` script automates the process:

```bash
python scripts/ftp-bounce-scan.py --help

# Basic usage
python scripts/ftp-bounce-scan.py --host <ftp_server> --user <username> --pass <password> --target <target_ip> --ports <port_list>

# Options:
# --host: FTP server IP/hostname
# --user: FTP username (default: anonymous)
# --pass: FTP password (default: anonymous)
# --target: Target IP to scan
# --ports: Comma-separated list of ports to scan
# --timeout: Connection timeout in seconds (default: 5)
# --verbose: Show detailed output
```

## References

- [HackTricks FTP Bounce](https://book.hacktricks.xyz/pentesting/21-ftp/ftp-bounce-attack)
- [Nmap FTP Bounce Scanning](https://nmap.org/book/ftp-bounce.html)
