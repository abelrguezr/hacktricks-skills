#!/usr/bin/env python3
"""
angr template for register-based input (after scanf).
Usage: python angr-register-input.py <path-to-binary> <start-addr> <reg1> <reg2> ...
"""

import angr
import claripy
import sys

def main(argv):
    if len(argv) < 4:
        print(f"Usage: {argv[0]} <path-to-binary> <start-addr> <reg1> <reg2> ...")
        print("Example: python angr-register-input.py binary 0x80488d1 eax ebx edx")
        sys.exit(1)
    
    path_to_binary = argv[1]
    start_address = int(argv[2], 16)
    registers = argv[3:]
    
    project = angr.Project(path_to_binary)
    initial_state = project.factory.blank_state(addr=start_address)
    
    # Create symbolic bitvectors for each register
    passwords = {}
    for i, reg in enumerate(registers):
        bv_name = f'password{i}'
        bv = claripy.BVS(bv_name, 32)
        passwords[bv_name] = bv
        setattr(initial_state.regs, reg, bv)
    
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
        solutions = [solution_state.solver.eval(passwords[bv_name]) for bv_name in passwords]
        print(f"Solution: {' '.join(map(str, solutions))}")
        return 0
    else:
        print("Could not find the solution")
        return 1

if __name__ == '__main__':
    sys.exit(main(sys.argv))
