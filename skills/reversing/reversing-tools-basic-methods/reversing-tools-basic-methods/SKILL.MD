---
name: reversing-tools-basic-methods
description: Use this skill for reverse engineering tasks including decompiling binaries, debugging shellcode, analyzing .NET/Java/Golang/Delphi/Rust applications, working with Wasm, GBA games, and using tools like IDA, x64dbg, dnSpy, Cutter, and scdbg. Trigger this skill whenever the user mentions reverse engineering, decompiling, debugging binaries, analyzing shellcode, or working with compiled code from any language or platform.
---

# Reversing Tools & Basic Methods

This skill provides guidance on reverse engineering tools and methodologies for various platforms, languages, and binary formats.

## Quick Reference by Target Type

| Target | Primary Tools |
|--------|---------------|
| .NET assemblies | dnSpy, ILSpy, dotPeek |
| Java | JADX, JD-GUI |
| Shellcode | Blobrunner, jmp2it, scdbg, Cutter |
| Wasm | wabt, wasmdec, Jeb |
| GBA games | no$gba, mgba, GhidraGBA |
| Delphi | IDR, IDA-For-Delphi |
| Golang | IDAGolangHelper |
| Obfuscated (movfuscator) | demovfuscator |

## .NET Decompilation & Debugging

### Tool Selection

- **dotPeek** (JetBrains): Best for examining .dll, .winmd, .exe files. Can save as Visual Studio project.
- **ILSpy**: Cross-platform, has VSCode extension. Good for quick decompilation.
- **dnSpy/dnSpyEx**: Use when you need to **decompile, modify, and recompile**. Right-click → "Modify Method" to edit functions.

### Debugging .NET Applications

To debug a .NET application with dnSpy:

1. **Modify assembly attributes** to enable debugging:
   ```csharp
   // Change from:
   [assembly: Debuggable(DebuggableAttribute.DebuggingModes.IgnoreSymbolStoreSequencePoints)]
   
   // To:
   [assembly: Debuggable(DebuggableAttribute.DebuggingModes.Default |
       DebuggableAttribute.DebuggingModes.DisableOptimizations |
       DebuggableAttribute.DebuggingModes.IgnoreSymbolStoreSequencePoints |
       DebuggableAttribute.DebuggingModes.EnableEditAndContinue)]
   ```

2. **Compile and save** the modified module via File → Save module...

3. **If running under IIS**, restart with:
   ```bash
   iisreset /noforce
   ```

4. **Attach debugger**:
   - Close all opened files in dnSpy
   - Debug Tab → Attach to Process...
   - Select `w3wp.exe` (IIS worker process)
   - Click Attach

5. **Load modules**:
   - Debug → Break All
   - Debug → Windows → Modules
   - Click any module → Open All Modules
   - Right-click in Assembly Explorer → Sort Assemblies

### Adding Logging in dnSpy

To make dnSpy log information to a file, insert this code:

```csharp
using System.IO;
path = "C:\\inetpub\\temp\\MyTest2.txt";
File.AppendAllText(path, "Password: " + password + "\n");
```

## Shellcode Analysis & Debugging

### Tool Selection

| Task | Tool |
|------|------|
| Allocate & debug | Blobrunner, jmp2it |
| Analyze functions | scdbg |
| Emulate & inspect | Cutter |
| Deobfuscate | scdbg, demovfuscator |
| Disassemble | CyberChef |

### Debugging with Blobrunner

1. Run Blobrunner with your shellcode
2. It will **allocate** the shellcode in memory and **stop** execution
3. Note the **memory address** where shellcode was allocated
4. **Attach debugger** (IDA or x64dbg) to the process
5. Set **breakpoint** at the indicated address
6. **Resume** execution to debug the shellcode

### Debugging with jmp2it

1. Run jmp2it with your shellcode
2. It allocates shellcode and starts an **eternal loop**
3. **Attach debugger** to the process
4. **Play start, wait 2-5 seconds, press stop**
5. You'll be in the eternal loop
6. **Jump to next instruction** (call to shellcode)
7. Now executing the shellcode

### Using scdbg

```bash
# Get basic info
scdbg.exe -f shellcode

# Show analysis report at end
scdbg.exe -f shellcode -r

# Enable interactive hooks (file/network) + report
scdbg.exe -f shellcode -i -r

# Dump decoded shellcode
scdbg.exe -f shellcode -d

# Find where shellcode starts
scdbg.exe -f shellcode /findsc

# Start execution at specific offset
scdbg.exe -f shellcode /foff 0x0000004D
```

**Key features:**
- Tells you which functions the shellcode uses
- Detects if shellcode is self-decoding in memory
- **Create Dump** option saves decoded shellcode if modified dynamically
- **Start offset** to begin at specific location

### Using Cutter

1. Open Cutter (GUI for radare2)
2. **Open File** or **Open Shellcode**
3. Set a **breakpoint** where you want to start emulation
4. Cutter will automatically start emulation from there
5. View stack in hex dump

### Disassembling with CyberChef

Upload shellcode file and use this recipe:
- To Hex (Space separator)
- Disassemble x86 (32-bit, Full x86 architecture)

## DLL Debugging

### Using x64dbg/x32dbg

1. **Load rundll32.exe**:
   - 64-bit: `C:\Windows\System32\rundll32.exe`
   - 32-bit: `C:\Windows\SysWOW64\rundll32.exe`

