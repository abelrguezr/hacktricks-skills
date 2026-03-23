---
name: pointer-redirecting
description: Use this skill when analyzing buffer overflow vulnerabilities where you need to redirect stack pointers (string or function pointers) instead of overwriting return addresses. Trigger this when: the overflow cannot reach the saved return address due to canaries, you need to upgrade a primitive to arbitrary write/read, you're working with AArch64 PAC/BTI protections, or you want to redirect system/popen/execl* calls, leak data through puts/write sinks, or create second-stage write primitives. Always use this skill when auditing stack-based overflows and considering pointer corruption as an alternative to classic ret2win.
---

# Pointer Redirecting Exploitation

This skill guides you through exploiting buffer overflows by corrupting stack pointers rather than return addresses. This technique is especially valuable when classic return address overwrites are blocked by canaries, or when you need to upgrade a primitive for more complex exploitation.

## When to Use Pointer Redirecting

Use pointer redirection when:
- The overflow stops at the stack canary before reaching the return address
- You need to create a second-stage arbitrary write primitive
- Working with AArch64 targets where PAC/BTI blocks classic return address hijacks
- A nearby pointer is easier to corrupt than the return address
- You want to redirect function calls (system, popen, execl*) to attacker-controlled strings
- You need to leak data by redirecting read sinks (puts, write)

## Core Concepts

### String Pointer Redirection

When a function uses a stack-allocated string pointer, you can overwrite that pointer to redirect it to a different string in memory.

**Attack pattern:**
1. Identify a local string pointer (e.g., `char *cmd`, `char *path`, `char *buf`)
2. Overflow a nearby buffer to overwrite the pointer's address
3. Point it to a string you control or that already exists in memory
4. When the function uses that pointer (e.g., `system(cmd)`), your string executes

**Common targets:**
- Pointers used by `system()`, `popen()`, `execl*()` family
- Pointers passed to `puts()`, `printf("%s", ptr)` for data leaks
- Pointers used in `strcpy()`, `memcpy()` for arbitrary writes
- Pointers inside temporary request/response structs

### Function Pointer Redirection

Same concept applied to function pointers stored on the stack.

**Attack pattern:**
1. Find a function pointer in a local struct or variable
2. Overflow to overwrite the function pointer address
3. Redirect it to `system()`, `execve()`, or another useful function
4. Trigger the indirect call

**Common targets:**
- Callback variables: `void (*fp)()`
- Callbacks in local structs passed to helper functions
- Destructor/cleanup handlers on error paths
- Parser dispatch tables or state-machine handlers
- Local objects that dispatch through indirect calls

## Exploitation Workflow

### Step 1: Identify Candidate Pointers

Look for stack locals that are pointers and used after the vulnerable input:

```c
// Good targets:
char *cmd;      // Used later in system(cmd)
char *path;     // Used in fopen(path, "r")
FILE *fp;       // Used in fprintf(fp, ...)
void (*callback)();  // Called later
struct { void *ptr; int len; } data;  // ptr dereferenced later
```

**Prioritize pointers that:**
- Are used AFTER the overflow occurs
- Are used BEFORE the function returns
- Are in the same stack frame as the vulnerable buffer
- Have associated length/size fields you can also corrupt

### Step 2: Analyze the Corruption Window

Determine what you can overwrite:

```c
void vulnerable(char *input) {
    char buf[64];
    char *cmd = "ls";      // Address at offset +68
    int len = 10;          // Address at offset +76
    char *ptr = &buf[0];   // Address at offset +84
    
    strcpy(buf, input);    // Overflow here
    
    // After overflow:
    system(cmd);           // Uses cmd pointer
    memcpy(ptr, data, len); // Uses ptr and len
}
```

**Key questions:**
- How many bytes can you write before hitting the canary?
- Which pointers are within that range?
- Are there associated length/size fields you can corrupt too?

### Step 3: Choose Your Target

**For command execution:**
- Redirect to existing `/bin/sh` in the binary's string table
- Place your command string on the stack and point to it
- Use `export PATH=.:$PATH` trick with a script named after the first letter

**For data leaks:**
- Redirect `puts(ptr)` or `write(fd, ptr, len)` to stack/heap/binary data
- Useful for ASLR bypass or finding other addresses

**For arbitrary writes:**
- Corrupt a pointer AND its associated length
- Wait for `memcpy(ptr, src, len)` or `ptr->field = value`
- Use the resulting write-what-where to overwrite GOT, callbacks, or config pointers

### Step 4: Handle Partial Overwrites

If you can only overwrite part of the pointer (e.g., trailing NUL):

**Strategies:**
- Redirect to a nearby string in the same stack frame
- Point to another object in the same module (non-PIE)
- Target a controlled region where high bytes stay unchanged
- Use the existing high bytes to your advantage

**Example:** If you can only write 3 bytes to a 4-byte pointer:
- Original: `0x08048000`
- You write: `0x????8000` (last 2 bytes fixed)
- Find targets in the `0x????8000` range

### Step 5: AArch64 Considerations (PAC/BTI)

