---
name: macos-mig-analyzer
description: Analyze Mach Interface Generator (MIG) IPC on macOS. Use this skill whenever the user mentions MIG, Mach IPC, macOS inter-process communication, binary analysis of Mach-O files with IPC, extracting dispatch tables from macOS binaries, or reverse engineering macOS system services. Trigger for any task involving .defs files, mach_port, bootstrap_look_up, jtool2 MIG analysis, or identifying RPC functions in macOS binaries.
---

# macOS MIG Analyzer

A skill for analyzing Mach Interface Generator (MIG) based inter-process communication on macOS systems.

## When to Use This Skill

Use this skill when:
- Analyzing macOS binaries that use Mach IPC
- Reverse engineering MIG-based system services
- Extracting dispatch tables from Mach-O binaries
- Understanding `.defs` interface definition files
- Identifying RPC functions in macOS daemons
- Debugging Mach port communication
- Using `jtool2` to parse MIG information

## MIG Fundamentals

MIG (Mach Interface Generator) simplifies Mach IPC code creation by generating server and client code from Interface Definition Language (IDL) files with `.defs` extension.

### Definition File Structure

MIG definitions have 5 sections:

1. **Subsystem declaration**: Specifies name and ID, optionally marked as `KernelServer`
2. **Inclusions and imports**: Uses C-preprocessor, supports `uimport` and `simport`
3. **Type declarations**: Custom types with `[in/out]tran`, `c[user/server]type`, `destructor`
4. **Operations**: RPC method definitions (5 types: `routine`, `simpleroutine`, `procedure`, `simpleprocedure`, `function`)
5. **Generated code**: Server and client stubs

### Operation Types

| Type | Expects Reply |
|------|---------------|
| `routine` | Yes |
| `simpleroutine` | No |
| `procedure` | Yes |
| `simpleprocedure` | No |
| `function` | Yes |

## Binary Analysis Workflow

### Step 1: Identify MIG Usage

Check if a binary uses MIG by looking for `_NDR_record` dependency:

```bash
jtool2 -S <binary> | grep NDR
# or
nm <binary> | grep NDR
```

MIG servers have dispatch tables in `__DATA.__const` (macOS userland) or `__CONST.__constdata` (kernel).

### Step 2: Extract MIG Dispatch Information

Use `jtool2` to parse MIG data from the binary:

```bash
# Extract dispatch table
jtool2 -d __DATA.__const <binary> | grep MIG

# Find function calls (BL instructions)
jtool2 -d __DATA.__const <binary> | grep BL
```

### Step 3: Locate Routine Descriptors

The dispatch table contains `routine_descriptor` structs (0x28 bytes each):

```c
struct routine_descriptor {
    mig_impl_routine_t  impl_routine;    // 8 bytes - actual function address
    mig_stub_routine_t  stub_routine;    // 8 bytes - stub function
    int                 const_count;     // 4 bytes
    int                 var_count;       // 4 bytes
    routine_arg_descriptor_t *arg_desc;  // 8 bytes
    mach_msg_size_t     maxsize;         // 4 bytes
    // padding to 0x28
};
```

Each descriptor is 0x28 bytes. The first 8 bytes contain the function address.

### Step 4: Map Message IDs to Functions

MIG uses sequential IDs starting from the subsystem ID:

```c
// Example: subsystem myipc 500
// First operation = ID 500, second = ID 501, etc.

// In generated code:
msgh_id = InHeadP->msgh_id - 500;  // Calculate index
routine = subsystem.routine[msgh_id].stub_routine;
```

### Step 5: Analyze Server Routine

The `myipc_server` function (or similar) handles message dispatch. Key patterns:

1. Validates message ID range
2. Calculates array index: `msgh_id - start_id`
3. Looks up function pointer in dispatch table
4. Calls the appropriate handler

Look for this pattern in decompiled code:
```c
if (msgh_id >= start && msgh_id <= end) {
    routine = dispatch_table[msgh_id - start].stub_routine;
    if (routine != 0) {
        routine(InHeadP, OutHeadP);
        return TRUE;
    }
}
```

## Common Analysis Tasks

### Extract All MIG Functions from Binary