2. **Change Command Line** (File → Change Command Line):
   ```
   "C:\Windows\SysWOW64\rundll32.exe" "path\to\your.dll",FunctionName
   ```

3. **Configure settings**:
   - Options → Settings
   - Select "DLL Entry"

4. **Start execution** - debugger will stop at each DLL entry point
5. When stopped in your DLL's entry, search for breakpoints

**Tip:** When execution stops, check the top of x64dbg window to see which code you're in.

### Using IDA

1. Load rundll32.exe
2. Select **Windbg** debugger
3. Select "**Suspend on library load/unload**"
4. Configure execution parameters with DLL path and function name
5. Start debugging - execution stops when each DLL loads

## Wasm Decompilation

### Online Tools

- **wasm2wat**: https://webassembly.github.io/wabt/demo/wasm2wat/index.html
  - Decompiles from wasm (binary) to wat (text)
- **wat2wasm**: https://webassembly.github.io/wabt/demo/wat2wasm/
  - Compiles from wat to wasm
- **web-wasmdec**: https://wwwg.github.io/web-wasmdec/
  - Alternative decompiler

### Software Tools

- **Jeb**: https://www.pnfsoftware.com/jeb/demo
- **wasmdec**: https://github.com/wwwg/wasmdec

## Platform-Specific Tools

### Rust Binaries

1. Search for functions containing `::main`
2. Identify the main function (often obvious from binary name)
3. Search function names online to learn about inputs/outputs

### Delphi Binaries

1. Use **IDR**: https://github.com/crypto2020/IDR
2. Use **IDA-For-Delphi** plugin: https://github.com/Coldzer0/IDA-For-Delphi
3. In IDA, press **ALT+F7** to import Python plugin
4. Select the plugin and start debugging
5. Press Start button (green or F9) - breakpoint hits at real code start
6. Pressing buttons in GUI will stop debugger in executed function

### Golang Binaries

1. Use **IDAGolangHelper** plugin: https://github.com/sibears/IDAGolangHelper
2. In IDA, press **ALT+F7** to import Python plugin
3. Select the plugin to resolve function names

### GBA Games

**Tools:**
- **no$gba** (debug version): GUI debugger with interface
- **mgba**: CLI debugger
- **gba-ghidra-loader**: Ghidra plugin
- **GhidraGBA**: Ghidra plugin

**Key Input Values:**
```
A = 1
B = 2
SELECT = 4
START = 8
RIGHT = 16
LEFT = 32
UP = 64
DOWN = 128
R = 256
L = 512
```

**Common Pattern:**
- Address `0x4000130` contains `KEYINPUT` function
- Look for how program treats user input
- Check for button value comparisons in decompiled code

### Game Boy

Reference: https://www.youtube.com/watch?v=VVbRe7wr3G4

## Obfuscation Handling

### Movfuscator

**What it does:** Modifies all instructions to `mov` and uses interrupts to change execution flow.

**Deobfuscation:**

1. Try **demovfuscator**: https://github.com/kirschju/demovfuscator

2. **Install dependencies:**
   ```bash
   apt-get install libcapstone-dev
   apt-get install libz3-dev
   ```

3. **Install Keystone:**
   ```bash
   apt-get install cmake
   mkdir build && cd build
   ../make-share.sh
   make install
   ```

4. **CTF workaround:** https://dustri.org/b/defeating-the-recons-movfuscator-crackme.html

## GUI Apps & Games

- **Cheat Engine**: Find and modify values in running game memory
- **PiNCE**: GDB front-end focused on games, works for any reverse engineering
- **Decompiler Explorer** (dogbolt.org): Compare decompiler outputs on small executables

## Compiled Python

To extract Python code from ELF/EXE compiled binaries, use standard .pyc extraction methods.

## Learning Resources

- **Z0F Course**: https://github.com/0xZ0F/Z0FCourse_ReverseEngineering
- **ABD (Binary Deobfuscation)**: https://github.com/malrev/ABD

## Workflow Recommendations

### Before Starting

1. **Identify the target type** (language, platform, format)
2. **Select appropriate tools** from the tables above
3. **Check for obfuscation** (movfuscator, custom packers)
4. **Set up debugging environment** (disable optimizations if needed)

### During Analysis

1. **Start with static analysis** (decompile, disassemble)
2. **Move to dynamic analysis** (debug, trace execution)
3. **Document findings** (function names, key addresses, logic flow)
4. **Test hypotheses** (modify code, recompile, verify)

### Common Pitfalls

- **Optimizations prevent breakpoints**: Modify assembly attributes for .NET
- **Shellcode self-decoding**: Use scdbg to dump decoded version
- **Missing function names**: Use language-specific IDA plugins
- **Wrong architecture**: Verify 32-bit vs 64-bit before loading

## Quick Commands Reference

```bash
# .NET IIS restart
iisreset /noforce

# scdbg analysis
scdbg.exe -f shellcode -r
scdbg.exe -f shellcode -d

# Install demovfuscator deps
apt-get install libcapstone-dev libz3-dev cmake
```

## When to Use This Skill

Use this skill when you need to:
- Decompile or analyze compiled binaries
- Debug shellcode or malicious payloads
- Reverse engineer .NET, Java, Golang, Delphi, or Rust applications
- Work with Wasm, GBA games, or other specialized formats
- Handle obfuscated binaries
- Select appropriate tools for a reverse engineering task
- Understand debugging workflows for different platforms
