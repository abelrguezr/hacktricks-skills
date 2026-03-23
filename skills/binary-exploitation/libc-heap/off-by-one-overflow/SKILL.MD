---
name: off-by-one-heap-exploit
description: How to exploit off-by-one heap overflow vulnerabilities in glibc. Use this skill whenever the user mentions heap exploitation, off-by-one vulnerabilities, glibc heap attacks, tcache poisoning, chunk size corruption, or any scenario where a single-byte write can corrupt heap metadata. Also trigger for CVE-2023-6779, syslog exploits, safe-linking bypasses, or when analyzing heap-based vulnerabilities in CTF challenges or real-world targets.
---

# Off-by-One Heap Overflow Exploitation

This skill guides you through exploiting off-by-one (OBO) heap overflow vulnerabilities in glibc-based systems. An OBO vulnerability allows writing exactly one byte past a buffer's boundary, which can corrupt the `size` field of the next heap chunk.

## Understanding the Vulnerability

### What is an Off-by-One Overflow?

An off-by-one overflow occurs when a program writes one byte beyond the intended buffer boundary. This single byte can corrupt the `size` field of the adjacent heap chunk, enabling:

- **Chunk size manipulation**: Modify how much memory a chunk claims to occupy
- **Overlapping chunks**: Make one chunk contain another, enabling arbitrary writes
- **Tcache poisoning**: Redirect allocations to attacker-controlled addresses
- **Double-free scenarios**: Create conditions for memory reuse attacks

### Two Types of OBO Vulnerabilities

1. **Arbitrary byte OBO**: Can overwrite the boundary byte with any value (0x00-0xFF)
2. **Null byte OBO (off-by-null)**: Can only write 0x00 to the boundary
   - Common in `strlen`/`strcpy` mismatches
   - Can be exploited with House of Einherjar technique
   - With tcache, can create double-free conditions

## General Attack Methodology

### Step 1: Setup the Heap Layout

Allocate chunks in a specific arrangement to enable the attack:

```
[ Chunk A (0x20) ] [ Chunk B (0x20) ] [ Chunk C (0x20) ] [ Chunk D (0x20) ]
```

- Allocate three chunks (A, B, C) of the same size (e.g., 0x20)
- Allocate a fourth chunk (D) to prevent consolidation with the top chunk
- This creates a controlled heap layout for exploitation

### Step 2: Create the Overflow Condition

1. **Free chunk C**: This inserts it into the tcache free-list (for 0x20 chunks)
2. **Overflow from A into B**: Use the OBO vulnerability to write one byte past A's boundary
3. **Corrupt B's size field**: Change B's size from 0x21 to 0x41 (or similar)

### Step 3: Create Overlapping Chunks

After corrupting B's size:

```
[ Chunk A ] [ Chunk B (now claims 0x40, contains C) ] [ Chunk D ]
```

- Chunk B now "contains" the freed chunk C
- C is still in the tcache free-list
- This creates the overlapping condition needed for exploitation

### Step 4: Trigger the Overlap

1. **Free chunk B**: This consolidates B with its "contained" chunk C
2. **Allocate a 0x40 chunk**: This allocation will reuse the B+C space
3. **Modify C's fd pointer**: Since C is still in tcache, you can poison it

### Step 5: Tcache Poisoning

With C's fd pointer corrupted:

1. **Free the overlapping chunk**: This adds it to tcache
2. **Poison C's fd**: Point it to an address you control (e.g., `__free_hook`)
3. **Trigger allocation**: Next malloc will place your fake chunk at the poisoned address
4. **Achieve arbitrary write**: Write shellcode or one_gadget to the target

## Modern glibc Hardening (>= 2.32)

### Safe-Linking Protection

Modern glibc uses safe-linking to protect tcache pointers:

```
fd = ptr ^ (chunk_addr >> 12)
```

This XOR encoding means:
- You need a heap leak to compute the XOR mask
- Single-byte size corruption alone is insufficient
- You must re-encode pointers before writing them

### Bypass Strategy

1. **Grow victim chunk**: Make it fully cover a freed chunk you control
2. **Leak a heap pointer**: Use stdout, UAF, or partially controlled struct
3. **Derive the key**: `heap_base >> 12`
4. **Re-encode pointers**: Use the protect/reveal helper (see scripts)
5. **Stage encoded values**: Place them in user data, memcpy later
6. **Combine with tcache attacks**: Redirect to `__free_hook` or tcache entries

### Double-Protect Technique

For leakless exploitation:

1. **Encode a controlled pointer**: Use `PROTECT_PTR` on a pointer you already own
2. **Reuse the gadget**: Encode your forged pointer with the same XOR key
3. **Alignment check passes**: No new address revelation needed

## Off-by-Null Specific Attack

When you can only write 0x00:

