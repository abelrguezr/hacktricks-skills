---
name: angr-binary-analysis
description: How to use angr for binary analysis, CTF challenges, and reverse engineering. Use this skill whenever the user mentions binary analysis, CTF challenges, reverse engineering, symbolic execution, angr, finding passwords in binaries, bypassing checks, or analyzing compiled programs. Make sure to use this skill for any task involving binary exploitation, symbolic execution, or automated binary analysis, even if the user doesn't explicitly mention 'angr'.
---

# Angr Binary Analysis Skill

A comprehensive guide to using angr for binary analysis, CTF challenges, and reverse engineering tasks.

## Quick Start Template

```python
import angr
import claripy
import sys

def main(argv):
    path_to_binary = argv[1]
    project = angr.Project(path_to_binary)
    
    # Start simulation from main
    initial_state = project.factory.entry_state()
    simulation = project.factory.simgr(initial_state)
    
    # Define success and failure conditions
    def is_successful(state):
        stdout = state.posix.dumps(sys.stdout.fileno())
        return b'Good Job.' in stdout
    
    def should_abort(state):
        stdout = state.posix.dumps(sys.stdout.fileno())
        return b'Try again.' in stdout
    
    # Explore to find solution
    simulation.explore(find=is_successful, avoid=should_abort)
    
    if simulation.found:
        solution_state = simulation.found[0]
        print(solution_state.posix.dumps(sys.stdin.fileno()).decode())
    else:
        raise Exception('Could not find the solution')

if __name__ == '__main__':
    main(sys.argv)
```

## Core Techniques

### 1. Reaching Specific Addresses

Use when you know the target address in the binary:

```python
# Find path to specific address
simulation.explore(find=0x804867d, avoid=0x080485A8)

# If found
if simulation.found:
    solution_state = simulation.found[0]
    print(solution_state.posix.dumps(sys.stdin.fileno()))
```

### 2. Working with Registers

When input is stored in registers after scanf:

```python
# Start after scanf at specific address
start_address = 0x80488d1
initial_state = project.factory.blank_state(addr=start_address)

# Create symbolic bitvectors for register values
password0 = claripy.BVS('password0', 32)  # 32-bit value
password1 = claripy.BVS('password1', 32)
password2 = claripy.BVS('password2', 32)

# Map to registers
initial_state.regs.eax = password0
initial_state.regs.ebx = password1
initial_state.regs.edx = password2

# After finding solution, extract values
if simulation.found:
    solution_state = simulation.found[0]
    solution0 = solution_state.solver.eval(password0)
    solution1 = solution_state.solver.eval(password1)
    solution2 = solution_state.solver.eval(password2)
    print(f'{solution0} {solution1} {solution2}')
```

### 3. Working with Stack Values

When scanf stores values on the stack:

```python
# Start after scanf
start_address = 0x8048697
initial_state = project.factory.blank_state(addr=start_address)

# Initialize stack frame
initial_state.regs.ebp = initial_state.regs.esp

# Create symbolic values
password0 = claripy.BVS('password0', 32)
password1 = claripy.BVS('password1', 32)

# Adjust stack pointer and push values
# (subtract padding to reach scanf storage location)
padding_length_in_bytes = 8
initial_state.regs.esp -= padding_length_in_bytes
initial_state.stack_push(password0)
initial_state.stack_push(password1)
```

### 4. Working with Static Memory (Global Variables)

When input is stored in global memory:

```python
# Start after scanf
start_address = 0x8048606
initial_state = project.factory.blank_state(addr=start_address)

# Create symbolic bitvectors (8 bytes each for %8s format)
password0 = claripy.BVS('password0', 8*8)
password1 = claripy.BVS('password1', 8*8)
password2 = claripy.BVS('password2', 8*8)
password3 = claripy.BVS('password3', 8*8)

# Store at known memory addresses
initial_state.memory.store(0xa29faa0, password0)
initial_state.memory.store(0xa29faa8, password1)
initial_state.memory.store(0xa29fab0, password2)
initial_state.memory.store(0xa29fab8, password3)

# Extract as strings after solving
if simulation.found:
    solution_state = simulation.found[0]
    solution0 = solution_state.solver.eval(password0, cast_to=bytes).decode()
    solution1 = solution_state.solver.eval(password1, cast_to=bytes).decode()
    # ... etc
```

### 5. Working with Dynamic Memory (Malloc)

When input is stored in malloc'd memory:

```python
# Create symbolic values
password0 = claripy.BVS('password0', 8*8)
password1 = claripy.BVS('password1', 8*8)

# Use fake heap addresses (find unused addresses in binary)
fake_heap_address0 = 0x4444444
pointer_to_malloc_memory_address0 = 0xa79a118

# Redirect malloc pointer to fake heap
initial_state.memory.store(
    pointer_to_malloc_memory_address0,
    fake_heap_address0,
    endness=project.arch.memory_endness
)

# Store symbolic values at fake heap addresses
initial_state.memory.store(fake_heap_address0, password0)
```

### 6. File Simulation

When the binary reads from a file:

```python
# Start before file is opened
start_address = 0x80488db
initial_state = project.factory.blank_state(addr=start_address)

# Create symbolic file content
filename = 'password.txt'
symbolic_file_size_bytes = 64
password = claripy.BVS('password', symbolic_file_size_bytes * 8)

# Create and insert symbolic file
password_file = angr.storage.SimFile(filename, content=password)
initial_state.fs.insert(filename, password_file)

# Extract solution
if simulation.found:
    solution_state = simulation.found[0]
    solution = solution_state.solver.eval(password, cast_to=bytes).decode()
    print(solution)
```

