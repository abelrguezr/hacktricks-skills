---
name: ldap-hardening
description: How to harden Active Directory against LDAP relay attacks using LDAP signing and channel binding. Use this skill whenever the user mentions LDAP security, AD hardening, LDAP signing, channel binding, LDAP relay prevention, Active Directory security, or wants to protect Domain Controllers from MITM/relay attacks. Make sure to use this skill even if they don't explicitly say "hardening" or "security" — if they're asking about LDAP configuration, GPO settings for DCs, or protecting against Kerberos/NTLM relays, this skill applies.
---

# LDAP Signing & Channel Binding Hardening

This skill guides you through hardening Active Directory against LDAP relay and MITM attacks using two server-side controls:

- **LDAP Channel Binding (CBT)** — ties LDAPS binds to the specific TLS tunnel, breaking relays across different channels
- **LDAP Signing** — forces integrity-protected LDAP messages, preventing tampering and most unsigned relays

## When to use this skill

Use this skill when you need to:
- Harden Domain Controllers against LDAP relay attacks
- Configure LDAP signing requirements
- Enable LDAP channel binding
- Audit current LDAP security posture
- Plan a safe rollout of LDAP hardening
- Interpret Directory Service security events

## Quick offensive check

Before hardening, understand the risk. Tools like `netexec` reveal server posture:

```bash
netexec ldap <dc> -u user -p pass
```

If you see `(signing:None)` and `(channel binding:Never)`, Kerberos/NTLM relays to LDAP are viable. Attackers can use tools like KrbRelayUp to write `msDS-AllowedToActOnBehalfOfOtherIdentity` for RBCD and impersonate administrators.

## LDAP Channel Binding (LDAPS only)

### Requirements

- **CVE-2017-8563 patch** (2017) — adds Extended Protection for Authentication support
- **KB4520412** (Server 2019/2022) — adds LDAPS CBT "what-if" telemetry

### GPO Configuration (Domain Controllers)

**Policy**: `Domain controller: LDAP server channel binding token requirements`

| Setting | Effect |
|---------|--------|
| `Never` (default) | No CBT enforcement |
| `When Supported` | Audit mode: emits failures, does not block |
| `Always` | Enforce: rejects LDAPS binds without valid CBT |

### Audit Events

Set **When Supported** to surface these events:

- **Event 3074** — LDAPS bind would have failed CBT validation if enforced
- **Event 3075** — LDAPS bind omitted CBT data and would be rejected if enforced
- **Event 3039** — CBT failures on older builds

**Note**: Channel binding only works on **LDAPS** (port 636), not raw LDAP (port 389).

## LDAP Signing

### Client GPO

**Policy**: `Network security: LDAP client signing requirements`

- Default on modern Windows: `Negotiate signing`
- Recommended: `Require signing`

### Domain Controller GPO

**Legacy policy** (Server 2016-2022):
- **Policy**: `Domain controller: LDAP server signing requirements`
- Default: `None`
- Recommended: `Require signing`

**Server 2025 DCs** (new behavior):
- Leave legacy policy at `None`
- **Policy**: `LDAP server signing requirements Enforcement`
- Default (Not Configured): **Require Signing** is enforced
- To avoid enforcement: explicitly set to `Disabled`

### Compatibility

Only Windows **XP SP3+** supports LDAP signing. Older systems will break when enforcement is enabled.

## Audit-first rollout (recommended ~30 days)

Follow this phased approach to avoid breaking legacy clients:

### Phase 1: Enable diagnostics

On each Domain Controller, enable LDAP interface diagnostics to log unsigned binds:

```powershell
Reg Add HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Diagnostics /v "16 LDAP Interface Events" /t REG_DWORD /d 2
```

### Phase 2: Start CBT telemetry

Set DC GPO `LDAP server channel binding token requirements` = **When Supported**

### Phase 3: Monitor Directory Service events

Watch for these events in the Directory Service log:

| Event ID | Meaning |
|----------|--------|
| **2889** | Unsigned/unsigned-allowed binds (signing noncompliant) |
| **3074** | LDAPS binds that would fail CBT if enforced |
| **3075** | LDAPS binds that omit CBT and would be rejected |

**Note**: Events 3074/3075 require KB4520412 on Server 2019/2022 and Phase 2 above.

### Phase 4: Enforce in separate changes

Apply these in sequence, monitoring for breakage between each:

1. `LDAP server channel binding token requirements` = **Always** (DCs)
2. `LDAP client signing requirements` = **Require signing** (clients)
3. `LDAP server signing requirements` = **Require signing** (DCs) **or** (Server 2025) `LDAP server signing requirements Enforcement` = **Enabled**

## Common issues and troubleshooting

### Legacy clients break after enabling signing

- Check Event 2889 for unsigned bind attempts
- Identify the source systems and either:
  - Upgrade them to Windows XP SP3+
  - Exclude them from the GPO using security filtering
  - Create a separate OU with a GPO that doesn't enforce signing

### LDAPS connections fail after enabling CBT

- Verify clients have CVE-2017-8563 patch
- Check Event 3074/3075 for CBT failures
- Ensure clients are using LDAPS (port 636), not LDAP (port 389)
- Some legacy applications may not support CBT — exclude them from enforcement

### Server 2025 unexpected enforcement

- Server 2025 defaults to **Require Signing** when the new policy is Not Configured
- To disable: explicitly set `LDAP server signing requirements Enforcement` = `Disabled`

## References

- [TrustedSec - LDAP Channel Binding and LDAP Signing](https://trustedsec.com/blog/ldap-channel-binding-and-ldap-signing)
- [Microsoft KB4520412 - LDAP channel binding & signing requirements](https://support.microsoft.com/en-us/topic/2020-and-2023-ldap-channel-binding-and-ldap-signing-requirements-for-windows-kb4520412-ef185fb8-00f7-167d-744c-f299a66fc00a)
- [Microsoft CVE-2017-8563 - LDAP relay mitigation update](https://portal.msrc.microsoft.com/en-us/security-guidance/advisory/CVE-2017-8563)
- [0xdf – HTB Bruno (LDAP signing disabled → Kerberos relay → RBCD)](https://0xdf.gitlab.io/2026/02/24/htb-bruno.html)
