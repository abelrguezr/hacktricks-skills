---
name: macos-app-analysis
description: Use this skill whenever analyzing macOS binaries, debugging applications, performing security research on macOS apps, or fuzzing macOS software. Trigger for any macOS binary analysis, reverse engineering, crash investigation, security assessment, or when the user mentions inspecting, debugging, or testing macOS applications. Also use when investigating suspicious macOS binaries, analyzing crash reports, or performing malware analysis on macOS.
---

# macOS App Analysis

A comprehensive skill for inspecting, debugging, and fuzzing macOS applications and binaries.

## Quick Start

```bash
# Analyze a binary
analyze-macos-binary.sh /path/to/binary

# Check code signature
check-signature.sh /path/to/binary

# Enumerate network processes
enumerate-network-procs.sh

# Set up fuzzing environment
setup-fuzzing.sh
```

## Static Analysis

### Binary Inspection Tools

**otool** - Native macOS binary analysis:
```bash
otool -L /path/to/binary          # List dynamically linked libraries
otool -tv /path/to/binary         # Disassemble application
otool -ov /path/to/binary         # Dump Objective-C metadata
otool -l /path/to/binary          # List load commands (sections)
```

**objdump** - GNU binary utilities:
```bash
objdump -m --dylibs-used /path/to/binary    # List dynamically linked libraries
objdump -m -h /path/to/binary               # Get headers information
objdump -m --syms /path/to/binary           # Check symbol table
objdump -m --full-contents /path/to/binary  # Dump every section
objdump -d /path/to/binary                  # Disassemble the binary
objdump --disassemble-symbols=_func --x86-asm-syntax=intel /path/to/binary
```

**nm** - Symbol listing:
```bash
nm -m /path/to/binary           # List of symbols
nm --dyldinfo-only /path/to/binary  # Dynamic linker info
```

### Disarm (jtool2 successor)

Download from: https://newosxbook.com/tools/disarm.html

```bash
export JCOLOR=1
ARCH=arm64e disarm -c -i -I --signature /path/to/binary  # Get binary info and signature
ARCH=arm64e disarm -c -l /path/to/binary                 # Get binary sections
ARCH=arm64e disarm -c -L /path/to/binary                 # Get binary commands (dependencies)
ARCH=arm64e disarm -c -S /path/to/binary                 # Get symbols (func names, strings)
ARCH=arm64e disarm -c -d /path/to/binary                 # Get disassembled code

disarm -e filesets kernelcache.release.d23              # Extract filesets from kernelcache
JDEBUG=1 disarm -e filesets kernelcache.release.d23     # Extract with debug info
disarm -r "code signature" /path/to/binary              # Check code signature
disarm -e "code signature" /path/to/binary              # Extract code signature
```

### Code Signing Analysis

**codesign** (macOS):
```bash
# Get signer information
codesign -vv -d /path/to/binary 2>&1 | grep -E "Authority|TeamIdentifier"

# Verify app contents haven't been modified
codesign --verify --verbose /path/to/app.app

# Get entitlements from binary
codesign -d --entitlements :- /path/to/binary

# Check if signature is valid
spctl --assess --verbose /path/to/app.app

# Sign a binary
codesign -s <cert-name-keychain> /path/to/binary

# Remove signature (for debugging)
codesign --remove-signature /path/to/binary
```

**ldid** (iOS/macOS):
```bash
ldid -h /path/to/binary          # Get signature info
ldid -e /path/to/binary          # Get entitlements
ldid -S /path/to/entitlements.xml /path/to/binary  # Change entitlements
```

### Package and Disk Image Analysis

**SuspiciousPackage** - Inspect .pkg installers:
- Download: https://mothersruin.com/software/SuspiciousPackage/get.html
- Check preinstall/postinstall scripts for persistence mechanisms

**hdiutil** - Mount disk images:
```bash
hdiutil attach ~/Downloads/file.dmg
# Mounted in /Volumes/
hdiutil detach /Volumes/VolumeName
```

