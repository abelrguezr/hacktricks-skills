#!/usr/bin/env lua
-- Lua Environment Hardening Template
-- Use this as a reference for creating secure Lua sandbox environments
-- For defenders and developers building Lua-based applications

-- Create a minimal, hardened environment
local function create_hardened_env()
  local env = {}
  
  -- Safe builtins only
  env._G = nil  -- Hide global environment
  env._ENV = env
  
  -- Safe math functions
  env.abs = math.abs
  env.ceil = math.ceil
  env.floor = math.floor
  env.max = math.max
  env.min = math.min
  env.random = math.random
  env.randomseed = math.randomseed
  
  -- Safe string functions (no file operations)
  env.string = {
    byte = string.byte,
    char = string.char,
    find = string.find,
    format = string.format,
    gmatch = string.gmatch,
    gsub = string.gsub,
    len = string.len,
    lower = string.lower,
    match = string.match,
    rep = string.rep,
    sub = string.sub,
    upper = string.upper,
  }
  
  -- Safe table functions
  env.table = {
    concat = table.concat,
    insert = table.insert,
    remove = table.remove,
    sort = table.sort,
  }
  
  -- Safe coroutine functions
  env.coroutine = {
    create = coroutine.create,
    resume = coroutine.resume,
    status = coroutine.status,
    wrap = coroutine.wrap,
    yield = coroutine.yield,
  }
  
  -- Safe debug functions (read-only introspection)
  env.debug = {
    getinfo = debug.getinfo,
    getmetatable = debug.getmetatable,
  }
  
  -- Safe os functions (time only, no execution)
  env.os = {
    date = os.date,
    time = os.time,
    difftime = os.difftime,
  }
  
  -- Safe io functions (no popen, no file creation)
  -- Only include if you need any I/O at all
  env.io = nil  -- Default: no I/O
  
  -- Explicitly block dangerous functions
  env.load = nil
  env.loadstring = nil
  env.loadfile = nil
  env.dofile = nil
  env.package = nil
  env.io = nil
  env.os.execute = nil
  env.os.popen = nil
  
  return env
end

-- Usage example:
-- local safe_env = create_hardened_env()
-- setfenv(my_function, safe_env)  -- Lua 5.1
-- or use environment metatable in Lua 5.2+

-- Print what's blocked
print("=== HARDENED ENVIRONMENT ===")
print("Blocked dangerous primitives:")
print("  - load, loadstring, loadfile, dofile")
print("  - io.popen, os.execute")
print("  - package.loadlib")
print("  - debug.sethook, debug.setfenv")
print("  - ffi (LuaJIT)")
print("")
print("Allowed safe functions:")
print("  - math.* (all)")
print("  - string.* (all)")
print("  - table.* (all)")
print("  - coroutine.* (all)")
print("  - debug.getinfo, debug.getmetatable")
print("  - os.date, os.time, os.difftime")
print("")
print("Recommendations:")
print("  1. Start with empty _ENV, add only what's needed")
print("  2. Never expose bytecode loading (loadstring with precompiled chunks)")
print("  3. Implement bytecode verifier or signature checks")
print("  4. Monitor for process creation from Lua context")
print("  5. Use allowlist approach, not blocklist")
