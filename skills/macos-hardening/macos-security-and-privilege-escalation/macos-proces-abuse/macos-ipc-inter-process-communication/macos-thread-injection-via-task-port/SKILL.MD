---
name: macos-thread-injection
description: macOS thread injection and IPC exploitation reference. Use this skill whenever the user asks about macOS security research, privilege escalation, task ports, thread hijacking, Mach IPC, process injection, EndpointSecurity detection, or Apple Silicon (arm64e) exploitation. Trigger for macOS security audits, EDR development, or understanding macOS process isolation bypasses.
---

# macOS Thread Injection via Task Port

A reference guide for macOS thread injection techniques using task ports, including detection and hardening strategies.

## When to Use This Skill

Use this skill when working with:
- macOS security research and privilege escalation
- Thread injection and process manipulation
- Mach IPC and task port exploitation
- EndpointSecurity event monitoring
- Apple Silicon (arm64e) exploitation considerations
- EDR/AV development for macOS
- Security audits of macOS applications

## Core Concepts

### Thread Hijacking

When `task_threads()` is available on a task port, you can hijack existing threads rather than creating new ones (which is blocked by `thread_create_running()` mitigation).

**Key operations on remote threads:**
- `thread_suspend()` - halt execution
- `thread_resume()` - resume execution  
- `thread_get_state()` / `thread_set_state()` - read/modify registers

**Remote function call pattern:**
1. Set registers `x0`-`x7` to function arguments
2. Set `pc` to target function address
3. Resume thread
4. Detect return (via exception handler or loop monitoring)

**Return value detection strategies:**
- **Exception handler**: Set `lr` to invalid address, register exception port via `thread_set_exception_ports()`
- **Loop monitoring**: Set `lr` to infinite loop, poll registers until `pc` hits loop instruction

### Mach Port Communication

Establish bidirectional communication between local and remote tasks:

**Local port setup:**
```c
// Create receive right in local task
mach_port_allocate(MACH_PORT_RIGHT_RECEIVE, &local_port)

// Transfer send right to remote via THREAD_KERNEL_PORT
thread_set_special_port(remote_thread, THREAD_KERNEL_PORT, local_port)

// Remote thread calls mach_thread_self() to retrieve send right
```

**Remote port setup:**
```c
// Remote thread creates port via mach_reply_port()
mach_port_insert_right() to establish send right
thread_set_special_port() to stash in kernel

// Local task retrieves via thread_get_special_port()
```

### Memory Read/Write Primitives

**Reading memory** - use `property_getName()` from libobjc:
```c
const char *property_getName(objc_property_t prop) {
    return prop->name;  // ldr x0, [x0]; ret
}
```

**Writing memory** - use `_xpc_int64_set_value()` from libxpc:
```c
// Writes x1 to [x0 + 0x18]
// For arbitrary 64-bit write at address:
_xpc_int64_set_value(address - 0x18, value)
```

### Shared Memory Setup

Use `OS_xpc_shmem` objects for efficient data transfer:

1. **Allocate** memory via `mach_vm_allocate()`
2. **Create** `OS_xpc_shmem` object via `xpc_shmem_create()`
3. **Copy** template to remote process (fix Mach send right at offset 0x18)
4. **Insert** send right via `thread_set_special_port()`
5. **Map** with remote `xpc_shmem_remote()` call

### Full Control Capabilities

Once you have arbitrary execution + shared memory:
- **Memory R/W**: `memcpy()` between local and shared regions
- **Multi-argument calls**: Stack arguments per ARM64 calling convention
- **Mach port transfer**: Pass rights via established ports
- **File descriptor transfer**: Use fileports (see triple_fetch)

## Apple Silicon (arm64e) Considerations

**Pointer Authentication Codes (PAC)** protect return addresses and function pointers.

**Safe approaches:**
- Reuse existing code (original `lr`/`pc` values have valid PAC)
- Chain existing gadgets/functions (ROP)

**For attacker-controlled memory:**
```c
// 1. Allocate executable memory in target
mach_vm_allocate() + mprotect(PROT_EXEC)

// 2. Copy payload

// 3. Sign pointer INSIDE remote process
uint64_t ptr = (uint64_t)payload;
ptr = ptrauth_sign_unauthenticated((void*)ptr, ptrauth_key_asia, 0);

// 4. Set pc = ptr in hijacked thread state
```

## Detection and Hardening

### EndpointSecurity Events

Monitor these events for thread injection detection:

| Event | Trigger |
|-------|--------|
| `ES_EVENT_TYPE_AUTH_GET_TASK` | Task port request (e.g., `task_for_pid()`) |
| `ES_EVENT_TYPE_NOTIFY_REMOTE_THREAD_CREATE` | Thread created in different task |
| `ES_EVENT_TYPE_NOTIFY_THREAD_SET_STATE` | Register manipulation (macOS 14+) |

**Swift detection client:**
```swift
import EndpointSecurity

let client = try! ESClient(subscriptions: [.notifyRemoteThreadCreate]) { _, msg in
    if let evt = msg.remoteThreadCreate {
        print("[ALERT] remote thread in pid \(evt.target.pid) by pid \(evt.thread.pid)")
    }
}
RunLoop.main.run()
```

**osquery query (≥ 5.8):**
```sql
SELECT target_pid, source_pid, target_path
FROM es_process_events
WHERE event_type = 'REMOTE_THREAD_CREATE';
```

### Hardening Recommendations

1. **Remove `com.apple.security.get-task-allow` entitlement** - prevents non-root task port access
2. **Enable Hardened Runtime** - adds additional protections
3. **Monitor EndpointSecurity events** - detect injection attempts
4. **Code signing** - verify integrity of loaded code
5. **SIP awareness** - System Integrity Protection blocks many Apple binaries

## Tooling Reference

| Tool | Year | Purpose |
|------|------|--------|
| [threadexec](https://github.com/bazad/threadexec) | 2018 | Thread injection library |
| [task_vaccine](https://github.com/rodionovd/task_vaccine) | 2023 | PAC-aware thread hijacking PoC |
| `remote_thread_es` | 2024 | EndpointSecurity helper for EDR vendors |

## Key References

- [Bypassing platform binary task_threads](https://bazad.github.io/2018/10/bypassing-platform-binary-task-threads/)
- [Apple EndpointSecurity Documentation](https://developer.apple.com/documentation/endpointsecurity)
- [task_vaccine source](https://github.com/rodionovd/task_vaccine)

## Important Notes

- **macOS 13/14+**: API changes affect compatibility - review recent tooling source code
- **Intel vs Apple Silicon**: Different exploitation paths due to PAC on arm64e
- **Legal**: Only use on systems you own or have explicit authorization to test
- **Defensive focus**: Understanding these techniques helps build better EDR and hardening