### Detecting Packed Binaries

Look for these indicators:
- High entropy in binary sections
- Almost no readable strings
- UPX packer creates `__XHDR` section on macOS

```bash
# Check entropy
otool -l /path/to/binary | grep -A 5 "__XHDR"
strings /path/to/binary | wc -l  # Low string count suggests packing
```

## Objective-C Analysis

### Understanding objc_msgSend

When Objective-C methods are called, they use `objc_msgSend`:

| Register | Parameter | Description |
|----------|-----------|-------------|
| rdi (x64) / x0 (arm64) | self | Object receiving the message |
| rsi (x64) / x1 (arm64) | op | Method selector (name) |
| rdx (x64) / x2 (arm64) | arg1 | First method argument |
| rcx (x64) / x3 (arm64) | arg2 | Second method argument |
| r8 (x64) / x4 (arm64) | arg3 | Third method argument |
| r9 (x64) / x5 (arm64) | arg4 | Fourth method argument |
| stack | arg5+ | Additional arguments |

### Dumping Objective-C Metadata

**Dynadump** (recommended):
```bash
./dynadump dump /path/to/binary
```

**class-dump** (legacy):
```bash
class-dump /path/to/binary > output.h
```

**iCDump** (modern, cross-platform):
```python
import icdump
metadata = icdump.objc.parse("/path/to/binary")
print(metadata.to_decl())
```

**Native tools**:
```bash
nm --dyldinfo-only /path/to/binary
otool -ov /path/to/binary
objdump --macho --objc-meta-data /path/to/binary
```

## Swift Analysis

### Finding Swift Metadata Sections

```bash
jtool2 -l /path/to/binary | grep "__swift5"
otool -l /path/to/binary | grep "__swift5"
```

Common Swift sections:
- `__swift5_typeref` - Type references
- `__swift5_reflstr` - Reflection strings
- `__swift5_fieldmd` - Field metadata
- `__swift5_capture` - Capture descriptors

### Demangling Swift Symbols

```bash
# Using Swift CLI
swift demangle "__T10MyApp10MyClassC10myMethodyyF"

# Using Ghidra plugin
# https://github.com/ghidraninja/ghidra_scripts/blob/master/swift_demangler.py
```

## Dynamic Analysis

### Prerequisites

**Disable SIP** (System Integrity Protection):
```bash
# In Recovery Mode
csrutil disable
# Or partial disable for debugging
csrutil enable --without debug
# Or without DTrace
csrutil enable --without dtrace
```

**Remove binary signature** (for debugging):
```bash
codesign --remove-signature /path/to/binary
```

### lldb - Primary Debugging Tool

```bash
# Launch debugger
lldb /path/to/binary
lldb -p <pid>                    # Attach to running process
lldb -n /path/to/binary --waitfor  # Wait for connection

# Configure Intel syntax (create ~/.lldbinit)
settings set target.x86-disassembly-flavor intel
```

**Common lldb commands**:

| Command | Description |
|---------|-------------|
| `run` / `r` | Start execution |
| `process launch --stop-at-entry` | Stop at entry point |
| `continue` / `c` | Continue execution |
| `nexti` / `ni` | Step over instruction |
| `stepi` / `si` | Step into instruction |
| `finish` / `f` | Run to function return |
| `control+c` | Pause execution |
| `breakpoint set -n main` | Set breakpoint on main |
| `breakpoint set -r '\[NSFileManager .*\]$'` | Regex breakpoint |
| `breakpoint set -r . -s libobjc.A.dylib` | All functions in library |
| `breakpoint delete <num>` | Delete breakpoint |
| `breakpoint list` / `br l` | List breakpoints |
| `breakpoint enable/disable <num>` | Enable/disable breakpoint |
| `reg read` | Read all registers |
| `reg read $rax` | Read specific register |
| `reg write $rip 0x100035cc0` | Write to register |
| `x/s <address>` | Display as string |
| `x/i <address>` | Display as instruction |
| `x/b <address>` | Display as bytes |
| `print object` / `po` | Print Objective-C object |
| `memory read <address>` | Read memory |
| `memory write <address> -s 4 0x41414141` | Write memory |
| `dis` | Disassemble current function |
| `dis -n <funcname>` | Disassemble function |
| `dis -c 6` | Disassemble 6 lines |
| `parray 3 (char **)$x1` | Print array |
| `image dump sections` | Print memory map |
| `image dump symtab <library>` | List library symbols |
| `process save-core` | Dump process to core file |

