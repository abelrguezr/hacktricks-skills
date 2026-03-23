---
name: lua-sandbox-security
description: Security research and penetration testing for Lua sandbox environments. Use this skill when analyzing Lua VM security in game clients, embedded applications, or scripting engines. Trigger when users mention Lua sandboxes, embedded Lua, game client security, bytecode exploitation, sandbox escape, or need to enumerate Lua environments for security assessments. Also use when hardening Lua environments or reviewing Lua security configurations.
---

# Lua Sandbox Security Research

A skill for security researchers and developers to analyze, test, and harden Lua sandbox environments in embedded applications, game clients, and scripting engines.

## When to Use This Skill

Use this skill when:
- You need to enumerate a Lua sandbox environment for security testing
- You're assessing Lua VM security in game clients or embedded applications
- You want to identify dangerous primitives exposed in a Lua environment
- You're testing for sandbox escape vulnerabilities
- You need to harden a Lua environment against exploitation
- You're reviewing Lua security configurations or bytecode loading policies

## Core Concepts

### The Lua Sandbox Model

Lua sandboxes typically restrict access to standard libraries (io, os, package, debug) while exposing a limited set of safe functions. However, misconfigurations often leave dangerous primitives reachable, enabling:
- Command execution via `io.popen()` or `os.execute()`
- Arbitrary code execution via `load()`, `loadstring()`, `loadfile()`
- Native library loading via `package.loadlib()`
- Memory corruption via bytecode exploitation (Lua ≤5.1)

### Attack Surface

The global environment `_G` is the primary attack surface. Enumeration reveals what's reachable:
- **io/os**: Direct command execution
- **load/loadstring/loadfile**: Source/bytecode execution
- **package**: Dynamic library loading
- **debug**: Privilege escalation within VM
- **LuaJIT ffi**: Native code calls

## Enumeration Techniques

### Dump the Global Environment

Start by inventorying all reachable globals. Use any available output primitive:

```lua
-- Basic _G dumper
local function dump_globals(out)
  out("=== DUMPING _G ===")
  for k, v in pairs(_G) do
    out(tostring(k) .. " = " .. tostring(v))
  end
end
```

### Alternative Output Channels

When `print()` is blocked, repurpose in-VM channels:

```lua
-- Example: Using game UI as output
local function create_output_channel()
  -- Some engines require initialization
  H.PlaySound(0, "r[1]")
  return function(msg)
    H.Say(1, msg)
  end
end

-- Usage
local out = create_output_channel()
dump_globals(out)
```

**Generalize this pattern**: Any textbox, toast, logger, or UI callback accepting strings can act as stdout for reconnaissance.

### Auto-Run Callbacks

If the host pushes scripts to clients with auto-run hooks, payloads execute on load:

```lua
function OnInit()
  -- Payload executes when script loads
  io.popen("whoami")
end

-- Other common callbacks: OnLoad, OnEnter, OnStart
```

## Dangerous Primitives Checklist

During enumeration, specifically hunt for:

| Primitive | Risk | Example |
|-----------|------|---------|
| `io.popen` | Command execution | `io.popen("id")` |
| `os.execute` | Command execution | `os.execute("/bin/id")` |
| `load/loadstring` | Code execution | `load("os.execute('id')")()` |
| `loadfile/dofile` | File-based code | `dofile("/tmp/payload.lua")` |
| `package.loadlib` | Native loading | `package.loadlib("./lib.so", "luaopen_foo")` |
| `debug` | Privilege escalation | `debug.getinfo`, `debug.sethook` |
| `ffi` (LuaJIT) | Native calls | `ffi.C.system("id")` |

### Testing Primitive Availability

```lua
-- Check if io.popen is reachable
if io and io.popen then
  local handle = io.popen("echo test")
  local result = handle:read("*a")
  handle:close()
  print("io.popen works: " .. result)
end

-- Check loadstring
if loadstring then
  local f = loadstring("return 42")
  print("loadstring works: " .. f())
end

-- Check package.loadlib
if package and package.loadlib then
  print("package.loadlib is exposed")
end
```

## Bytecode Exploitation (Advanced)

When `load/loadstring` are exposed but `io/os` are restricted, crafted bytecode can enable memory corruption:

### Key Facts

- **Lua ≤5.1**: Bytecode verifier has known bypasses
- **Lua 5.2+**: Verifier removed (applications should reject precompiled chunks)
- **Attack flow**: Leak pointers → craft type confusion → arbitrary read/write → code execution

### Basic Bytecode Loading

```lua
-- Create and load bytecode
local function create_bytecode()
  local bc = string.dump(function() return 0x1337 end)
  local f = loadstring(bc)
  return f()
end

print(create_bytecode()) -- 4919
```

**Note**: Bytecode exploitation is engine/version-specific and requires reverse engineering. See references for detailed primitives.

## Hardening Recommendations

### Server-Side Controls

1. **Reject or rewrite user scripts** - Don't execute untrusted code directly
2. **Allowlist safe APIs** - Only expose necessary functions
3. **Strip dangerous globals**:
   ```lua
   _ENV = {}
   _ENV.print = print  -- Only safe functions
   -- Remove: io, os, load, loadstring, loadfile, dofile
   -- Remove: package.loadlib, debug, ffi
   ```

### Client-Side Controls

1. **Minimal _ENV** - Start with empty environment, add only what's needed
2. **Forbid bytecode loading** - Reject `loadstring` with precompiled chunks
3. **Reintroduce bytecode verifier** - Or implement signature checks
4. **Block process creation** - Prevent child process spawning from client

### Telemetry & Detection

- Alert on gameclient → child process creation after script load
- Correlate UI/chat/script events with process spawning
- Monitor for unusual `io.popen` or `os.execute` calls

## Security Assessment Workflow

1. **Enumerate** - Dump `_G` and identify reachable primitives
2. **Test** - Verify dangerous functions actually work
3. **Exploit** - If primitives are exposed, demonstrate impact
4. **Report** - Document findings with reproduction steps
5. **Remediate** - Apply hardening recommendations

## References

- [This House is Haunted: AION housing Lua VM RCE](https://appsec.space/posts/aion-housing-exploit/)
- [Bytecode Breakdown: Factorio Lua Security Flaws](https://memorycorruption.net/posts/rce-lua-factorio/)
- [Lua 5.1 bytecode verifier discussion](https://web.archive.org/web/20230308193701/https://lua-users.org/lists/lua-l/2009-03/msg00039.html)
- [Exploiting Lua 5.1 bytecode](https://gist.github.com/ulidtko/51b8671260db79da64d193e41d7193e41d7e7d16)

## Important Notes

- **Authorization**: Only test Lua sandboxes you own or have explicit permission to assess
- **Scope**: Document what you're testing and get written authorization
- **Safety**: Some exploitation techniques can crash applications or corrupt data
- **Defense**: This skill is equally valuable for hardening Lua environments against attacks