```bash
# Get the dispatch table address
jtool2 -s <binary> | grep -A5 "__DATA.__const"

# Dump the section
jtool2 -d __DATA.__const <binary> > mig_dump.txt

# Look for routine descriptors (search for MIG patterns)
grep -A20 "subsystem" mig_dump.txt
```

### Find Bootstrap Service Names

MIG servers often register with bootstrap:

```bash
# Search for bootstrap service strings
jtool2 -s <binary> | grep -i bootstrap
strings <binary> | grep -E "^[a-z0-9._-]+$" | grep -v "^[0-9]"
```

### Identify Client vs Server

| Indicator | Client | Server |
|-----------|--------|--------|
| Uses `__NDR_record` | Yes | Yes |
| Calls `__mach_msg` | Yes | Yes |
| Has dispatch table | No | Yes |
| Uses `bootstrap_look_up` | Yes | No |
| Uses `bootstrap_check_in` | No | Yes |
| Has `mach_msg_server` | No | Yes |

## Debugging MIG Communication

Enable MIG debug logging:

```bash
# View MIG kernel debug messages
kdv all | grep MIG

# Or use trace
trace -f <binary>
```

## Example Analysis

### Simple MIG Definition

```c
subsystem myipc 500;

userprefix USERPREF;
serverprefix SERVERPREF;

#include <mach/mach_types.defs>
#include <mach/std_types.defs>

simpleroutine Subtract(
    server_port : mach_port_t;
    n1          : uint32_t;
    n2          : uint32_t);
```

### Generated Server Structure

```c
const struct SERVERPREFmyipc_subsystem SERVERPREFmyipc_subsystem = {
    myipc_server_routine,  // Server routine
    500,                   // start ID
    501,                   // end ID
    sizeof(union __ReplyUnion__),
    0,
    {
        { 0, _XSubtract, 3, 0, 0, sizeof(__Reply__Subtract_t) }
    }
};
```

### Server Implementation Pattern

```c
kern_return_t SERVERPREFSubtract(mach_port_t server_port, uint32_t n1, uint32_t n2)
{
    // Your handler code here
    printf("Received: %d - %d = %d\n", n1, n2, n1 - n2);
    return KERN_SUCCESS;
}

int main() {
    mach_port_t port;
    kern_return_t kr;
    
    // Register with bootstrap
    kr = bootstrap_check_in(bootstrap_port, "com.example.service", &port);
    
    // Start message server
    mach_msg_server(myipc_server, sizeof(union __RequestUnion__), port, MACH_MSG_TIMEOUT_NONE);
}
```

### Client Implementation Pattern

```c
int main() {
    mach_port_t port;
    kern_return_t kr;
    
    // Lookup service
    kr = bootstrap_look_up(bootstrap_port, "com.example.service", &port);
    if (kr != KERN_SUCCESS) {
        printf("Failed to lookup service\n");
        return 1;
    }
    
    // Call RPC
    USERPREFSubtract(port, 40, 2);
}
```

## Tools Reference

### jtool2 Commands

```bash
# Show section symbols
jtool2 -s <binary>

# Dump section data
jtool2 -d <section> <binary>

# Show dependencies
jtool2 -S <binary>

# Disassemble
jtool2 -D <binary>
```

### Finding MIG Examples on System

```bash
# Find .defs files
mdfind "*.defs"

# Find mach_port.defs
mdfind mach_port.defs

# Compile example
mig -DLIBSYSCALL_INTERFACE mach_ports.defs
```

## Common Pitfalls

1. **Message ID offset**: Remember to subtract the subsystem start ID when indexing into the dispatch table
2. **Reply handling**: Only `routine`, `procedure`, and `function` types expect replies
3. **Port management**: First argument is always the server port; MIG handles reply ports automatically
4. **NDR encoding**: Data is encoded for cross-system compatibility via `_NDR_record`
5. **Dispatch table location**: Varies by platform (`__DATA.__const` vs `__CONST.__constdata`)

## Next Steps

For deeper analysis:
1. Use Hopper/IDA to decompile the server routine
2. Extract routine descriptors using the 0x28-byte stride
3. Map each function address to its handler
4. Trace actual IPC calls with `dtrace` or `kdv`
5. Compare against known system services for patterns

## References

- *OS Internals, Volume I, User Mode* - Jonathan Levin
- macOS Mach IPC documentation
- jtool2 GitHub repository
- MIG man page: `man mig`