**Printing Objective-C method names**:
```bash
# When objc_msgSend is called, rsi holds the method name
(lldb) x/s $rsi
(lldb) print (char*)$rsi
(lldb) reg read $rsi
```

### DTrace - Dynamic Tracing

```bash
# List available probes
dtrace -l | head

# Count syscalls per process
sudo dtrace -n 'syscall:::entry {@[execname] = count()}'

# Log syscalls for specific PID
sudo dtrace -s script.d <pid>

# Log file operations
sudo dtrace -s b.d -c "cat /etc/hosts"

# Trace with dtruss
sudo dtruss -c /path/to/binary
sudo dtruss -p <pid>              # Trace by PID
sudo dtruss -n /path/to/binary    # No argument values
```

**DTrace script example** (save as `syscalls.d`):
```d
syscall::open:entry
{
    printf("%s(%s)", probefunc, copyinstr(arg0));
}
syscall::close:entry
{
    printf("%s(%d)\n", probefunc, arg0);
}
```

### Kernel Tracing Tools

**ktrace** (works with SIP enabled):
```bash
ktrace trace -s -S -t c -c /path/to/binary | grep "binary("
```

**fs_usage** - File system monitoring:
```bash
fs_usage -w -f filesys ls        # Track filesystem actions
fs_usage -w -f network curl      # Track network actions
```

**kdebug** - Kernel tracing facility:
- Trace codes: `/usr/share/misc/trace.codes`
- Tools: `latency`, `sc_usage`, `fs_usage`, `trace`
- Note: Only one kdebug client at a time

### Process Monitoring Tools

**ProcessMonitor** (Objective-See):
- Monitor process creation, file access, network connections
- Download: https://objective-see.com/products/utilities.html#ProcessMonitor

**TaskExplorer** (Objective-See):
- View libraries, files, network connections used by binary
- VirusTotal integration
- Download: https://objective-see.com/products/taskexplorer.html

**FileMonitor** (Objective-See):
- Monitor file creation, modifications, deletions
- Download: https://objective-see.com/products/utilities.html#FileMonitor

**SpriteTree** - Process relationship visualization:
```bash
# Capture process events (requires FDA)
sudo eslogger fork exec rename create > cap.json
# Load cap.json in SpriteTree GUI
```

**Crescendo** - Sysinternals-style monitoring:
- GUI tool for event recording
- Filter by file, process, network events
- Export to JSON
- Download: https://github.com/SuprHackerSteve/Crescendo

### System Diagnostics

**sysdiagnose** - Comprehensive system dump:
```bash
sudo /usr/bin/sysdiagnose
# Output in /tmp/
```

**Stackshots** - Process state capture:
```bash
sample <pid> <seconds> <outputfile>
spindump <pid>
```

**Unified Logs**:
```bash
log show --predicate 'process == "AppName"' --last 1h
log stream --predicate 'process == "AppName"'
```

