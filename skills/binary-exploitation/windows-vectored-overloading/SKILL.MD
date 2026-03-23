---
name: vectored-overloading-pe-injection
description: Windows PE injection technique using Vectored Exception Handlers (VEHs) and hardware breakpoints to disguise malicious code as legitimate DLLs. Use this skill when analyzing or implementing Vectored Overloading attacks, investigating VEH-based evasion techniques, understanding how attackers bypass kernel-level telemetry by hijacking the Windows loader, or when you need to detect this technique in security tools. Trigger this skill for any questions about VEH injection, hardware breakpoint exploitation, module overloading, or Windows loader manipulation.
---

# Vectored Overloading PE Injection

A Windows PE injection primitive that fuses classic Module Overloading with Vectored Exception Handlers (VEHs) and hardware breakpoints to disguise malicious code as legitimate DLLs while bypassing kernel-level telemetry.

## Technique Overview

Instead of patching `LoadLibrary` or writing a custom loader, this technique:

1. Creates a `SEC_IMAGE` section backed by a legitimate DLL (e.g., `wmp.dll`)
2. Overwrites the mapped view with a fully relocated malicious PE while keeping the section object pointing to the benign image on disk
3. Registers a VEH and programs debug registers so every call to `NtOpenSection`, `NtMapViewOfSection`, and optionally `NtClose` raises a user-mode breakpoint
4. Calls `LoadLibrary("amsi.dll")` (or any other benign target). When the Windows loader invokes those syscalls, the VEH **skips the kernel transition** and returns the handles and base addresses of the prepared malicious image

**Key advantage**: Tooling that only looks at section backing files sees the legitimate DLL (e.g., `wmp.dll`) even though memory contains the attacker's payload. Imports/TLS callbacks are still resolved by the genuine loader, reducing custom PE-parsing logic.

## Stage 1 – Build the Disguised Section

### Step 1: Create and map a section for the decoy DLL

```c
HANDLE DecoySection;
PVOID DecoyView;
SIZE_T DecoySize;

NtCreateSection(&DecoySection, SECTION_ALL_ACCESS, NULL,
                NULL, 0, PAGE_READWRITE, SEC_IMAGE, L"\\??\\C:\\Windows\\System32\\wmp.dll");
NtMapViewOfSection(DecoySection, GetCurrentProcess(), &DecoyView, 0, 0,
                   NULL, &DecoySize, ViewShare, 0, PAGE_READWRITE);
```

### Step 2: Copy the malicious PE into that view

Copy section by section, honoring `SizeOfRawData`/`VirtualSize` and updating protections afterwards (`PAGE_EXECUTE_READ`, `PAGE_READWRITE`, etc.).

### Step 3: Apply relocations and resolve imports

Apply relocations and resolve imports exactly as a reflective loader would. Because the view is already mapped as `SEC_IMAGE`, section alignments and guard pages match what the Windows loader expects later.

### Step 4: Normalize the PE header

- If the payload is an EXE, set `IMAGE_FILE_HEADER.Characteristics |= IMAGE_FILE_DLL` and zero the entry point to keep `LdrpCallTlsInitializers` from jumping into EXE-specific stubs
- DLL payloads can keep their headers unchanged

**Result**: The process owns a RWX-capable view whose backing object is still `wmp.dll`, yet the bytes in memory are attacker-controlled.

## Stage 2 – Hijack the Loader with VEHs

### Step 1: Register a VEH and arm hardware breakpoints

Program `Dr0` (or another debug register) with the address of `ntdll!NtOpenSection` and set `DR7` so every execution raises `STATUS_SINGLE_STEP`. Repeat later for `NtMapViewOfSection` and optionally `NtClose`.

Minimal HWBP setup (x64):

```c
CONTEXT ctx = {0};
ctx.ContextFlags = CONTEXT_DEBUG_REGISTERS;
GetThreadContext(GetCurrentThread(), &ctx);
ctx.Dr0 = (DWORD64)NtOpenSection;
ctx.Dr7 = 1;  // Enable breakpoint on Dr0
SetThreadContext(GetCurrentThread(), &ctx);
AddVectoredExceptionHandler(1, VehHandler);
```

### Step 2: Trigger DLL loading

Call `LoadLibrary("amsi.dll")`. `LdrLoadDll` will eventually call `NtOpenSection` to obtain the real section handle.

### Step 3: VEH hook for `NtOpenSection`

