---
name: macos-ipc-analysis
description: Analyze macOS Mach IPC communications, port rights, task ports, and inter-process communication mechanisms. Use this skill whenever the user needs to understand Mach ports, debug IPC messages, analyze port permissions, work with task/thread ports, investigate code injection via task ports, or understand macOS IPC internals for security research, debugging, or privilege escalation analysis. Trigger on any mention of Mach ports, IPC, task_for_pid, bootstrap server, port rights, or macOS inter-process communication.
---

# macOS IPC Analysis

A skill for analyzing and working with macOS Mach Inter-Process Communication (IPC) mechanisms, including ports, rights, task ports, and related security implications.

## When to Use This Skill

Use this skill when you need to:
- Understand Mach port concepts and IPC mechanisms on macOS
- Debug or analyze Mach message communications
- Investigate port rights and permissions
- Work with task ports, thread ports, or special ports
- Analyze code injection techniques via task ports
- Understand bootstrap server and service registration
- Investigate privilege escalation via IPC mechanisms
- Debug XPC or MIG-based communications

## Core Concepts

### Mach Ports Overview

Mach uses **tasks** as the smallest unit for sharing resources. Each task maps 1:1 to POSIX processes and can contain multiple threads.

**Key concepts:**
- **Ports**: Basic IPC elements acting as message queues managed by the kernel
- **IPC Table**: Each process has an IPC table containing its Mach ports
- **Port Names**: Numbers (pointers to kernel objects)
- **Communication**: One-way channels between ports

### Port Rights

Port rights define what operations a task can perform:

| Right | Description | Clonable |
|-------|-------------|----------|
| **Receive** | Receive messages; can create Send rights | No (single per port) |
| **Send** | Send messages to the port | Yes |
| **Send-once** | Send one message, then disappears | No |
| **Port set** | Listen on multiple ports simultaneously | N/A |
| **Dead name** | Placeholder when port is destroyed | N/A |

**Important:**
- Receive rights are MPSC (multiple-producer, single-consumer)
- Send rights can be cloned and transferred to other tasks
- Port rights can be passed through Mach messages
- If the Receive right owner dies, Send rights become dead names

### Bootstrap Server

The bootstrap server (launchd on macOS) enables initial communication:

1. **Task A** creates a port with RECEIVE right
2. Task A generates a SEND right for the port
3. Task A sends the SEND right to the bootstrap server
4. Task A registers the port with a name (e.g., `com.apple.taska`)
5. **Task B** looks up the service name via bootstrap server
6. Bootstrap server duplicates Task A's SEND right and sends to Task B
7. Task B can now send messages to Task A

**Security note:** The bootstrap server cannot authenticate service names claimed by tasks. System services are protected via SIP-protected directories (`/System/Library/LaunchDaemons`, `/System/Library/LaunchAgents`).

## Port Enumeration and Analysis

### Using lsmp

```bash
# List ports for a specific process
lsmp -p <pid>

# List ports for launchd (requires sudo)
sudo lsmp -p 1
```

**Output columns:**
- `name`: Default port name (increasing in first 3 bytes)
- `ipc-object`: Obfuscated unique identifier
- `rights`: Port rights (send, recv, send+recv)
- `+`: Indicates other tasks connected to the same port

### Using procexp

```bash
# List all host special ports
procexp all ports | grep "HSP"

# List ports for a specific process (requires SIP disabled for some info)
procexp 1 ports
```

## Task Ports

Task ports are critical for process control and memory manipulation.

### Key Functions

| Function | Purpose |
|----------|--------|
| `task_for_pid(target, pid, &task_port)` | Get SEND right for task of specified PID |
| `pid_for_task(task, &pid)` | Get PID from task port |
| `mach_task_self()` | Get task port for current task |

### Task Port Capabilities

With SEND right over a task port, you can:
- `task_threads`: Get SEND rights to all threads
- `task_info`: Get task information
- `task_suspend/resume`: Control task execution
- `vm_read/vm_write`: Read/write task memory
- `thread_create`: Create new threads
- `task_get/set_state`: Control task state

**Security implications:**
- SEND right over another task's port enables code injection
- `task_for_pid` requires specific entitlements or root
- `com.apple.security.get-task-allow`: Same-user access (debugging)
- `com.apple.system-task-ports`: Any process access (Apple binaries only)
- Root can access non-hardened runtime applications

### Task Port Restrictions

