---
name: python-basics
description: Python fundamentals reference covering data types, operators, control flow, data structures (lists, tuples, dicts, sets), classes, functions, generators, regex, and itertools. Use this skill whenever the user asks about Python syntax, basic operations, data structures, string manipulation, file I/O, error handling, or any Python programming question. Trigger on queries about Python lists, dictionaries, tuples, sets, classes, functions, lambda, map, filter, zip, decorators, generators, regular expressions, or any Python learning/teaching request.
---

# Python Basics Reference

A comprehensive guide to Python fundamentals. Use this as your go-to reference for Python syntax, data structures, and common operations.

## Core Operations

### Arithmetic & Comparison
- **Power**: `3**2` (not `3^2`)
- **Division**: `2/3` returns `0` (int division in Python 2), use `2.0/3.0` for decimals
- **Comparisons**: `>=`, `<=`, `==`, `!=`
- **Logic**: `and`, `or`, `not`

### Type Conversions
```python
float(a)    # Convert to float
int(a)      # Convert to int
str(d)      # Convert to string
ord("A")   # Returns 65 (ASCII)
chr(65)     # Returns 'A'
hex(100)    # Returns '0x64'
hex(100)[2:] # Returns '64' (without 0x prefix)
isinstance(1, int)  # Returns True
```

### String Operations
```python
"a b".split(" ")      # ['a', 'b']
" ".join(['a', 'b'])  # "a b"
"abcdef".startswith("ab")  # True
"abc\n".strip()        # "abc"
"apbc".replace("p", "")  # "abc"
"a".upper()            # "A"
"A".lower()            # "a"
"abc".capitalize()     # "Abc"
```

### String Indexing & Slicing
```python
'abc'[0]      # 'a'
'abc'[-1]     # 'c' (last character)
'abc'[1:3]    # 'bc' (from index 1 to 2)
"qwertyuiop"[:-1]  # 'qwertyuio' (all except last)
```

### String & List Concatenation
```python
3 * 'a'       # 'aaa'
'a' + 'b'     # 'ab'
'a' + str(3)  # 'a3'
[1,2,3] + [4,5]  # [1,2,3,4,5]
```

## Data Structures

### Lists
```python
d = []                    # Empty list
a = [1, 2, 3]
b = [4, 5]
a + b                     # [1, 2, 3, 4, 5]
b.append(6)               # [4, 5, 6]
tuple(a)                  # (1, 2, 3) - convert to tuple
sum([1, 2, 3])            # 6
sorted([1, 43, 5, 3, 21, 4])  # [1, 3, 4, 5, 21, 43]
```

### Tuples
```python
t1 = (1, '2', 'three')
t2 = (5, 6)
t3 = t1 + t2              # (1, '2', 'three', 5, 6)
(4,)                      # Singleton tuple (note the comma)
d = ()                    # Empty tuple
d += (4,)                 # Add to tuple
list(t2)                  # [5, 6] - convert to list
# t1[1] = 'New value'     # ERROR: tuples are immutable
```

**Key difference**: Tuples have structure (position gives meaning), lists have order.

### Dictionaries
```python
d = {}                                    # Empty dict
monthNumbers = {1: 'Jan', 2: 'Feb', 'Feb': 2}
monthNumbers[1]                           # 'Jan'
monthNumbers['Feb']                       # 2
list(monthNumbers)                        # [1, 2, 'Feb'] (keys)
monthNumbers.values()                     # ['Jan', 'Feb', 2]
monthNumbers.keys()                       # dict_keys([1, 2, 'Feb'])
monthNumbers.update({'9': 9})             # Add/update entries
mN = monthNumbers.copy()                  # Independent copy
monthNumbers.get('key', 0)                # Return value or 0 if key doesn't exist
```