```c
LONG WINAPI VehHandler(EXCEPTION_POINTERS* ExceptionInfo) {
    if (ExceptionInfo->ExceptionRecord->ExceptionCode == EXCEPTION_SINGLE_STEP) {
        // Locate the stack slot for the [out] PHANDLE SectionHandle argument
        // Write the previously created DecoySection handle into that slot
        // Advance RIP/EIP to the ret instruction so the kernel is never called
        // Re-arm the hardware breakpoint to watch NtMapViewOfSection next
        return EXCEPTION_CONTINUE_EXECUTION;
    }
    return EXCEPTION_CONTINUE_SEARCH;
}
```

### Step 4: VEH hook for `NtMapViewOfSection`

- Overwrite the `[out] PVOID *BaseAddress` (and size/protection outputs) with the address of the already mapped malicious view
- Skip the syscall body just like before

### Step 5: (Optional) VEH hook for `NtClose`

Verify that the fake section handle is cleaned up, preventing resource leaks and providing a final sanity check.

**Why this works**: Because the syscalls are never executed, kernel callbacks (ETWti, minifilter, etc.) do not observe the suspicious `NtOpenSection`/`NtMapViewOfSection` events, drastically lowering telemetry. From the loader's point of view everything succeeded and `amsi.dll` is in memory, so it proceeds with import/TLS resolution against the attacker's bytes.

## Implementation Notes

### Hardware Breakpoints are Per-Thread

The VEH must run on the same thread that triggers the loader. Set `CONTEXT_DEBUG_REGISTERS` on the **current thread** before calling `LoadLibrary`.

### Syscall Emulation

The VEH sets `RAX = 0` and advances `RIP` to the `ret` inside the `ntdll` stub (scan for `0xC3`) so the kernel transition never happens, then resumes with `NtContinue`.

### Output Parameters

For `NtMapViewOfSection`, the VEH overwrites the returned `BaseAddress`, `ViewSize`, and `Win32Protect` outputs so the loader believes the mapping succeeded and continues with imports/TLS using the attacker's view.

## Stealth Variation

Recent VEH research highlights that handlers can be registered by **manually manipulating the VEH list** instead of calling `AddVectoredExceptionHandler`, which reduces reliance on user-mode APIs that may be monitored or hooked. This is not required for Vectored Overloading but can be combined with it to reduce observable API activity.

## Stage 3 – Execute the Payload

### EXE Payload

The injector simply jumps to the original entry point once relocations are done. When the loader thinks it would call `DllMain`, the custom code instead executes the EXE-style entry.

### DLL Payload / Node.js Addon

Resolve and call the intended export. Because the module is already registered with `LdrpModuleBaseAddressIndex`, subsequent lookups see it as the benign DLL.

When combined with a Node.js native addon (`.node` file), all of the Windows-internals heavy lifting stays outside the JavaScript layer.

## Detection Considerations

### Indicators to Monitor

1. **Hardware breakpoint usage**: Monitor `SetThreadContext` calls with `CONTEXT_DEBUG_REGISTERS`
2. **VEH registration**: Track `AddVectoredExceptionHandler` calls, especially before `LoadLibrary`
3. **Section mapping anomalies**: `NtMapViewOfSection` returning addresses that don't match expected DLL bases
4. **Syscall skipping**: Unusual patterns where syscalls appear to complete without kernel transitions
5. **PE header modifications**: EXE files with `IMAGE_FILE_DLL` characteristics set

### Evasion Challenges

- Manual VEH list manipulation can hide handler registration
- Hardware breakpoints are per-thread, making them harder to detect globally
- The technique uses legitimate Windows APIs, making behavioral detection difficult

## References

- [Check Point Research – GachiLoader: Defeating Node.js Malware with API Tracing](https://research.checkpoint.com/2025/gachiloader-node-js-malware-with-api-tracing/)
- [VectoredOverloading – PoC implementation](https://github.com/CheckPointSW/VectoredOverloading)
- [IBM X-Force – You just got vectored: Using VEH for defense evasion and process injection](https://www.ibm.com/think/x-force/using-veh-for-defense-evasion-process-injection)
- [Module Overloading](https://github.com/hasherezade/module_overloading)

## Safety Notice

This technique is for **security research and defensive purposes only**. Use only in controlled environments with proper authorization. Unauthorized use of injection techniques may violate laws and terms of service.
