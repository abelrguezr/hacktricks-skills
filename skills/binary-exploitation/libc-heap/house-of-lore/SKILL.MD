---
name: house-of-lore-exploit
description: How to perform a House of Lore (small bin attack) heap exploitation. Use this skill whenever the user mentions heap exploitation, small bin attacks, fake chunks, glibc heap vulnerabilities, or needs to insert fake chunks into small bins for arbitrary read/write. Trigger for CTF challenges involving heap corruption, glibc 2.31+ exploitation, or when the user needs to bypass malloc sanity checks using fake chunk linking.
---

# House of Lore Exploit (Small Bin Attack)

A heap exploitation technique that inserts fake small chunks into the small bin to gain arbitrary read/write capabilities.

## What This Attack Does

Inserts a **fake small chunk** into the small bin so it can be allocated, allowing you to read/write pointers inside it. The fake chunk is attacker-controlled, not a legitimate freed chunk.

## Requirements

You need:
1. **A small chunk vulnerability** - ability to free and reallocate small chunks
2. **A pointer write primitive** - to modify `legit.fd` to point to your fake chunk
3. **glibc 2.31+** - this attack targets the small bin management
4. **Two fake chunks** - properly linked together and with the legitimate chunk

## The Chunk Linking Structure

You must create this exact linking pattern:

```
fake0.bk -> fake1
fake1.fd -> fake0
fake0.fd -> legit (requires pointer write primitive)
legit.bk -> fake0
```

## Step-by-Step Attack

### Phase 1: Setup the Legitimate Chunk

1. Allocate a small chunk (`legit`)
2. Allocate another chunk to prevent consolidation with top chunk
3. Free `legit` (moves to unsorted bin)
4. Allocate a larger chunk (moves `legit` to small bin)

### Phase 2: Create Fake Chunks

Generate two fake chunks with proper metadata:

```python
# Example fake chunk structure (little-endian)
fake0 = struct.pack('<QQ', size0, fake1_addr)  # size, fd
fake0 += struct.pack('<QQ', fake1_addr, 0)     # bk, fd_nextsize
fake0 += struct.pack('<QQ', 0, 0)              # bk_nextsize, padding

fake1 = struct.pack('<QQ', size1, fake0_addr)  # size, fd
fake1 += struct.pack('<QQ', fake0_addr, 0)     # bk, fd_nextsize
fake1 += struct.pack('<QQ', 0, 0)              # bk_nextsize, padding
```

**Key requirements for fake chunks:**
- `size` must be valid small bin size (typically 0x20-0x100)
- `PREV_INUSE` bit must be set (bit 0 of size)
- `fd` and `bk` must point to valid heap addresses
- Chunks must be properly aligned (8-byte on 64-bit)

### Phase 3: Link the Chunks

1. Write `fake0` and `fake1` to heap memory (via overflow or other primitive)
2. Use your pointer write primitive to set `legit.fd = fake0_addr`
3. Ensure `legit.bk = fake0_addr` (may need another write)

### Phase 4: Trigger the Exploit

1. Allocate a small chunk → gets `legit`, making `fake0` the new head of small bin
2. Allocate another small chunk → gets `fake0` (your fake chunk!)
3. Now you can read/write through `fake0` to control heap metadata

## Common Pitfalls

| Issue | Solution |
|-------|----------|
| `malloc(): unaligned tcache chunk detected` | Ensure 8-byte alignment on 64-bit systems |
| `malloc(): corrupted top size` | Verify size field has PREV_INUSE bit set |
| `double free or corruption` | Don't free chunks that are already in bins |
| Sanity check failures | Double-check all fd/bk pointers are valid heap addresses |

## Working Examples

Use these as reference implementations:

- **GuyInATuxedo**: https://guyinatuxedo.github.io/40-house_of_lore/house_lore_exp/index.html
- **CTF Wiki**: https://ctf-wiki.mahaloz.re/pwn/linux/glibc-heap/house_of_lore/
- **Heap Exploitation Guide**: https://heap-exploitation.dhavalkapil.com/attacks/house_of_lore

## Helper Scripts

Use the bundled scripts to generate and verify fake chunks:

```bash
# Generate fake chunk metadata
python scripts/generate_fake_chunks.py --size 0x20 --addr1 0x555555556000 --addr2 0x555555556100

# Verify linking structure
python scripts/verify_linking.py --fake0 0x555555556000 --fake1 0x555555556100 --legit 0x555555556200
```

## When to Use This Attack

- You have a heap overflow that can write to chunk metadata
- You need arbitrary read/write but don't have a direct write primitive
- The target uses glibc 2.31+ with small bins
- Other heap attacks (House of Force, etc.) are blocked by sanity checks

## Next Steps After Exploitation

Once you control `fake0`:
1. Overwrite `fd`/`bk` pointers to redirect allocations
2. Create fake chunks pointing to GOT entries for arbitrary write
3. Use `unlink()` style attacks for code execution
4. Combine with other primitives for full RCE
