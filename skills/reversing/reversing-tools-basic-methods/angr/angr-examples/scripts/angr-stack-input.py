#!/usr/bin/env python3
"""
angr template for stack-based input (after scanf).
Usage: python angr-stack-input.py <path-to-binary> <start-addr> <num-values> <padding-bytes>
"""

import angr
import claripy
import sys

def main(argv):
    if len(argv) < 5:
        print(f"Usage: {argv[0]} <path-to-binary> <start-addr> <num-values> <padding-bytes>")
        print("Example: python angr-stack-input.py binary 0x8048697 2 8")
        sys.exit(1)
    
    path_to_binary = argv[1]
    start_address = int(argv[2], 16)
    num_values = int(argv[3])
    padding_bytes = int(argv[4])
    
    project = angr.Project(path_to_binary)
    initial_state = project.factory.blank_state(addr=start_address)
    
    # Initialize stack frame
    initial_state.regs.ebp = initial_state.regs.esp
    
    # Create symbolic values
    passwords = []
    for i in range(num_values):
        bv = claripy.BVS(f'password{i}', 32)
        passwords.append(bv)
    
    # Adjust stack pointer and push values
    initial_state.regs.esp -= padding_bytes
    for bv in passwords:
        initial_state.stack_push(bv)
    
    simulation = project.factory.simgr(initial_state)
    
    def is_successful(state):
        stdout = state.posix.dumps(sys.stdout.fileno())
        return b'Good Job.' in stdout or b'correct' in stdout.lower()
    
    def should_abort(state):
        stdout = state.posix.dumps(sys.stdout.fileno())
        return b'Try again.' in stdout or b'wrong' in stdout.lower()
    
    simulation.explore(find=is_successful, avoid=should_abort)
    
    if simulation.found:
        solution_state = simulation.found[0]
        solutions = [solution_state.solver.eval(bv) for bv in passwords]
        print(f"Solution: {' '.join(map(str, solutions))}")
        return 0
    else:
        print("Could not find the solution")
        return 1

if __name__ == '__main__':
    sys.exit(main(sys.argv))