### 7. Adding Constraints

When you want to add manual constraints to avoid expensive branching:

```python
# Find state at address before expensive comparison
address_to_check = 0x8048671
simulation.explore(find=address_to_check)

if simulation.found:
    solution_state = simulation.found[0]
    
    # Load the value that will be compared
    constrained_address = 0x804a050
    constrained_size = 16
    constrained_bv = solution_state.memory.load(constrained_address, constrained_size)
    
    # Add constraint that it must equal expected value
    expected_value = 'BWYRUBQCMVSBRGFU'.encode()
    solution_state.add_constraints(constrained_bv == expected_value)
    
    print(solution_state.posix.dumps(sys.stdin.fileno()))
```

### 8. Hooking Functions

#### Hook a Single Call

```python
# Hook at specific address
check_address = 0x80486b8
instruction_length = 5

@project.hook(check_address, length=instruction_length)
def skip_check(state):
    # Load input from memory
    input_address = 0x804a054
    input_length = 16
    input_string = state.memory.load(input_address, input_length)
    
    # Set return value based on comparison
    expected = 'XKSPZSJKJYQCQXZV'.encode()
    state.regs.eax = claripy.If(
        input_string == expected,
        claripy.BVV(1, 32),
        claripy.BVV(0, 32)
    )
```

#### Hook a Function (SimProcedure)

```python
class ReplacementCheckEquals(angr.SimProcedure):
    def run(self, to_check, length):
        # Load input from memory address passed as parameter
        input_string = self.state.memory.load(to_check, length)
        
        # Compare and return result
        expected = 'WQNDNKKWAWOLXBAC'.encode()
        return claripy.If(
            input_string == expected,
            claripy.BVV(1, 32),
            claripy.BVV(0, 32)
        )

# Hook by symbol name
project.hook_symbol('check_equals_WQNDNKKWAWOLXBAC', ReplacementCheckEquals())
```

### 9. Simulating scanf with Multiple Parameters

```python
class ReplacementScanf(angr.SimProcedure):
    def run(self, format_string, param0, param1):
        # Create symbolic values
        scanf0 = claripy.BVS('scanf0', 32)
        scanf1 = claripy.BVS('scanf1', 32)
        
        # Store at addresses passed as parameters
        self.state.memory.store(param0, scanf0, endness=project.arch.memory_endness)
        self.state.memory.store(param1, scanf1, endness=project.arch.memory_endness)
        
        # Store references in globals for later retrieval
        self.state.globals['solutions'] = (scanf0, scanf1)

project.hook_symbol('__isoc99_scanf', ReplacementScanf())

# After solving, retrieve from globals
if simulation.found:
    solution_state = simulation.found[0]
    stored_solutions = solution_state.globals['solutions']
    solution = ' '.join(map(str, map(solution_state.solver.eval, stored_solutions)))
    print(solution)
```

### 10. Static Binaries

For statically compiled binaries, manually hook libc functions:

```python
# Hook standard library functions at their addresses
project.hook(0x804ed40, angr.SIM_PROCEDURES['libc']['printf']())
project.hook(0x804ed80, angr.SIM_PROCEDURES['libc']['scanf']())
project.hook(0x804f350, angr.SIM_PROCEDURES['libc']['puts']())
project.hook(0x8048d10, angr.SIM_PROCEDURES['glibc']['__libc_start_main']())

# Available SimProcedures:
# angr.SIM_PROCEDURES['libc']['malloc', 'fopen', 'fclose', 'fwrite',
#                       'getchar', 'strncmp', 'strcmp', 'scanf',
#                       'printf', 'puts', 'exit']
```

### 11. Simulation Managers

Use Veritesting to merge similar states and reduce branching:

```python
# Method 1: Constructor parameter
simulation = project.factory.simgr(initial_state, veritesting=True)

# Method 2: Set technique
simulation = project.factory.simgr(initial_state)
simulation.use_technique(angr.exploration_techniques.Veritesting())
```

## Common Patterns

### Finding Passwords

1. **Simple stdin input**: Use `entry_state()` and `posix.dumps(sys.stdin.fileno())`
2. **Multiple scanf values**: Hook `__isoc99_scanf` with SimProcedure
3. **File input**: Use `SimFile` with symbolic content
4. **Register/stack/memory**: Use `blank_state()` at address after input

### Performance Tips

- **Avoid expensive loops**: Add constraints before char-by-char comparisons
- **Use Veritesting**: Merges similar states to reduce branching
- **Hook expensive functions**: Replace slow checks with symbolic comparisons
- **Start after input**: Use `blank_state()` to skip input handling

### Debugging

```python
# Print state information
print(f"State address: {hex(state.addr)}")
print(f"State registers: eax={hex(state.regs.eax)}")

# Check available states
print(f"Found: {len(simulation.found)}")
print(f"Active: {len(simulation.active)}")
print(f"Deadended: {len(simulation.deadended)}")
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Too many branches | Use Veritesting or add constraints |
| scanf with multiple params | Hook `__isoc99_scanf` with SimProcedure |
| Static binary | Manually hook libc functions |
| Memory address unknown | Disassemble binary to find addresses |
| Slow execution | Hook expensive functions, use constraints |

## References

- [angr documentation](https://docs.angr.io/)
- [angr examples](https://github.com/jakespringer/angr_ctf)
- [SimProcedures](https://github.com/angr/angr/tree/master/angr/procedures/libc)