To reveal `<private>` data, install disclosure certificate (see: https://superuser.com/questions/1532031/how-to-show-private-data-in-macos-unified-log)

## Anti-Debugging Detection

### Common Techniques

**VM Detection**:
```bash
sysctl hw.model              # Returns "Mac" on physical, different on VM
sysctl hw.logicalcpu         # CPU count checks
sysctl hw.physicalcpu        # Physical CPU count
# VMware MAC addresses start with 00:50:56
```

**Debugger Detection**:
```bash
# Check for P_TRACED flag
# Check for ptrace/PT_DENY_ATTACH usage
# Status 45 (0x2d) indicates PT_DENY_ATTACH
```

**Import Analysis**:
```bash
# Check if sysctl or ptrace is imported
otool -L /path/to/binary | grep -E "sysctl|ptrace"
nm /path/to/binary | grep -E "sysctl|ptrace"
```

## Core Dumps

### Configuration

```bash
# Check core dump settings
sysctl kern.coredump           # Should be 1
sysctl kern.sugid_coredump     # Should be 1 for suid binaries
sysctl kern.corefile           # Core file path pattern

# Control core dump size
ulimit -c 0                    # Disable core dumps
ulimit -c unlimited            # Enable unlimited core dumps
```

### Core Dump Locations

- User processes: `/cores/core.%P`
- Default pattern: `kern.corefile` sysctl
- Check: `ls -la /cores/`

## Fuzzing

### Crash Report Analysis

**ReportCrash** locations:
- User apps: `~/Library/Logs/DiagnosticReports/`
- System daemons: `/Library/Logs/DiagnosticReports/`

**Disable crash reporting**:
```bash
launchctl unload -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist
sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist
```

**Re-enable**:
```bash
launchctl load -w /System/Library/LaunchAgents/com.apple.ReportCrash.plist
sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.ReportCrash.Root.plist
```

### Preventing Sleep During Fuzzing

```bash
# System setup
sudo systemsetup -setsleep Never

# pmset
pmset sleep 0

# Using KeepingYouAwake
# https://github.com/newmarcel/KeepingYouAwake
```

### SSH Session Persistence

Edit `/etc/ssh/sshd_config`:
```ssh
TCPKeepAlive yes
ClientAliveInterval 0
ClientAliveCountMax 0
```

```bash
sudo launchctl unload /System/Library/LaunchDaemons/ssh.plist
sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist
```

### Fuzzing Tools

**AFL++** - CLI tools:
```bash
# https://github.com/AFLplusplus/AFLplusplus
afl-fuzz -i input_dir -o output_dir -- /path/to/binary @@
```

**Litefuzz** - GUI apps (recommended for macOS):
```bash
# Basic usage
litefuzz -l -c "/path/to/app.app/Contents/MacOS/AppName FUZZ" \
         -i input_dir -o crashes_dir -n 100000 -ez

# Options:
# -l : Local mode
# -c : Command line with FUZZ placeholder
# -i : Input directory
# -o : Output directory for crashes
# -t : Runtime artifacts directory
# -x : Timeout (default 1s)
# -n : Iterations (default 1)
# -e : Enable second round (reuse crashes)
# -z : Enable malloc debug helpers
# -p : Use pcap replay
# -s : Sockets mode
# -a : Address for network mode

# Example: Fuzz iBooks
litefuzz -l -c "/System/Applications/Books.app/Contents/MacOS/Books FUZZ" \
         -i files/epub -o crashes/ibooks \
         -t ~/Library/Containers/com.apple.iBooksX/Data/tmp \
         -x 10 -n 100000 -ez

# Example: Fuzz Font Book
litefuzz -l -c "/System/Applications/Font Book.app/Contents/MacOS/Font Book FUZZ" \
         -i input/fonts -o crashes/font-book -x 2 -n 500000 -ez

# Example: Network fuzzing with pcap
litefuzz -lk -c "smbutil view smb://localhost:4455" \
         -a tcp://localhost:4455 -i input/mac-smb-resp -p -n 100000 -z
```

### Memory Error Detection

**libgmalloc** - Debug malloc:
```bash
lldb -o "target create \`which binary\"" \
     -o "settings set target.env-vars DYLD_INSERT_LIBRARIES=/usr/lib/libgmalloc.dylib" \
     -o "run arg1 arg2" \
     -o "bt" \
     -o "reg read" \
     -o "dis -s \$pc-32 -c 24 -m -F intel" \
     -o "quit"
```

### Network Process Enumeration

```bash
# Using dtrace
dtrace -n 'syscall::recv*:entry { printf("-> %s (pid=%d)", execname, pid); }' >> recv.log
sort -u recv.log > procs.txt

# Using netstat
netstat -an | grep LISTEN

# Using lsof
lsof -i -P
lsof -i :<port>
```

## Hopper Disassembler

### Interface Overview

**Left Panel**:
- Labels: Binary symbols
- Proc: Procedures and functions
- Str: Strings from binary sections

**Middle Panel**:
- Raw disassembly
- Control flow graph
- Decompiled pseudocode
- Binary view
- Python console (bottom)

**Right Panel**:
- Navigation history
- Call graph (callers/callees)
- Local variables

### Useful Actions

- Right-click code object → References to/from
- Right-click → Rename symbol
- Use Python console for custom analysis

## Best Practices

1. **Always work on copies** - Never modify original binaries
2. **Document findings** - Keep notes on analysis steps and discoveries
3. **Use multiple tools** - Cross-verify findings with different analyzers
4. **Check entitlements** - Review what permissions the binary requests
5. **Monitor side effects** - Watch file, network, and process activity
6. **Preserve evidence** - Save crash reports, logs, and core dumps
7. **Test in isolated environment** - Use VMs or sandboxed environments for suspicious binaries

## Common Workflows

### Quick Binary Analysis

```bash
# 1. Basic info
file /path/to/binary
otool -L /path/to/binary

# 2. Check signature
codesign -vv -d /path/to/binary

# 3. List symbols
nm /path/to/binary | head -50

# 4. Check for anti-debug
strings /path/to/binary | grep -iE "ptrace|debug|vmware|virtual"

# 5. Run with monitoring
sudo dtruss -c /path/to/binary
```

### Malware Analysis

```bash
# 1. Isolate in VM with SIP disabled
# 2. Remove signature
codesign --remove-signature /path/to/malware

# 3. Static analysis
./analyze-macos-binary.sh /path/to/malware

# 4. Dynamic analysis with lldb
lldb /path/to/malware
(lldb) process launch --stop-at-entry
(lldb) breakpoint set -n main
(lldb) continue

# 5. Monitor activity
sudo ProcessMonitor
sudo FileMonitor

# 6. Capture network
sudo dtrace -n 'syscall::recv*:entry { printf("%s (pid=%d)\n", execname, pid); }'
```

### Fuzzing Setup

```bash
# 1. Prepare environment
sudo systemsetup -setsleep Never
# Configure SSH persistence

# 2. Set up input corpus
mkdir -p fuzz_input
# Add sample files to fuzz_input/

# 3. Run fuzzer
litefuzz -l -c "/path/to/app FUZZ" -i fuzz_input -o crashes -n 1000000 -ez

# 4. Monitor crashes
watch -n 1 'ls -lt crashes/ | head -10'
```

## References

- [The Art of Mac Malware](https://taomm.org/)
- [OS X Incident Response](https://www.amazon.com/OS-Incident-Response-Scripting-Analysis-ebook/dp/B01FHOHHVS)
- [DTrace Documentation](https://illumos.org/books/dtrace/chp-intro.html)
- [Swift Metadata Analysis](https://knight.sc/reverse%20engineering/2019/07/17/swift-metadata.html)
- [Defeating Anti-Debug Techniques](https://alexomara.com/blog/defeating-anti-debug-techniques-macos-ptrace-variants/)
- [Debugging PT_DENY_ATTACH](https://knight.sc/debugging/2019/06/03/debugging-apple-binaries-that-use-pt-deny-attach.html)
