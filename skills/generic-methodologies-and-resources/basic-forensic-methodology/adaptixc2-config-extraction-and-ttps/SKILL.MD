---
name: adaptixc2-config-extractor
description: Extract and decrypt AdaptixC2 beacon configurations from malware samples. Use this skill whenever analyzing C2 beacons, post-exploitation frameworks, or malware with embedded RC4-encrypted configs. Trigger on mentions of AdaptixC2, beacon extraction, C2 config parsing, RC4 decryption, or when investigating suspicious PE files with embedded configuration blobs.
---

# AdaptixC2 Configuration Extraction

A forensic skill for extracting and analyzing AdaptixC2 beacon configurations from malware samples. AdaptixC2 is a modular post-exploitation/C2 framework that embeds RC4-encrypted configuration blobs in its beacons.

## When to use this skill

Use this skill when:
- You have a suspected AdaptixC2 beacon (EXE/DLL/service) and need to extract its C2 configuration
- You're investigating malware with embedded encrypted configuration blobs
- You need to parse HTTP/SMB/TCP beacon profiles for threat hunting
- You're analyzing post-exploitation framework artifacts
- You want to extract network indicators (C2 servers, ports, URIs) from beacon samples

## Quick start

```bash
# Extract config from a beacon file
python scripts/extract_adaptixc2_config.py beacon.exe

# Or extract from a pre-isolated blob
python scripts/extract_adaptixc2_config.py blob.bin --blob-mode
```

## Configuration structure

AdaptixC2 embeds encrypted configuration as a tail blob in the beacon PE:

```
[4 bytes: size (uint32 LE)]
[N bytes: RC4-encrypted config]
[16 bytes: RC4 key]
```

The beacon loader reads this structure, extracts the key, and RC4-decrypts the config in place. The blob is typically located in the `.rdata` section.

## Beacon profile types

### HTTP Beacon

Most common profile type. Fields include:

| Field | Type | Description |
|-------|------|-------------|
| `agent_type` | u32 | Agent identifier |
| `use_ssl` | bool | HTTPS vs HTTP |
| `servers` | array | C2 server addresses |
| `ports` | array | C2 ports |
| `http_method` | string | GET/POST |
| `uri` | string | Request path |
| `parameter` | string | Custom header name for beacon ID |
| `user_agent` | string | HTTP user agent |
| `sleep_delay` | u32 | Beacon interval (seconds) |
| `jitter_delay` | u32 | Randomization factor |
| `kill_date` | u32 | Self-expiry timestamp |
| `working_time` | u32 | Active hours window |

### SMB Beacon

Named-pipe peer-to-peer C2 for intranet environments. Uses similar structure with SMB-specific fields.

### TCP Beacon

Direct socket communication, optionally with prepended marker bytes for obfuscation.

## Extraction workflow

### Step 1: Locate the blob

The encrypted config blob is typically in the PE `.rdata` section. Use the bundled script to scan for the `[size|ciphertext|key]` pattern:

```bash
python scripts/extract_adaptixc2_config.py sample.exe
```

The script will:
1. Parse the PE file
2. Scan `.rdata` for plausible blob layouts
3. Attempt RC4 decryption with candidate keys
4. Validate by checking if string fields decode as UTF-8
5. Output the decrypted configuration as JSON

### Step 2: Parse the configuration

Once decrypted, the config follows a length-prefixed format:
- Scalars: u32/boolean values
- Strings: u32 length followed by bytes (may have trailing NUL)
- Arrays: count followed by that many elements

The script handles parsing automatically and outputs structured JSON.

### Step 3: Extract indicators

From the parsed config, extract:
- **C2 servers**: `servers` array
- **Ports**: `ports` array  
- **URI paths**: `uri` field
- **Custom headers**: `parameter` field (beacon ID header name)
- **User agents**: `user_agent` field
- **Timing**: `sleep_delay`, `jitter_delay`, `kill_date`, `working_time`

## Network hunting indicators

### HTTP C2

- **Method**: POST to operator-selected URIs (e.g., `/uri.php`, `/endpoint/api`)
- **Custom header**: Beacon ID in custom header (e.g., `X-Beacon-Id`, `X-App-Id`)
- **User agents**: Often Firefox 20 or contemporary Chrome builds
- **Polling**: Regular intervals based on `sleep_delay` with `jitter_delay` randomization

### SMB/TCP C2

- **SMB**: Named-pipe listeners for intranet C2
- **TCP**: May prepend marker bytes to obfuscate protocol start

## Common TTPs

### In-memory loaders

- Download Base64/XOR payloads via `Invoke-RestMethod` or `WebClient`
- Allocate unmanaged memory, copy shellcode
- Change protection to `PAGE_EXECUTE_READWRITE` (0x40) via `VirtualProtect`
- Execute via `Marshal.GetDelegateForFunctionPointer` + delegate invocation

### Persistence mechanisms

- **Startup folder**: `.lnk` shortcuts to re-launch loaders at logon
- **Registry Run keys**: `HKCU/HKLM\...\CurrentVersion\Run` with benign names like "Updater"
- **DLL hijacking**: Dropping `msimg32.dll` under `%APPDATA%\Microsoft\Windows\Templates`

### Hunting queries

- PowerShell spawning RW→RX memory transitions (`VirtualProtect` to `PAGE_EXECUTE_READWRITE`)
- Dynamic invocation patterns (`GetDelegateForFunctionPointer`)
- Startup `.lnk` files in user/common Startup folders
- Suspicious Run keys with names like "Updater", `update.ps1`, `loader.ps1`
- User-writable DLL paths containing `msimg32.dll`

## Example output

```json
{
  "agent_type": 3192652105,
  "use_ssl": true,
  "servers": ["tech-system[.]online"],
  "ports": [443],
  "http_method": "POST",
  "uri": "/endpoint/api",
  "parameter": "X-App-Id",
  "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...",
  "sleep_delay": 4,
  "jitter_delay": 0,
  "kill_date": 0,
  "working_time": 0
}
```

## YARA detection

Consider rules that look for:
- The `[size|ciphertext|16-byte-key]` layout near PE `.rdata` end
- Default HTTP profile strings (e.g., `/uri.php`, `X-Beacon-Id`)
- RC4 decryption function patterns
- Loader API-hashing constants

## References

- [AdaptixC2: A New Open-Source Framework Leveraged in Real-World Attacks (Unit 42)](https://unit42.paloaltonetworks.com/adaptixc2-post-exploitation-framework/)
- [AdaptixC2 GitHub](https://github.com/Adaptix-Framework/AdaptixC2)
- [MITRE ATT&CK T1547.001 – Registry Run Keys/Startup Folder](https://attack.mitre.org/techniques/T1547/001/)