| Entitlement | Access Level |
|-------------|-------------|
| `com.apple.security.get-task-allow` | Same user processes |
| `com.apple.system-task-ports` | Any process (except kernel) |
| Root | Non-hardened runtime apps |

## Thread Ports

Threads have associated ports visible via `task_threads`.

### Thread Port Capabilities

With SEND right over a thread port:
- `thread_terminate`: Terminate the thread
- `thread_get/set_state`: Control thread state
- `thread_suspend/resume`: Pause/resume execution
- `thread_info`: Get thread information

### Getting Thread Port

```c
mach_thread_self()  // Get thread port for current thread
```

## Mach Message Structure

### Message Header

```c
typedef struct {
    mach_msg_bits_t               msgh_bits;      // Bitmap flags
    mach_msg_size_t               msgh_size;      // Total packet size
    mach_port_t                   msgh_remote_port;  // Destination port
    mach_port_t                   msgh_local_port;   // Reply port
    mach_port_name_t              msgh_voucher_port; // Voucher port
    mach_msg_id_t                 msgh_id;        // Message ID
} mach_msg_header_t;
```

### msgh_bits Bitmap

| Byte | Bits | Purpose |
|------|------|--------|
| 1st | Bit 0 | Complex message flag |
| 1st | Bits 1-2 | Kernel use |
| 2nd | Bits 0-4 | Voucher port type |
| 3rd | Bits 0-4 | Local port type |
| 4th | Bits 0-4 | Remote port type |

### Port Type Constants

```c
#define MACH_MSG_TYPE_MOVE_RECEIVE      16
#define MACH_MSG_TYPE_MOVE_SEND         17
#define MACH_MSG_TYPE_MOVE_SEND_ONCE    18
#define MACH_MSG_TYPE_COPY_SEND         19
#define MACH_MSG_TYPE_MAKE_SEND         20
#define MACH_MSG_TYPE_MAKE_SEND_ONCE    21
#define MACH_MSG_TYPE_DISPOSE_RECEIVE   24
#define MACH_MSG_TYPE_DISPOSE_SEND      25
#define MACH_MSG_TYPE_DISPOSE_SEND_ONCE 26
```

## Debugging Mach Messages

### Setting Breakpoints

```bash
# In lldb
(lldb) b mach_msg
(lldb) r
```

### Inspecting Arguments

```bash
# Read registers (ARM64 calling convention)
(lldb) reg read $x0 $x1 $x2 $x3 $x4 $x5 $x6

# Inspect message header
(lldb) x/6w $x0
```

**Register mapping:**
- `$x0`: `mach_msg_header_t *msg`
- `$x1`: `mach_msg_option_t option`
- `$x2`: `mach_msg_size_t send_size`
- `$x3`: `mach_msg_size_t rcv_size`
- `$x4`: `mach_port_name_t rcv_name`
- `$x5`: `mach_msg_timeout_t timeout`
- `$x6`: `mach_port_name_t notify`

## Special Ports

### Host Special Ports

| Port | Number | Owner | Purpose |
|------|--------|-------|--------|
| HOST_PORT | 1 | Kernel | System information |
| HOST_PRIV_PORT | 2 | Kernel | Privileged actions |
| HOST_IO_MASTER_PORT | 3 | Kernel | I/O master |
| HOST_MAX_SPECIAL_KERNEL_PORT | 7 | Kernel | Max kernel port |
| 8+ | 8+ | System daemons | Various services |

**Access:**
- `host_get_special_port`: Get SEND rights (requires host_priv)
- `host_set_special_port`: Set RECEIVE rights (requires host_priv)

### Task Special Ports

```c
#define TASK_KERNEL_PORT        1   // Task control port
#define TASK_HOST_PORT          2   // Host port for task
#define TASK_BOOTSTRAP_PORT     4   // Bootstrap environment
#define TASK_WIRED_LEDGER_PORT  5   // Wired memory ledger
#define TASK_PAGED_LEDGER_PORT  6   // Paged memory ledger
```

## Code Injection Techniques

### Shellcode Injection via Task Port

**Requirements:**
- SEND right to target task port (via `task_for_pid`)
- Target process with `com.apple.security.get-task-allow` entitlement (same user)
- Or root access to non-hardened runtime apps

**Steps:**
1. Get task port via `task_for_pid(mach_task_self(), pid, &remoteTask)`
2. Allocate memory: `mach_vm_allocate(remoteTask, &address, size, VM_FLAGS_ANYWHERE)`
3. Write shellcode: `mach_vm_write(remoteTask, address, shellcode, length)`
4. Set permissions: `vm_protect(remoteTask, address, size, FALSE, VM_PROT_READ | VM_PROT_EXECUTE)`
5. Create thread: `thread_create_running(remoteTask, ARM_THREAD_STATE64, &state, count, &thread)`