### Sets
```python
myset = set(['a', 'b'])                   # {'a', 'b'}
myset.add('c')                            # {'a', 'b', 'c'}
myset.add('a')                            # No change (no duplicates)
myset.update([1, 2, 3])                   # {'a', 'b', 'c', 1, 2, 3}
myset.discard(10)                         # Remove if present, no error if not
myset.remove(10)                          # Remove if present, error if not
myset.union(myset2)                       # Values in myset OR myset2
myset.intersection(myset2)                # Values in myset AND myset2
myset.difference(myset2)                  # Values in myset but not myset2
myset.symmetric_difference(myset2)        # Values in either but not both
myset.pop()                               # Remove and return arbitrary element
myset.intersection_update(myset2)         # myset = intersection
myset.difference_update(myset2)           # myset = difference
```

## Control Flow

### Conditionals
```python
if a:
    # something
elif b:
    # something
else:
    # something
```

### Loops
```python
while(a):
    # something

for i in range(0, 100):      # 0 to 99
    # something

for letter in "hola":       # Iterate over string
    # something with letter
```

### Comments
```python
# One line comment
"""
Several lines comment
Another one
"""
```

## Functions & Advanced Concepts

### Lambda Functions
```python
# Simple function
(lambda x, y: x + y)(5, 3)  # 8

# Sort with lambda
sorted(range(-5, 6), key=lambda x: x**2)  # [0, -1, 1, -2, 2, ...]

# Filter with lambda
filter(lambda x: x % 3 == 0, [1, 2, 3, 4, 5, 6, 7, 8, 9])  # [3, 6, 9]

# Create function factory
def make_adder(n):
    return lambda x: x + n
plus3 = make_adder(3)
plus3(4)  # 7

# Lambda in class
class Car:
    crash = lambda self: print('Boom!')
my_car = Car()
my_car.crash()  # Boom!
```

### Map, Filter, Zip
```python
# Map: apply function to all elements
m = map(lambda x: x % 3 == 0, [1, 2, 3, 4, 5, 6, 7, 8, 9])
# [False, False, True, False, False, True, False, False, True]

# Zip: combine iterables (stops at shortest)
for f, b in zip(foo, bar):
    print(f, b)

# Filter: keep elements matching condition
m = filter(lambda x: x % 3 == 0, [1, 2, 3, 4, 5, 6, 7, 8, 9])
# [3, 6, 9]
```

### List Comprehensions
```python
# Filter in one line
mult1 = [x for x in [1, 2, 3, 4, 5, 6, 7, 8, 9] if x % 3 == 0]
# [3, 6, 9]

# Map in one line
squared = [x**2 for x in range(10)]
# [0, 1, 4, 9, 16, 25, 36, 49, 64, 81]
```

## Classes

### Basic Class
```python
class Person:
    def __init__(self, name):
        self.name = name
        self.lastName = name.split(' ')[-1]
        self.birthday = None
    
    def __lt__(self, other):  # For sorting
        if self.lastName == other.lastName:
            return self.name < other.name
        return self.lastName < other.lastName
    
    def setBirthday(self, month, day, year):
        from datetime import date
        self.birthday = date(year, month, day)
    
    def getAge(self):
        from datetime import date
        return (date.today() - self.birthday).days
```

### Inheritance
```python
class MITPerson(Person):
    nextIdNum = 0  # Class attribute
    
    def __init__(self, name):
        Person.__init__(self, name)
        self.idNum = MITPerson.nextIdNum
        MITPerson.nextIdNum += 1
    
    def __lt__(self, other):
        return self.idNum < other.idNum
```

## Error Handling

### Try-Except
```python
def divide(x, y):
    try:
        result = x / y
    except ZeroDivisionError as e:
        print("division by zero!" + str(e))
    except TypeError:
        divide(int(x), int(y))
    else:
        print("result is", result)
    finally:
        print("executing finally clause in any case")
```

### Assertions
```python
def avg(grades, weights):
    assert len(grades) != 0, 'no grades data'
    assert len(grades) == len(weights), 'wrong number of grades'
    # ... rest of function
```

## Generators

```python
def myGen(n):
    yield n
    yield n + 1

g = myGen(6)
next(g)  # 6
next(g)  # 7
next(g)  # StopIteration error
```

**Why use generators**: They save memory by yielding values one at a time instead of creating a full list.

## Regular Expressions

