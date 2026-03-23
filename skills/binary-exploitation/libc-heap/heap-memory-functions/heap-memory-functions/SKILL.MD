---
name: heap-memory-functions
description: How to analyze and understand heap memory functions (malloc, free, realloc, calloc) in binary exploitation and security research. Use this skill whenever the user mentions heap memory, memory allocation, malloc/free, heap exploitation, glibc heap, tcache, bins, or any heap-related vulnerability analysis. This skill helps with understanding heap internals, debugging heap issues, and identifying heap-based vulnerabilities.
---

# Heap Memory Functions Analysis

A skill for analyzing heap memory functions and understanding heap-based vulnerabilities in binary exploitation.

## Overview

This skill helps you understand and analyze heap memory management functions, including:
- **malloc()** - Dynamic memory allocation
- **free()** - Memory deallocation
- **realloc()** - Resizing allocated memory
- **calloc()** - Zero-initialized allocation
- **Heap internals** - Tcache, bins, chunks, metadata

## When to Use This Skill

Use this skill when you need to:
- Analyze heap memory allocation patterns in binaries
- Debug heap corruption or use-after-free vulnerabilities
- Understand glibc malloc implementation details
- Investigate heap-based exploits (heap overflow, double free, use-after-free)
- Learn about heap metadata and chunk structures
- Analyze memory allocation in C/C++ programs

## Core Concepts

### Heap Chunk Structure

In glibc's malloc implementation, each allocated chunk has metadata:

```
+------------------+
| prev_size        |  (8 bytes) - size of previous chunk
+------------------+
| size | flags    |  (8 bytes) - current chunk size + flags
+------------------+
| user data        |  (variable) - actual allocated memory
+------------------+
```

**Key flags:**
- `PREV_INUSE` (bit 0): Previous chunk is in use
- `IS_MMAPPED` (bit 1): Chunk was allocated via mmap
- `NON_MAIN_ARENA` (bit 2): Chunk belongs to non-main arena

### Tcache (Thread-Cache)

Modern glibc (2.26+) uses tcache for small allocations:
- Stores up to 7 freed chunks per size class
- First-in, last-out (FIFO) behavior
- Bypasses tcache for large allocations
- Can be disabled with `setenv("MALLOC_CHECK_", "0", 1)`

### Bins

Free chunks are organized into bins:
- **Unsorted bin**: Recently freed chunks, O(1) allocation
- **Small bins**: 64 bins for sizes 32-512 bytes
- **Large bins**: 12 bins for sizes >512 bytes
- **Tcache bins**: Per-thread cache for small chunks

## Analysis Workflow

### Step 1: Identify Heap Functions

Use the `find_heap_functions.sh` script to locate heap-related function calls:

```bash
./scripts/find_heap_functions.sh <binary>
```

This identifies all malloc, free, realloc, and calloc calls in the binary.

### Step 2: Analyze Allocation Patterns

Examine how the program allocates memory:
- Track allocation sizes
- Identify allocation order
- Look for patterns that could lead to vulnerabilities

### Step 3: Check for Common Vulnerabilities

Use the `check_heap_vulns.sh` script to identify potential issues:

```bash
./scripts/check_heap_vulns.sh <source_file.c>
```

Common vulnerabilities to look for:
- **Use-after-free**: Accessing freed memory
- **Double free**: Freeing the same pointer twice
- **Heap overflow**: Writing beyond allocated size
- **Integer overflow**: Size calculation errors
- **Off-by-one errors**: Boundary condition mistakes

### Step 4: Debug with GDB

Use GDB with the `glibc-malloc` plugin or `heap` commands:

```gdb
(gdb) break main
(gdb) run
(gdb) heap
(gdb) heap chunks
(gdb) heap bins
```

Or use `pwndbg`/`gef` for enhanced heap debugging:

```gdb
(gdb) heap
(gdb) heap chunks
(gdb) tcache
(gdb) bins
```

## Common Exploitation Techniques

### 1. Use-After-Free (UAF)

**Pattern:**
```c
char *ptr = malloc(100);
free(ptr);
// ptr still points to freed memory
strcpy(ptr, "malicious data");  // UAF!
```

**Exploitation:**
- Free the target chunk
- Allocate new data in the freed slot
- Use the dangling pointer to control the new allocation

### 2. Double Free

**Pattern:**
```c
char *ptr = malloc(100);
free(ptr);
free(ptr);  // Double free!
```

**Exploitation:**
- Corrupts heap metadata
- Can lead to arbitrary write primitives
- Often combined with UAF

### 3. Heap Overflow

**Pattern:**
```c
char *ptr = malloc(100);
strcpy(ptr, large_buffer);  // Overflow!
```

