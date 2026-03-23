---
name: format-string-exploitation
description: How to exploit format string vulnerabilities in C binaries. Use this skill whenever the user mentions format string vulnerabilities, printf vulnerabilities, GOT/PLT overwrites, or needs to exploit a binary with format string bugs. This skill automates finding the format string offset, crafting payloads, and overwriting GOT entries to redirect function calls (e.g., printf → system) for code execution.
---

# Format String Exploitation

A skill for exploiting format string vulnerabilities in C binaries using pwntools.

## When to Use This Skill

Use this skill when:
- You're given a binary with a format string vulnerability (e.g., `printf(user_input)` without format specifiers)
- You need to leak stack memory or overwrite GOT entries
- You want to redirect function calls (printf → system) for shellcode execution
- You're working on CTF challenges involving format string bugs

## Quick Start

1. **Configure the connection** in `scripts/format_string_exploit.py`:
   - Set `LOCAL = True` for local testing
   - Set `REMOTETTCP = True` for remote TCP
   - Set `REMOTESSH = True` for SSH (e.g., OverTheWire)

2. **Run the exploit**:
   ```bash
   python scripts/format_string_exploit.py
   ```

3. **Review the output** - the script will:
   - Automatically find the format string offset
   - Overwrite GOT entries
   - Spawn an interactive shell

## How Format String Exploitation Works

### The Vulnerability

Format string vulnerabilities occur when user input is passed directly to format functions like `printf()`, `fprintf()`, or `sprintf()` without a format string argument:

```c
// VULNERABLE
char *input = get_user_input();
printf(input);  // User can use %x, %s, %n to read/write memory

// SAFE
printf("%s", input);  // Format string is controlled
```

### Attack Phases

1. **Find the offset**: Determine which position in the format string corresponds to your input
2. **Leak memory**: Use `%x` or `%p` to read stack values
3. **Overwrite GOT**: Use `%n` to write addresses to memory
4. **Redirect execution**: Point printf GOT entry to system PLT
5. **Trigger shell**: Find where printf is called with controlled input

## Configuration Options

| Variable | Description | Default |
|----------|-------------|----------|
| `LOCAL` | Run binary locally | `True` |
| `REMOTETTCP` | Connect via TCP | `False` |
| `REMOTESSH` | Connect via SSH | `False` |
| `GDB` | Attach GDB for debugging | `False` |
| `LOCAL_BIN` | Path to vulnerable binary | `"./tyler"` |
| `PREFIX_PAYLOAD` | Bytes to prepend to payload | `b""` |
| `SUFFIX_PAYLOAD` | Bytes to append to payload | `b""` |
| `MAX_LENTGH` | Maximum payload length | `999999` |

## Example Usage

### Local Binary

```python
LOCAL = True
LOCAL_BIN = "./vulnerable_binary"
```

### Remote TCP

```python
REMOTETTCP = True
# Update in connect_binary():
P = remote('10.10.10.10', 1338)
```

### SSH (OverTheWire)

```python
REMOTESSH = True
REMOTE_BIN = "./tyler"
# SSH credentials configured in connect_binary()
```

## Advanced: Loop Back for Extra Execution

Some binaries require looping back to the vulnerability for a second exploitation. Uncomment in the script:

```python
P_FINI_ARRAY = ELF_LOADED.symbols["__init_array_end"]
INIT_LOOP_ADDR = 0x8048614  # Address to return to
format_string.write(P_FINI_ARRAY, INIT_LOOP_ADDR)
```

## Troubleshooting

### Offset not found
- Increase the search range in `get_formatstring_config()`
- Check if the binary has ASLR enabled (`setarch -R`)
- Verify the binary actually has a format string vulnerability

### GOT overwrite fails
- Check if the binary is PIE (Position Independent Executable)
- Verify GOT entry is writable
- Ensure you're writing the correct address

### Shell doesn't spawn
- Find where printf is called with user-controlled input
- The input should contain `/bin/sh` or similar
- Check if the binary has a second call to printf after GOT overwrite

## References

- [HackTricks Format Strings](https://book.hacktricks.xyz/pentesting/ctf/ctf-writeups/binary-exploitation/format-strings)
- [pwntools FmtStr](https://docs.pwntools.com/en/stable/tubes.html#fmtstr)
- [Format String Attacks - Phrack 59](https://phrack.org/issues/59/10.html)

## Script Files

- `scripts/format_string_exploit.py` - Main exploitation script

Run the script after configuring your connection settings. The script will automatically:
1. Find the format string offset
2. Overwrite printf GOT with system PLT
3. Spawn an interactive shell
