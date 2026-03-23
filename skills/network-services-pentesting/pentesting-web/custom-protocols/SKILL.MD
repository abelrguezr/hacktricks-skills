---
name: game-rpc-pentest
description: Analyze and exploit custom UDP RPC protocols in games. Use this skill whenever you need to enumerate proprietary game networking protocols, intercept file-transfer RPCs, perform path traversal attacks on game saves, or turn protocol vulnerabilities into code execution. Trigger this for any game security research involving custom binary protocols, multiplayer save synchronization, or asset manipulation attacks.
---

# Game RPC Protocol Pentesting

A skill for analyzing and exploiting custom UDP RPC protocols in games, particularly those with proprietary networking stacks.

## When to use this skill

Use this skill when:
- You're analyzing a game with custom UDP-based networking
- You need to enumerate RPC methods in a game's networking DLL
- You're investigating file-transfer vulnerabilities in multiplayer games
- You want to perform path traversal attacks on game save systems
- You're researching how to turn protocol vulnerabilities into code execution
- You're doing CTF challenges or security research on game protocols

## Core Workflow

### 1. Map the RPC Surface with Frida

Many games embed home-grown RPC stacks on top of UDP. The goal is to enumerate all remotely reachable methods without traffic captures or symbol leaks.

**Step 1: Identify the networking DLL**
- Look for DLLs with names like `NetComEngine*.dll`, `Network*.dll`, `RPC*.dll`
- Search for exported functions that handle message dispatching
- Look for functions with names like `RMC_CallMessage`, `DispatchMessage`, `HandleRPC`

**Step 2: Find the dispatcher and helper functions**
- The dispatcher typically parses fields like: ID (RPC verb), Flags (transport modifiers), Source (caller object ID), TargetObject (remote object), Method (method index)
- Look for helper functions that translate IDs to strings (e.g., `ClassToMethodName`, `TargetName`)
- These helpers are gold - they let you enumerate the protocol using the game's own reflection

**Step 3: Brute-force the ID space**
- Use the helper functions to enumerate object IDs and method IDs
- Typical ranges: 24-bit object IDs (0x0 to 0x9000000), 16-bit method IDs (0x0 to 0xFFFF)
- Log all valid combinations to build your RPC map

### 2. Subvert File-Transfer RPCs

Multiplayer games often have file-transfer RPCs for save synchronization. These are prime targets for path traversal.

**Common patterns to look for:**
- RPC verbs named `SendFile`, `Upload`, `ShareSave`, `OnSendFile*`, `OnReceivedFile*`
- Two-packet handshakes: Init (with filename) + Data (with contents)
- Serialization helpers like `ByteStreamWriteString()` that handle filenames

**Exploitation approach:**
1. Hook the serialization function that writes filenames
2. Swap the filename pointer to a traversal payload (e.g., `..\..\..\..\target.sww`)
3. Keep packet sizes intact to avoid detection
4. Victim writes to arbitrary path if no sanitization exists

### 3. Turn Path Traversal into Code Execution

Once you can write arbitrary files, you have several options:

**Option A: DLL Search-Order Hijacking**
- Drop a malicious DLL in the game directory
- Next launch loads your DLL before legitimate ones
- Works if game directory is world-writable

**Option B: Asset Archive Overwrite**
- Replace asset archives (RDA, PK3, etc.) with trojanized versions
- Inject malicious 3D models, textures, or scripts
- Exploit unsafe asset processing for RCE

**Option C: Allocator Callback Hijacking**
- If ASLR is disabled and DEP is off
- Replace malloc/free function pointers in vulnerable DLLs
- Redirect allocations to your shellcode

## Scripts

### Surface Enumerator

Use `scripts/enumerate-rpc-surface.js` to brute-force RPC methods:

```bash
frida -l scripts/enumerate-rpc-surface.js <game-exe>
```

This script:
- Hooks `ClassToMethodName` and `TargetName` exports
- Brute-forces object IDs and method IDs
- Logs all valid RPC combinations
- Output format: `object_id = ClassName, method_id = MethodName`

### Filename Swapper

Use `scripts/swap-filename.js` to inject path traversal payloads:

```bash
frida -l scripts/swap-filename.js <game-exe>
```

This script:
- Hooks the string serialization function
- Detects target filenames (configurable)
- Swaps to traversal payload while preserving packet size
- Works with UTF-16 encoded filenames

## Tips

- **Use the engine's own logging** - Don't reimplement string encodings; use the game's `WString::Format` or similar helpers
- **Dump Flags first** - Identify reliability features (ACK, resend) before fuzzing; custom UDP stacks often drop malformed packets silently
- **Store your RPC map** - It serves as a fuzzing corpus and reveals which objects manipulate filesystem, world state, or scripting
- **Check ACLs** - Use `icacls` to confirm if game directory is world-writable before attempting file drops
- **Try all separators** - Brute-force `..\`, `../`, mixed sequences; many stacks forget to canonicalize
- **Look for length checks** - Even if filenames are length-checked, traversal often bypasses them

## Defense Considerations

When analyzing targets:
- Look for RPC verbs with file-related names
- Intercept serialization helpers for filenames or directories
- Check if receivers canonicalize paths before writing
- Verify ACLs on game installation directories
- Look for unsafe relocation processing in asset loaders

## References

- [Synacktiv – Exploiting Anno 1404](https://www.synacktiv.com/publications/exploiting-anno-1404.html)
- [RDA File Format notes](https://github.com/lysanntranvouez/RDAExplorer/wiki/RDA-File-Format)
- [Frida Documentation](https://frida.re/docs/)

## Common Targets

This technique applies to:
- Older multiplayer games with custom UDP stacks
- Games with save synchronization features
- Titles using binary asset archives (RDA, PK3, etc.)
- Games with disabled ASLR/DEP
- Any protocol with internal reflection helpers exposed as exports