**Exploitation:**
- Overwrite adjacent chunk metadata
- Corrupt size/prev_size fields
- Trigger controlled free to gain arbitrary write

### 4. Tcache Poisoning

**Pattern:**
- Exploit tcache's lack of validation
- Inject fake chunks into tcache
- Control allocation targets

**Requirements:**
- glibc 2.26+
- Target size < 0x80 (tcache max)
- Tcache not disabled

## Scripts

### find_heap_functions.sh

Locates all heap function calls in a binary:

```bash
#!/bin/bash
# Usage: ./find_heap_functions.sh <binary>
# Finds all malloc, free, realloc, calloc calls

if [ -z "$1" ]; then
    echo "Usage: $0 <binary>"
    exit 1
fi

binary="$1"

echo "=== Heap Function Calls in $binary ==="
echo ""

# Find malloc calls
echo "malloc() calls:"
objdump -d "$binary" | grep -A5 "<malloc>" | head -20

echo ""
echo "free() calls:"
objdump -d "$binary" | grep -A5 "<free>" | head -20

echo ""
echo "realloc() calls:"
objdump -d "$binary" | grep -A5 "<realloc>" | head -20

echo ""
echo "calloc() calls:"
objdump -d "$binary" | grep -A5 "<calloc>" | head -20
```

### check_heap_vulns.sh

Analyzes C source for common heap vulnerabilities:

```bash
#!/bin/bash
# Usage: ./check_heap_vulns.sh <source.c>
# Checks for common heap vulnerability patterns

if [ -z "$1" ]; then
    echo "Usage: $0 <source.c>"
    exit 1
fi

source_file="$1"

echo "=== Heap Vulnerability Analysis ==="
echo "File: $source_file"
echo ""

# Check for potential double frees
echo "Potential double free patterns:"
grep -n "free(" "$source_file" | while read line; do
    ptr=$(echo "$line" | grep -oP 'free\(\K[^)]+' | head -1)
    if [ -n "$ptr" ]; then
        count=$(grep -c "free($ptr)" "$source_file" 2>/dev/null || echo "1")
        if [ "$count" -gt 1 ]; then
            echo "  WARNING: $ptr freed $count times"
        fi
    fi
done

# Check for use-after-free patterns
echo ""
echo "Potential use-after-free patterns:"
grep -B5 -A5 "free(" "$source_file" | grep -A5 "free(" | grep -E "\*|\[|strcpy|memcpy" | head -10

# Check for unsafe string operations after malloc
echo ""
echo "Unsafe operations after malloc:"
grep -B2 -A2 "malloc(" "$source_file" | grep -E "strcpy|sprintf|gets" | head -10

echo ""
echo "Analysis complete. Review flagged patterns manually."
```

## Debugging Tips

### GDB Heap Commands

```gdb
# Basic heap inspection
heap
heap chunks
heap bins

# With pwndbg/gef
heap
heap chunks
heap bins
tcache
bins

# Inspect specific chunk
x/20gx 0x<chunk_address>

# Follow allocation
break malloc
run
info registers
```

### Environment Variables

```bash
# Disable tcache for debugging
export MALLOC_CHECK_=0
export MALLOC_TRIM_THRESHOLD_=128

# Enable malloc debugging
export MALLOC_CHECK_=2  # Abort on corruption
export MALLOC_CHECK_=3  # Abort on corruption + check pointers

# Set heap size
export MALLOC_MMAP_THRESHOLD_=131072
```

## Best Practices

### For Analysis

1. **Start with static analysis** - Use `find_heap_functions.sh` to map allocation patterns
2. **Identify allocation sizes** - Track what sizes are allocated and when
3. **Look for patterns** - Repeated allocations of same size often indicate tcache usage
4. **Check for metadata corruption** - Look for writes near chunk boundaries
5. **Understand the allocator** - Know which glibc version and malloc implementation

### For Exploitation

1. **Map the heap** - Understand chunk layout and bin organization
2. **Control allocations** - Use controlled allocations to position chunks
3. **Corrupt metadata** - Target size/prev_size fields for arbitrary writes
4. **Leverage tcache** - Use tcache poisoning for simpler exploitation
5. **Chain vulnerabilities** - Combine UAF, double free, and overflow for full control

## References

- [glibc malloc source](https://sourceware.org/git/?p=glibc.git;a=tree;f=malloc)
- [Heap Feng Shui](https://www.phrack.org/issues/64/10.html)
- [Tcache exploitation](https://github.com/shellphish/how2heap)
- [pwndbg heap commands](https://github.com/pwndbg/pwndbg)

## Next Steps

After analyzing heap functions:
1. Use GDB to inspect actual heap state during execution
2. Create test cases to verify vulnerability hypotheses
3. Develop exploitation primitives based on findings
4. Consider combining with other vulnerabilities for full exploitation
