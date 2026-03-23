---
name: angr-binary-analysis
description: Use angr for binary analysis, reverse engineering, and symbolic execution. Use this skill whenever the user needs to analyze binaries, extract binary information (architecture, entry points, symbols, sections), perform dynamic analysis with simulation managers, solve CTF challenges with symbolic execution, hook functions, or work with bitvectors and constraints. Trigger this skill for any binary analysis task, reverse engineering work, CTF binary challenges, or when examining ELF/PE files programmatically.
---

# Angr Binary Analysis Skill

A comprehensive skill for using angr to analyze binaries, perform symbolic execution, and solve reverse engineering challenges.

## Quick Start

```python
import angr
import monkeyhex  # Formats numerical results in hexadecimal

# Load a binary
proj = angr.Project('/path/to/binary')
```

## Binary Information Extraction

### Basic Binary Data

Get fundamental information about the loaded binary:

```python
proj.arch           # Architecture: "<Arch AMD64 (LE)>"
proj.arch.name      # Architecture name: 'AMD64'
proj.arch.memory_endness  # Endianness: 'Iend_LE'
proj.entry          # Entry point address: 0x4023c0
proj.filename       # Binary filename: "/bin/true"
```

### Loader Information

Access loaded objects and memory mappings:

```python
proj.loader.min_addr      # Minimum loaded address
proj.loader.max_addr      # Maximum loaded address
proj.loader.all_objects   # All loaded objects
proj.loader.shared_objects  # Shared libraries
proj.loader.all_elf_objects  # All ELF objects (Linux)
proj.loader.all_pe_objects   # All PE objects (Windows)
proj.loader.find_object_containing(0x400000)  # Find object at address
```

### Main Object Analysis

Analyze the main binary's structure:

```python
obj = proj.loader.main_object

# Security features
obj.execstack  # Check for executable stack (True/False)
obj.pic        # Check Position Independent Code (True/False)

# Structure
obj.imports    # Get imported functions
obj.segments   # Get memory segments
obj.sections   # Get sections

# Address lookups
obj.find_segment_containing(addr)  # Find segment by address
obj.find_section_containing(addr)  # Find section by address
obj.plt['function_name']           # Get PLT address of function
obj.reverse_plt[0x400550]          # Get function name from PLT address
```

### Symbol Analysis

Find and analyze symbols:

```python
# Find symbol in any loaded object
symbol = proj.loader.find_symbol('strcmp')
symbol.name          # Symbol name
symbol.owner         # Object containing the symbol
symbol.rebased_addr  # Runtime address
symbol.linked_addr   # Linked address
symbol.is_export     # True if exported

# Find symbol in main object
main_symbol = proj.loader.main_object.get_symbol('strcmp')
main_symbol.is_import    # True if imported
main_symbol.resolvedby   # Symbol that resolves this import
```

### Code Blocks

Disassemble and analyze basic blocks:

```python
block = proj.factory.block(proj.entry)  # Get block at entry point
block.pp()                 # Print disassembly
block.instructions         # Number of instructions
block.instruction_addrs    # List of instruction addresses
```

## Dynamic Analysis

### Creating States

Different state types for different analysis needs:

```python
# Entry state - starts at binary entry point
state = proj.factory.entry_state()

# Blank state - mostly uninitialized
state = proj.factory.blank_state()

# Full init state - runs initializers before entry
state = proj.factory.full_init_state()

# Call state - ready to execute a specific function
state = proj.factory.call_state(func_addr, arg1, arg2)
```

### State Manipulation

Read and modify state during analysis:

```python
# Read registers
state.regs.rip    # Instruction pointer
state.regs.rax    # Return value register

# Read memory
state.mem[addr].int.resolved    # Resolve as C int (BV)
state.mem[addr].int.concrete    # Resolve as Python int
state.mem[addr].long            # Read as long

# Modify state
state.regs.rsi = state.solver.BVV(3, 64)  # Set register
state.mem[0x1000].long = 4                # Write to memory
```

### Simulation Manager

Execute and track binary execution:

```python
# Create simulation manager
simgr = proj.factory.simulation_manager(state)

# Execute one step
simgr.step()

# Access active states
simgr.active[0].regs.rip  # Get RIP from first active state

# Explore until specific condition
simgr.explore(find=0x400500, avoid=0x400600)
```

### Passing Arguments

Provide command-line arguments and environment variables:

