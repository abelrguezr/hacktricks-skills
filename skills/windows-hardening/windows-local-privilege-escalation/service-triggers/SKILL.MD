---
name: windows-service-trigger-abuse
description: How to enumerate and abuse Windows Service Triggers for privilege escalation. Use this skill whenever you need to start privileged services without SERVICE_START rights, enumerate service triggers, or activate services through network endpoints, ETW events, or system triggers. Make sure to use this skill when you're doing Windows privilege escalation and encounter services you can't start directly, or when you want to discover alternative ways to activate privileged services like RemoteRegistry, WebClient, EFS, or other system services.
---

# Windows Service Trigger Abuse

Windows Service Triggers allow the Service Control Manager (SCM) to start/stop a service when specific conditions occur. Even without SERVICE_START rights, you can often start privileged services by firing their triggers.

## Quick Start

1. **Enumerate triggers** on interesting services (RemoteRegistry, WebClient, EFS, etc.)
2. **Identify trigger type** (named pipe, RPC, ETW, group policy, etc.)
3. **Activate the trigger** using the appropriate method
4. **Exploit the started service** (e.g., named pipe impersonation, RPC access)

## Enumerating Service Triggers

### Local Enumeration

**Using sc.exe:**
```powershell
sc.exe qtriggerinfo <ServiceName>
```

**Using Registry:**
```powershell
reg query HKLM\SYSTEM\CurrentControlSet\Services\<ServiceName>\TriggerInfo /s
```

**Using PowerShell (Win32 API):**
```powershell
# Use the bundled script for comprehensive enumeration
.\scripts\enumerate_triggers.ps1 -ServiceName <ServiceName>
```

### Remote Enumeration

**Using Titanis (TrustedSec):**
```bash
Scm.exe qtriggers <target>
```

**Using Impacket:**
Implement remote query using MS-SCMR protocol structures.

## High-Value Trigger Types and Activation

### 1. Named Pipe Triggers

**Behavior:** A client connection attempt to `\\.\pipe\<PipeName>` causes SCM to start the service.

**Activation:**
```powershell
# Use the bundled script
.\scripts\activate_named_pipe.ps1 -PipeName <PipeNameFromTrigger>
```

**Manual PowerShell:**
```powershell
$pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'PipeNameFromTrigger', [System.IO.Pipes.PipeDirection]::InOut)
try { $pipe.Connect(1000) } catch {}
$pipe.Dispose()
```

**Post-activation:** After starting a privileged service via named pipe, you may be able to impersonate it. See named-pipe-client-impersonation techniques.

### 2. RPC Endpoint Triggers

**Behavior:** Querying the Endpoint Mapper (EPM, TCP/135) for an interface UUID causes SCM to start the service.

**Activation:**
```bash
# Use the bundled script
python3 scripts/activate_rpc_endpoint.py -uuid <INTERFACE-UUID> -target 127.0.0.1
```

**Manual (Impacket):**
```bash
python3 rpcdump.py @127.0.0.1 -uuid <INTERFACE-UUID>
```

### 3. ETW (Event Tracing for Windows) Triggers

**Behavior:** A service registers a trigger bound to an ETW provider/event. If no filters are configured, any event from that provider starts the service.

**Example - WebClient/WebDAV:**
```powershell
# List trigger
sc.exe qtriggerinfo webclient

# Verify provider is registered
logman query providers | findstr /I 22b6d684-fa63-4578-87c9-effcbe6643c7
```

**Activation:** Emit an event from the provider. If no filters exist, any event suffices.

### 4. Group Policy Triggers

**Behavior:** On domain-joined hosts with corresponding policies, triggers run at boot.

**Activation:**
```cmd
gpupdate /force
```

Note: `gpupdate` alone won't trigger without policy changes, but `/force` reliably fires the trigger if the policy type exists.

### 5. IP Address Available Triggers

**Behavior:** Fires when the first IP is obtained (or last is lost). Often triggers at boot.

**Activation:**
```cmd
netsh interface set interface name="Ethernet" admin=disabled
netsh interface set interface name="Ethernet" admin=enabled
```

### 6. Device Interface Arrival Triggers

**Behavior:** Starts when a matching device interface arrives. Evaluated at boot and upon hot-plug.

**Activation:** Attach/insert a device (physical or virtual) matching the class/hardware ID specified by the trigger subtype.

### 7. Domain Join State Triggers

**Behavior:** Evaluates domain state at boot:
- `DOMAIN_JOIN_GUID` → start if domain-joined
- `DOMAIN_LEAVE_GUID` → start only if NOT domain-joined

### 8. Aggregate Service Triggers (Windows 11+)

**Location:** `HKLM\SYSTEM\CurrentControlSet\Control\ServiceAggregatedEvents`

**Behavior:** A service's Trigger value is a GUID; the subkey defines the aggregated event. Triggering any constituent event starts the service.

### 9. Firewall Port Event Triggers

**Warning:** These have quirks and DoS risk. A trigger scoped to a specific port/protocol may start on any firewall rule change. Configuring a port without a protocol can corrupt BFE startup across reboots.

**Treat with extreme caution.**

## Practical Workflow

### Step 1: Identify Target Services

Focus on high-value services:
- `RemoteRegistry` - exposes registry access
- `WebClient` / `WebDAV` - enables HTTP/DAV access
- `EFS` - enables encrypted file system access
- `LanmanServer` - enables SMB sharing
- `Spooler` - enables print spooler access

### Step 2: Enumerate Triggers

```powershell
# Quick enumeration of multiple services
$services = @('RemoteRegistry', 'WebClient', 'EFS', 'LanmanServer', 'Spooler')
foreach ($svc in $services) {
    Write-Host "=== $svc ==="
    sc.exe qtriggerinfo $svc 2>$null
}
```

### Step 3: Activate Based on Trigger Type

| Trigger Type | Activation Method |
|--------------|-------------------|
| Named Pipe | Connect to `\\.\pipe\<PipeName>` |
| RPC Endpoint | Query EPM for interface UUID |
| ETW | Emit event from provider |
| Group Policy | Run `gpupdate /force` |
| IP Address | Toggle network interface |
| Device Arrival | Hot-plug matching device |

### Step 4: Exploit the Started Service

After activation:
- **Named pipe services:** Attempt client impersonation
- **RPC services:** Query for available interfaces and methods
- **Registry services:** Access remote registry
- **Web services:** Test HTTP/DAV endpoints

## Detection and Evasion

### Detection Indicators

- Baseline and audit `TriggerInfo` across services
- Monitor suspicious EPM lookups for privileged service UUIDs
- Monitor named-pipe connection attempts preceding service starts
- Review `HKLM\SYSTEM\CurrentControlSet\Control\ServiceAggregatedEvents`
- Treat unexpected BFE failures after trigger changes as suspicious

### Evasion Considerations

- Trigger-based service starts may be logged in SCM event logs
- Named pipe connections may be visible in network monitoring
- EPM queries may be detected by EDR solutions
- Consider timing and noise when activating triggers

## References

- [There's More than One Way to Trigger a Windows Service (TrustedSec)](https://trustedsec.com/blog/theres-more-than-one-way-to-trigger-a-windows-service)
- [QueryServiceConfig2 function (Win32 API)](https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-queryserviceconfig2a)
- [MS-SCMR: Service Control Manager Remote Protocol](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-scmr)
- [TrustedSec Titanis (SCM trigger enumeration)](https://github.com/trustedsec/Titanis)
- [Cobalt Strike BOF example – sc_qtriggerinfo](https://github.com/trustedsec/CS-Situational-Awareness-BOF)
