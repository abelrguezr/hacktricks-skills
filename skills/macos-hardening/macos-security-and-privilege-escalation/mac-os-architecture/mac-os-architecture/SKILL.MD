---
name: macos-kernel-architecture
description: macOS kernel and system architecture reference for security research. Use this skill whenever the user asks about XNU kernel internals, Mach/BSD architecture, coprocessors (SEP, SMC, T2, ANE, etc.), kernel extensions, system extensions, cryptexes, RSR updates, or macOS attack surfaces. Trigger for questions about macOS security mechanisms, privilege escalation vectors, firmware security, or when analyzing macOS system internals.
---

# macOS Kernel & System Architecture Reference

This skill provides comprehensive information about macOS kernel architecture, security mechanisms, and attack surfaces for security research and system analysis.

## XNU Kernel Overview

**XNU** ("X is Not Unix") is the core kernel of macOS, combining:
- **Mach microkernel** - handles low-level operations
- **BSD components** - Unix-compatible system services
- **I/O Kit** - device driver framework

The XNU kernel is part of the Darwin open source project. Source code is available at: https://opensource.apple.com/source/xnu/

### Mach Microkernel

Mach is designed to minimize kernel-space code, running many functions as user-level tasks.

**Mach responsibilities:**
- Processor scheduling
- Multitasking
- Virtual memory management
- Low-level IPC (Inter-Process Communication)

**Key concept:** Mach operates based on threads, not processes.

### BSD Components

FreeBSD-derived code runs in the same address space as Mach, providing:

- Process management
- Signal handling
- User/group management and basic security
- System call infrastructure
- TCP/IP stack and sockets
- Firewall and packet filtering

**Important interaction:** Each BSD process associates with a Mach task containing exactly one Mach thread. When `fork()` is called, BSD code uses Mach functions to create task and thread structures.

**Security model differences:**
- Mach: port rights-based security
- BSD: process ownership-based security

These disparities have historically led to local privilege-escalation vulnerabilities.

### I/O Kit - Device Drivers

The I/O Kit is an open-source, object-oriented device-driver framework that:
- Handles dynamically loaded device drivers
- Allows modular code to be added to the kernel on-the-fly
- Supports diverse hardware

## Coprocessors in macOS

Apple platforms use coprocessors to isolate security-critical functions and reduce latency on main cores.

### Secure Enclave Processor (SEP)

- **Architecture:** Dedicated ARM core with own microkernel, runs at EL3/secure world
- **Communication:** Mailbox drivers in macOS at EL1
- **Attack surface:**
  - SEP firmware updates
  - User-space daemons (`seputil`, `securityd`) that proxy requests
- **Impact of compromise:**
  - Leak long-term keys
  - Bypass biometric gating
  - Break FileVault or Apple Pay protections

### System Management Controller (SMC)

- **Architecture:** Proprietary firmware on microcontroller outside ARM exception levels
- **Communication:** I/O Kit user clients from macOS (EL1)
- **Attack surface:**
  - USB-C power delivery messages
  - Fan/battery management interfaces
  - Firmware update paths
- **Impact of compromise:**
  - Override thermal limits
  - Inject fake sensor data
  - Cut power
  - Implant persistent NVRAM backdoors

### T1/T2 Security Chips

- **Architecture:** Runs bridgeOS (watchOS-derived) at EL1/EL3 on dedicated ARM cores
- **Communication:** PCIe/USB-like channels mediated by IOKit
- **Attack surface:**
  - DFU/restore pathways
  - IPC endpoints exposed by services like `tccd`
  - Media pipelines bridged to T2
- **Impact of compromise:**
  - Disable secure boot
  - Decrypt SSD contents
  - Hijack camera/mic gating
  - Emulate HID input for stealth persistence

### Display Coprocessor (DCP)