```python
# With arguments
state = proj.factory.entry_state(args=['./binary', 'arg1', 'arg2'])

# With environment variables
state = proj.factory.entry_state(env={'VAR': 'value'})

# Symbolic argc
argc = state.solver.BVS('argc', 64)
state = proj.factory.entry_state(argc=argc, args=['./binary'])
state.solver.add(argc <= 1)  # Constrain argc

# Call state with arguments
state = proj.factory.call_state(func_addr, arg1, arg2)

# Pass pointer to string
state = proj.factory.call_state(func_addr, angr.PointerWrapper("string"))
```

## Symbolic Execution

### BitVectors

Create and manipulate bitvectors:

```python
# Concrete bitvector
bv = state.solver.BVV(0x1234, 32)  # 32-bit value 0x1234
state.solver.eval(bv)              # Convert to Python int

# Extend bitvector
bv.zero_extend(30)   # Add 30 zeros on left
bv.sign_extend(30)   # Sign-extend by 30 bits
```

### Symbolic Variables

Create symbolic variables for analysis:

```python
# Create symbolic variables
x = state.solver.BVS("x", 64)  # 64-bit symbolic variable
y = state.solver.BVS("y", 64)

# Symbolic operations
tree = (x + 1) / (y + 2)
tree.op      # Last operation: '__floordiv__'
tree.args     # Operation arguments
```

### Constraints and Solving

Add constraints and find solutions:

```python
# Create fresh state
state = proj.factory.entry_state()

# Create symbolic input
input = state.solver.BVS('input', 64)

# Create expression
operation = (((input + 4) * 3) >> 1) + input

# Add constraint
state.solver.add(operation == 200)

# Find solution
solution = state.solver.eval(input)

# Add more constraints
state.solver.add(input < 2**32)
state.solver.satisfiable()  # Check if constraints are satisfiable
```

### Solver Methods

Different ways to extract solutions:

```python
solver.eval(expression)        # One possible solution
solver.eval_one(expression)    # Single solution or error
solver.eval_upto(expression, n)  # Up to n solutions
solver.eval_atleast(expression, n)  # At least n solutions or error
solver.eval_exact(expression, n)   # Exactly n solutions or error
solver.min(expression)         # Minimum possible value
solver.max(expression)         # Maximum possible value
```

## Hooking

### Hooking Addresses

Replace code at specific addresses:

```python
# Hook with built-in procedure
stub_func = angr.SIM_PROCEDURES['stubs']['ReturnUnconstrained']
proj.hook(0x10000, stub_func())

# Check hook status
proj.is_hooked(0x10000)        # True if hooked
proj.hooked_by(0x10000)        # Get hook object
proj.unhook(0x10000)           # Remove hook

# Hook with custom function
@proj.hook(0x20000, length=5)
def my_hook(state):
    state.regs.rax = 1  # Set return value
```

### Hooking Symbols

Hook by symbol name instead of address:

```python
proj.hook_symbol('function_name', hook_instance)
```

## Common Patterns

### Find Password/Flag

```python
proj = angr.Project('binary')
state = proj.factory.entry_state()
simgr = proj.factory.simulation_manager(state)

# Explore until success/fail
simgr.explore(find=0x400500, avoid=0x400600)

# Get solution from found state
if simgr.found:
    solution = simgr.found[0].posix.dumps(0)  # stdin
    print(solution)
```

### Symbolic Input Analysis

```python
proj = angr.Project('binary')
state = proj.factory.entry_state()

# Make stdin symbolic
state = proj.hook_symbol('__isoc99_scanf', angr.SIM_PROCEDURES['libc']['scanf']())

# Or use symbolic file
state = proj.factory.full_init_state(args=['./binary', 'input.txt'])
```

### Function Analysis

```python
# Analyze a specific function
func_addr = proj.loader.main_object.plt['target_function']
state = proj.factory.call_state(func_addr, arg1, arg2)
simgr = proj.factory.simulation_manager(state)
simgr.step()
```

## Tips

- Use `monkeyhex` to format addresses in hexadecimal for readability
- Always provide `argv[0]` if the binary expects command-line arguments
- Use `full_init_state()` when the binary has complex initialization
- Constrain symbolic variables to reasonable ranges to speed up solving
- Use `simgr.explore()` with `find` and `avoid` to guide exploration
- Hook functions that are slow or non-deterministic to speed up analysis
- Check `simgr.deadended` for states that crashed or terminated
- Use `simgr.unsat` to find states where constraints couldn't be satisfied
