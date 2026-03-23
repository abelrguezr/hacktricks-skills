---
name: format-string-exploit
description: How to exploit format string vulnerabilities in C programs. Use this skill whenever the user mentions format strings, printf vulnerabilities, sprintf/fprintf issues, GOT overwrites, arbitrary memory read/write, stack leaks, or any C program that takes user input as a format string. Also trigger for CTF challenges involving format string bugs, pwn tasks with printf-family functions, or when analyzing binaries for format string vulnerabilities.
---

# Format String Exploitation

Format string vulnerabilities occur when user-controlled input is passed as the format string argument to `printf`-family functions (`printf`, `sprintf`, `fprintf`). This allows attackers to read from and write to arbitrary memory addresses.

## Core Concepts

### Why This Works

The `printf` function expects a format string as its first parameter, followed by values to substitute. When an attacker controls the format string, they can:

- **Read memory**: Use formatters like `%x`, `%s`, `%p` to leak stack values
- **Write memory**: Use `%n` to write the number of bytes printed to an address
- **Control execution**: Overwrite function pointers in the GOT to redirect execution

### Key Formatters

| Formatter | Purpose |
|-----------|----------|
| `%x` | Print 4 bytes as hex |
| `%08x` | Print 8 hex bytes (padded) |
| `%d` | Print as integer |
| `%s` | Print as string (reads from address) |
| `%p` | Print pointer address |
| `%n` | Write byte count to address |
| `%hn` | Write 2 bytes to address |
| `%<n>$x` | Direct parameter access (nth argument) |
| `%<n>$s` | Read string from nth parameter address |
| `%<n>$n` | Write to nth parameter address |

## Finding the Offset

Before exploiting, you need to find where your input lands on the stack. Send a known pattern followed by format specifiers and increment until you see your pattern.

**Use the script**: `scripts/find_offset.py` automates this process.

```python
# Manual approach
for i in range(1, 20):
    payload = b"AAAA%" + str(i).encode() + b"$x"
    # Send payload, check if "41414141" appears in output
```

## Arbitrary Read

Use `%<n>$s` to read from an arbitrary address. The nth parameter should be the address you want to read.

**Why this matters**: You can leak:
- Binary base address (defeat ASLR)
- Canaries
- Encryption keys
- Sensitive data on the stack

**Example**:
```python
from pwn import *

p = process('./vulnerable_binary')

# If input is at offset 6, and we want to read 0x8048000
payload = b'%6$s'  # Read string from 6th param
payload += b'xxxx'  # Padding (5th param)
payload += p32(0x8048000)  # 6th param = address to read

p.sendline(payload)
print(p.clean())  # Shows memory at 0x8048000
```

## Arbitrary Write

The `%n` formatter writes the number of bytes printed so far to an address. To write arbitrary values:

1. **Use padding**: `%.<count>x` prints exactly `<count>` hex characters
2. **Use `%hn`**: Write only 2 bytes (useful for 32-bit addresses)
3. **Write in two steps**: Low bytes first, then high bytes

**Why two steps**: Writing a full 32-bit address like `0x08049724` would require printing 134,000,000+ characters. Using `%hn` twice (2 bytes each) is much more efficient.

**GOT Overwrite Pattern**:

The Global Offset Table (GOT) contains addresses of external functions. Overwriting a GOT entry redirects function calls.

**Use the script**: `scripts/got_overwrite_template.py` for a ready-to-use template.

```python
from pwn import *

elf = context.binary = ELF('./vulnerable_binary')
libc = elf.libc

p = process()

# Overwrite printf's GOT entry with system's address
payload = fmtstr_payload(offset, {elf.got['printf']: libc.sym['system']})
p.sendline(payload)

# Now printf() calls system()
p.sendline('/bin/sh')
p.interactive()
```

## Windows x64 ASLR Bypass

On Windows x64, the first 4 parameters are in registers (RCX, RDX, R8, R9). When a format string is used without varargs, `%p` reads from R9, often leaking a stable pointer.

**Use the script**: `scripts/windows_aslr_bypass.py` for this technique.

**Why this works**: The leaked pointer has a known offset within the module. Subtract the offset to get the base address, then calculate all other addresses.

```python
# Leak R9 via %p
leaked = int(received_output, 16)
base = leaked - KNOWN_OFFSET  # Found during local reversing
```

## Common Vulnerable Patterns

**Vulnerable**:
```c
char buffer[30];
gets(buffer);  // User input
printf(buffer);  // DANGEROUS: buffer as format string
```

**Safe**:
```c
char buffer[30];
gets(buffer);
printf("%s", buffer);  // Safe: format string is constant
```

## Exploitation Workflow

1. **Identify the vulnerability**: User input → printf-family function
2. **Find the offset**: Use `scripts/find_offset.py`
3. **Determine protection status**: Check for ASLR, canary, RELRO, PIE
4. **Choose attack**:
   - **No ASLR**: Direct GOT overwrite
   - **ASLR enabled**: Leak address first, then overwrite
5. **Craft payload**: Use `fmtstr_payload()` or manual construction
6. **Test and iterate**: Adjust offsets and addresses as needed

## Scripts Available

- `scripts/find_offset.py` - Brute force stack offset
- `scripts/got_overwrite_template.py` - GOT overwrite exploit template
- `scripts/windows_aslr_bypass.py` - Windows x64 ASLR bypass

## References

- [HackTricks Format Strings](https://book.hacktricks.xyz/pentesting/remote-code-execution/rce/format-string-vulnerabilities)
- [CTF Recipes - Data Leak](https://www.ctfrecipes.com/pwn/stack-exploitation/format-string/data-leak)
- [GuyInATuxedo Format String Series](https://guyinatuxedo.github.io/10-fmt_strings/)
- [ir0nstone Notes](https://ir0nstone.gitbook.io/notes/types/stack/format-string)