- **Architecture:** Firmware at EL1 in isolated address space protected by DART (Apple's IOMMU)
- **Attack surface:**
  - `DCPAVService` interfaces
  - Shared descriptor buffers
  - Firmware image parsing
- **Impact of compromise:**
  - Inject arbitrary frames
  - Snoop framebuffers
  - Brick display pipeline for DoS

### Apple Neural Engine (ANE)

- **Architecture:** Microcode on dedicated ML cluster (no ARM EL levels)
- **Communication:** `ANECompilerService` and IOKit
- **Attack surface:**
  - Compiled model binaries (`.ane`)
  - Core ML APIs feeding custom kernels
  - Firmware loaders
- **Impact of compromise:**
  - Tamper or exfiltrate ML models
  - Leak processed audio/vision data
  - Sabotage on-device inference

### AGX GPU

- **Architecture:** Firmware on custom GPU cores with scheduler; EL0 submits Metal commands validated at EL1
- **Attack surface:**
  - Metal shader compiler
  - Shared buffer mapping APIs
  - `com.apple.AGXFirmware` ioctl interfaces
- **Impact of compromise:**
  - DMA access to system memory
  - Sandbox escapes via GPU drivers
  - Persistent firmware implants

### Apple Video Encoder (AVE)

- **Architecture:** Firmware on Media Engine in EL1-like sandbox
- **Communication:** VideoToolbox and `AppleAVE2`
- **Attack surface:**
  - Codec bitstreams
  - Parameter sets
  - User-supplied buffers
  - Firmware update blobs
- **Impact of compromise:**
  - Leak uncompressed frames
  - Bypass DRM
  - Code execution with DMA engine access

### Image Signal Processor (ISP)

- **Architecture:** Secure firmware in Media Engine cluster; camera drivers at EL1
- **Attack surface:**
  - Camera HALs
  - RAW frame descriptors
  - ISP configuration queues
  - Firmware updates
- **Impact of compromise:**
  - Capture raw camera feeds silently
  - Disable privacy indicators
  - Inject fabricated imagery

### AMX Matrix Cores

- **Architecture:** Coprocessor units exposed at EL0/EL1 via new instructions
- **Attack surface:**
  - Kernel virtualization of AMX state (`thread_set_state`, context switches)
  - User-space code generation
- **Impact of compromise:**
  - Leak other processes' tile registers
  - Fingerprint workloads
  - Escalate via kernel memory corruption

**Chain of Trust:** Modern macOS treats these coprocessors as trusted components. Firmware for SEP, SMC, and T2 is signed by Apple. Handshake protocols (often over mailboxes or I/O Kit families) include challenge-response checks for authenticated firmware.

## Kernel Extensions vs System Extensions

### Kernel Extensions (.kext)

macOS is **highly restrictive** about loading kernel extensions due to the high privileges they run with. By default, loading .kext files is virtually impossible unless a bypass is found.

### System Extensions

Instead of kernel extensions, macOS uses **System Extensions** which:
- Offer user-level APIs to interact with the kernel
- Allow developers to avoid kernel extensions
- Provide safer, more restricted access to kernel functionality

## Cryptexes & Rapid Security Response (RSR)

### Cryptex (CRYPTographically-sealed EXtension)

A sealed disk image container used by Apple to host OS components that change frequently between major updates.

**Key characteristics:**
- Resides on the **Preboot volume** alongside boot firmware
- Grafted into the OS filesystem at runtime
- Loading involves validation: file seals, manifests, and root hashes
- In boot logs, cryptex loading occurs after kernel initialization but before full system services

### Rapid Security Response (RSR)

Apple's mechanism for delivering security patches between regular OS updates.

**How RSR works:**
1. Targets cryptex content to update vulnerable parts (libraries, frameworks) without touching the core system volume
2. Device requests a **Cryptex1 Image4 manifest** from Apple's signing server
3. Manifest is cryptographically bound to the device and new cryptex content
4. Existing AP boot ticket for base system is **not modified** - patch works additively
5. On macOS, patched components (e.g., Safari) become active when the app relaunches; full restart not always required

**RSR properties:**
- **Removable:** Each ships both a patch and "antipatch" for rollback
- **Smaller:** Much smaller than full OS updates
- **Lower requirements:** Requires lower battery state to install

## Research Workflow

When investigating macOS kernel or system architecture:

1. **Identify the component** - Determine which part of the architecture is relevant (kernel, coprocessor, extension, etc.)
2. **Map the attack surface** - Review the documented attack vectors for that component
3. **Understand the trust model** - Identify what security mechanisms protect the component
4. **Check for known issues** - Research historical vulnerabilities in similar components
5. **Consider the impact** - Evaluate what compromise of this component would enable

## References

- [The Mac Hacker's Handbook](https://www.amazon.com/-/es/Charlie-Miller-ebook-dp-B004U7MUMU/dp/B004U7MUMU/ref=mt_other?_encoding=UTF8&me=&qid=)
- [TAOMM Volume 1 Analysis](https://taomm.org/vol1/analysis.html)
- [XNU Open Source](https://opensource.apple.com/source/xnu/)