```python
import re

re.search(r"\w", "hola").group()      # "h"
re.findall(r"\w", "hola")             # ['h', 'o', 'l', 'a']
re.findall(r"\w+(la)", "hola caracola")  # ['la', 'la']
```

### Special Characters
| Pattern | Meaning |
|---------|---------|
| `.` | Any character |
| `\w` | `[a-zA-Z0-9_]` |
| `\d` | Digit |
| `\s` | Whitespace (` \n\r\t\f`) |
| `\S` | Non-whitespace |
| `^` | Start of string |
| `$` | End of string |
| `+` | One or more |
| `*` | Zero or more |
| `?` | Zero or one |

### Options
```python
re.search(pat, str, re.IGNORECASE)  # Case insensitive
re.search(pat, str, re.DOTALL)      # Dot matches newline
re.search(pat, str, re.MULTILINE)   # ^ and $ match per line
```

### Non-greedy Matching
```python
re.findall(r"<.*>", "<b>foo</b>and<i>so on</i>")
# ['<b>foo</b>and<i>so on</i>'] (greedy - matches everything)

re.findall(r"<.*?>", "<b>foo</b>and<i>so on</i>")
# ['<b>', '</b>', '<i>', '</i>'] (non-greedy - matches minimally)
```

## Itertools

```python
from itertools import product, permutations, combinations, combinations_with_replacement

# Cartesian product
list(product([1, 2, 3], [3, 4]))
# [(1, 3), (1, 4), (2, 3), (2, 4), (3, 3), (3, 4)]

list(product([1, 2, 3], repeat=2))
# [(1, 1), (1, 2), (1, 3), (2, 1), (2, 2), (2, 3), (3, 1), (3, 2), (3, 3)]

# Permutations (order matters)
list(permutations(['1', '2', '3']))
# [('1', '2', '3'), ('1', '3', '2'), ('2', '1', '3'), ...]

list(permutations('123', 2))
# [('1', '2'), ('1', '3'), ('2', '1'), ('2', '3'), ('3', '1'), ('3', '2')]

# Combinations (order doesn't matter, no repeats)
list(combinations('123', 2))
# [('1', '2'), ('1', '3'), ('2', '3')]

# Combinations with replacement
list(combinations_with_replacement('1133', 2))
# [('1', '1'), ('1', '1'), ('1', '3'), ('1', '3'), ('1', '1'), ('1', '3'), ('1', '3'), ('3', '3'), ('3', '3'), ('3', '3')]
```

## Decorators

```python
from functools import wraps
import time

def timeme(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        print("Let's call our decorated function")
        start = time.time()
        result = func(*args, **kwargs)
        print(f'Execution time: {time.time() - start:.6f} seconds')
        return result
    return wrapper

@timeme
def decorated_func():
    print("Decorated func!")

decorated_func()
# Output:
# Let's call our decorated function
# Decorated func!
# Execution time: 0.000048 seconds
```

## Quick Reference

### Python 2 vs 3
- `range()` in Python 3 = `xrange()` in Python 2 (generator, not list)
- `print` is a function in Python 3: `print("hello")`
- Division: `2/3` = `0` in Python 2, `0.666...` in Python 3

### Getting Help
```python
dir(str)      # List all available methods
help(str)      # Show class definition
help(function_name)  # Show function documentation
```

### Common Patterns
```python
# Check if key exists in dict
if key in my_dict:
    value = my_dict[key]

# Or use get() with default
value = my_dict.get(key, default_value)

# Iterate with index
for i, item in enumerate(items):
    print(i, item)

# Iterate two lists together
for a, b in zip(list1, list2):
    print(a, b)

# One-liner sum
sum([x**2 for x in range(10)])  # 285
```

## When to Use This Skill

Use this skill when:
- Learning Python basics or reviewing syntax
- Need quick reference for data structures
- Writing Python code and need to recall operations
- Debugging Python code
- Teaching Python to others
- Converting between data types
- Working with strings, lists, dicts, sets, or tuples
- Need help with regex patterns
- Understanding generators, decorators, or lambda functions