### Dylib Injection via Task Port

For POSIX-compliant injections:
1. Inject shellcode that calls `pthread_create_from_mach_thread`
2. The new pthread can call `dlopen` to load custom libraries
3. This enables more complex injections using system APIs

### Thread Hijacking

Instead of creating new threads, hijack existing threads:
1. Get task port and enumerate threads via `task_threads`
2. Suspend target thread: `thread_suspend(thread_port)`
3. Modify thread state (PC, SP) to point to injected code
4. Resume thread: `thread_resume(thread_port)`

## Detection and Evasion

### Task Port Injection Detection

The kernel increments a counter in the task struct when:
- `task_for_pid` is called
- `thread_create_*` is called

**Detection:**
```c
task_info(task, TASK_EXTMOD_INFO, ...)
```

### Exception Ports

Exception triage flow:
1. Thread exception port
2. Task exception ports
3. Host port (launchd)
4. ReportCrash daemon

**Note:** Crash reporting tools like `PLCrashReporter` handle exceptions within the same task.

## Common APIs Reference

### Port Management

| API | Purpose |
|-----|--------|
| `mach_port_allocate` | Create a port |
| `mach_port_construct` | Create a port (alternative) |
| `mach_port_allocate_name` | Change port name |
| `mach_port_names` | Get port names from target |
| `mach_port_type` | Get rights over a name |
| `mach_port_rename` | Rename a port |
| `mach_port_insert_right` | Create new right in port |

### Message Operations

| API | Purpose |
|-----|--------|
| `mach_msg` | Send/receive messages |
| `mach_msg_overwrite` | Send/receive with different receive buffer |

### Complex Messages

For messages with port rights or shared memory:
- Set MSB of `msgh_bits`
- Use descriptors: `MACH_MSG_PORT_DESCRIPTOR`, `MACH_MSG_OOL_DESCRIPTOR`, etc.
- Kernel copies descriptors to kernel memory first (Feng Shui technique)

## Security Considerations

### Privilege Escalation Vectors

1. **Task port access**: SEND right enables full process control
2. **Exception port hijacking**: Handle exceptions to gain control
3. **Bootstrap impersonation**: Register fake service names (non-system tasks)
4. **Port right transfer**: Send rights to vulnerable processes

### Mitigations

- **SIP (System Integrity Protection)**: Protects system directories and ports
- **Hardened Runtime**: Restricts task port access
- **Entitlements**: Control access to sensitive APIs
- **Code Signing**: Validates binary authenticity

## Practical Examples

### Basic Port Communication

See the `scripts/` directory for working examples:
- `receiver.c`: Register a port and receive messages
- `sender.c`: Look up a port and send messages

### Enumerating System Ports

```bash
# List all ports for launchd
sudo lsmp -p 1

# Find host special ports
procexp all ports | grep "HSP"

# Check specific process ports
lsmp -p <pid>
```

### Debugging IPC

```bash
# Start lldb with target application
lldb /path/to/app

# Set breakpoint on mach_msg
(lldb) b mach_msg

# Run and inspect
(lldb) r
(lldb) reg read $x0 $x1 $x2 $x3 $x4 $x5 $x6
(lldb) x/6w $x0
```

## Related Topics

- **XPC**: Higher-level IPC framework (see `macos-xpc` skill)
- **MIG**: Mach Interface Generator for RPC code generation
- **Sandbox**: macOS sandboxing and entitlements
- **Code Signing**: Binary signing and verification

## References

- [Darling Mach Ports Documentation](https://docs.darlinghq.org/internals/macos-specifics/mach-ports.html)
- [Apple XNU Source - mach/message.h](https://opensource.apple.com/source/xnu/xnu-7195.81.3/osfmk/mach/message.h.auto.html)
- [Apple XNU Source - host_special_ports.h](https://opensource.apple.com/source/xnu/xnu-4570.1.46/osfmk/mach/host_special_ports.h.auto.html)
- [*OS Internals, Volume I, User Mode* by Jonathan Levin
- [Project Zero - Sound Barrier 2](https://projectzero.google/2026/01/sound-barrier-2.html)
- [Sector7 - XPC Audit Token Spoofing](https://sector7.computest.nl/post/2023-10-xpc-audit-token-spoofing/)