1. **Allocate three chunks**: a, b, c in sequence
2. **Free the middle chunk (b)**
3. **Overflow from a with 0x00**: This reduces b's apparent size
4. **Allocate two smaller chunks in b**: b1 and b2
5. **Free b1 and c**: They consolidate, but b2 remains inside
6. **Allocate new chunk**: It contains b2, giving you control over its content

## Practical Exploitation Workflow

### 1. Identify the Vulnerability

Look for:
- Buffer size calculations that are off by one
- `strlen`/`strcpy` mismatches
- Format string vulnerabilities with INT_MAX truncation
- Off-by-one in array bounds checking

### 2. Map the Heap Layout

Use `pwndbg` or `gef`:

```bash
heap bins
heap chunks
vmmap
```

Identify:
- Chunk sizes and positions
- Which chunks are in tcache
- Adjacent chunk relationships

### 3. Craft the Exploit

Use the helper scripts:
- `scripts/protect_reveal.py` for safe-linking encoding
- `scripts/exploit_template.py` for exploit scaffolding

### 4. Test and Iterate

- Start with a simple heap leak
- Progress to size corruption
- Add tcache poisoning
- Finalize with arbitrary write

## Real-World Example: CVE-2023-6779

### Vulnerability Details

- **Location**: `__vsyslog_internal()` in glibc 2.37-2.39
- **Trigger**: `syslog()` format strings exceeding `INT_MAX`
- **Effect**: Terminating `\0` corrupts next chunk's size byte
- **Impact**: Root via `__free_hook` overwrite

### Exploitation Pipeline

1. **Craft overlong `openlog()` ident**: Makes `vasprintf` return adjacent heap buffer
2. **Call `syslog()`**: Smashes neighbor chunk's `size | prev_inuse` byte
3. **Free and consolidate**: Creates overlapping chunk with attacker data
4. **Corrupt tcache metadata**: Aim next allocation at `__free_hook`
5. **Overwrite with system/one_gadget**: Achieve root

### Reproduction Harness

```python
# Fork with gigantic argv[0]
# Call openlog(NULL, LOG_PID, LOG_USER)
# Call syslog(LOG_INFO, "%s", payload)
# where payload = b"A" * 0x7fffffff
# Check with: pwndbg heap bins
```

## CTF Writeup Patterns

### Bon-nie-appetit (HTB Cyber Apocalypse 2022)

- **Vulnerability**: `strlen` considers next chunk's size field
- **Technique**: General OBO with tcache poisoning
- **Result**: Arbitrary write primitive

### Asis CTF 2016 b00ks

- **Vulnerability**: OBO leaks heap address via 0x00 byte
- **Technique**: Fake struct with fake pointers
- **Result**: Arbitrary write to `__free_hook` with one_gadget

### PlaidCTF 2015 plaiddb

- **Vulnerability**: NULL OBO in `getline` function
- **Technique**: Multi-chunk consolidation with fd poisoning
- **Result**: `__malloc_hook` overwrite with one_gadget

## Common Pitfalls

1. **Tcache interference**: Small chunks (<= 0x40) go to tcache, not fastbins
2. **Safe-linking**: Modern glibc requires XOR encoding
3. **Alignment**: Chunk addresses must be properly aligned
4. **Consolidation**: Adjacent free chunks may merge unexpectedly
5. **Top chunk**: Don't let your chunks consolidate with the top chunk

## Debugging Tips

### With pwndbg

```bash
# View heap layout
heap chunks
heap bins

# View specific chunk
heap chunk <address>

# Watch for changes
watch *(size_t*)<chunk_address>
```

### With GDB + gef

```bash
heap-analysis
heap-context
```

## When to Use This Skill

Use this skill when:
- You encounter an off-by-one vulnerability in a CTF or real target
- You need to corrupt heap metadata with a single-byte write
- You're working with glibc heap exploitation
- You need to bypass safe-linking in modern glibc
- You're analyzing CVE-2023-6779 or similar syslog vulnerabilities
- You need tcache poisoning techniques
- You're dealing with chunk size corruption attacks

## Helper Scripts

Use the bundled scripts for:
- `scripts/protect_reveal.py`: Safe-linking encode/decode
- `scripts/exploit_template.py`: Exploit scaffolding

Run them with:
```bash
python scripts/protect_reveal.py --help
python scripts/exploit_template.py --help
```

## References

- [heap-exploitation.dhavalkapil.com](https://heap-exploitation.dhavalkapil.com/attacks/shrinking_free_chunks)
- [Qualys CVE-2023-6246/6779/6780 Advisory](https://www.qualys.com/2024/01/30/cve-2023-6246/syslog.txt)
- [Ubuntu CVE-2023-6779](https://ubuntu.com/security/CVE-2023-6779)
- [Breaking Safe-Linking in Modern Glibc](https://blog.csdn.net/2402_86373248/article/details/148717274)