On modern AArch64 targets:

**PAC (Pointer Authentication):**
- Saved return addresses are authenticated with PAC
- Classic return address overwrites may fail
- Non-return hijacks (corrupted local function pointers) are more attractive

**BTI (Branch Target Identification):**
- Indirect call targets must land on valid landing pads
- Prefer real function entries over mid-function gadgets
- Look for functions with `bti c` or prologues with `paciasp`/`pacibsp`
- Ensure the indirect-call pointer isn't additionally authenticated before use

**AArch64 strategy:**
1. Target local function pointers instead of return addresses
2. Use real function entries as targets
3. Verify the target satisfies BTI requirements
4. Check if the pointer is authenticated before the indirect call

## Practical Examples

### Example 1: Redirecting system() Argument

```c
// Vulnerable code:
void process_input(char *input) {
    char buf[64];
    char *cmd = "ls";  // Points to string in .rodata
    
    strcpy(buf, input);  // Overflow
    system(cmd);         // Uses cmd pointer
}
```

**Exploit:**
1. Find address of `cmd` pointer on stack (offset +68 from buf)
2. Overflow buf with 68 bytes padding + address of "/bin/sh" on stack
3. Place "/bin/sh" string after the pointer address in your payload
4. When `system(cmd)` executes, it runs `/bin/sh`

### Example 2: Second-Stage Arbitrary Write

```c
// Vulnerable code:
void process_request(char *input) {
    char buf[64];
    struct { void *ptr; int len; } data;
    
    strcpy(buf, input);  // Overflow corrupts data.ptr and data.len
    
    // Later:
    memcpy(data.ptr, source, data.len);  // Arbitrary write!
}
```

**Exploit:**
1. Overflow to corrupt `data.ptr` to point to GOT entry
2. Corrupt `data.len` to desired write size
3. Control `source` to contain your payload (e.g., address of `system`)
4. When `memcpy` executes, you've written to the GOT
5. Next call to that function jumps to `system`

### Example 3: Data Leak via puts()

```c
// Vulnerable code:
void leak(char *input) {
    char buf[64];
    char *ptr = &secret[0];  // Points to sensitive data
    
    strcpy(buf, input);  // Overflow
    puts(ptr);           // Leaks data at ptr
}
```

**Exploit:**
1. Overflow to overwrite `ptr` with address of stack/heap/binary data
2. When `puts(ptr)` executes, it leaks the data at your chosen address
3. Use leaked addresses for ASLR bypass or finding other targets

## Common Pitfalls

1. **Don't forget the canary:** If the canary is between your buffer and target pointer, you'll crash before reaching it
2. **Check pointer usage timing:** The pointer must be used AFTER the overflow, not before
3. **Watch for NULL terminators:** Some bugs append `\0`, limiting your overwrite to partial bytes
4. **Verify the pointer isn't re-initialized:** Some code re-sets pointers after the vulnerable function
5. **Consider ASLR:** On ASLR-enabled targets, you may need to leak addresses first
6. **AArch64 PAC:** Don't try to overwrite PAC-protected return addresses without valid PAC

## Debugging Tips

**In GDB:**
```gdb
# Find pointer addresses
info frame
x/20gx $rsp

# Watch pointer usage
watch *cmd_ptr

# See what the pointer points to
x/s $cmd_ptr

# Trace execution
set follow-fork-mode child
run <payload>
```

**In pwntools:**
```python
from pwn import *

# Find addresses
elf = ELF('./vuln')
print(f"system: {elf.sym.system}")
print(f"/bin/sh: {next(elf.search(b'/bin/sh'))}")

# Build payload
payload = b'A' * 64  # Fill buffer
payload += p64(stack_addr + 68)  # Overwrite pointer
payload += b'/bin/sh\x00'  # New string

# Send and interact
p = process('./vuln')
p.sendline(payload)
p.interactive()
```

## When This Technique Wins

Pointer redirecting is your best option when:
- ✅ Canary blocks return address access
- ✅ Function pointer is closer than return address
- ✅ You need arbitrary write, not just control flow
- ✅ AArch64 with PAC/BTI protections
- ✅ The bug appends NULL (partial overwrite scenario)
- ✅ You want to leak data before full exploitation

## References

- [Stack Buffer Overflow Internship - Pointer Redirecting](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/NOTES.md#pointer-redirecting)
- [CVE-2024-20017 Exploitation Writeup](https://blog.coffinsec.com/0day/2024/08/30/exploiting-CVE-2024-20017-four-different-ways.html)
- [ARM PAC/BTI Documentation](https://developer.arm.com/community/arm-community-blogs/b/architectures-and-processors-blog/posts/enabling-pac-and-bti-on-aarch64)
- [strptr.c Example](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/ASLR%20Smack%20and%20Laugh%20reference%20-%20Tilo%20Mueller/strptr.c)
- [funcptr.c Example](https://github.com/florianhofhammer/stack-buffer-overflow-internship/blob/master/ASLR%20Smack%20and%20Laugh%20reference%20-%20Tilo%20Mueller/funcptr.c)
