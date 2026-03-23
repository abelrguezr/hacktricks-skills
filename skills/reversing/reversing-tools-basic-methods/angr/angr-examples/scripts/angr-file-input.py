#!/usr/bin/env python3
"""
angr template for file-based input.
Usage: python angr-file-input.py <path-to-binary> <start-addr> <filename> <file-size-bytes>
"""

import angr
import claripy
import sys

def main(argv):
    if len(argv) < 5:
        print(f"Usage: {argv[0]} <path-to-binary> <start-addr> <filename> <file-size-bytes>")
        print("Example: python angr-file-input.py binary 0x80488db password.txt 64")
        sys.exit(1)
    
    path_to_binary = argv[1]
    start_address = int(argv[2], 16)
    filename = argv[3]
    file_size_bytes = int(argv[4])
    
    project = angr.Project(path_to_binary)
    initial_state = project.factory.blank_state(addr=start_address)
    
    # Create symbolic file content
    password = claripy.BVS('password', file_size_bytes * 8)
    password_file = angr.storage.SimFile(filename, content=password)
    initial_state.fs.insert(filename, password_file)
    
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
        solution = solution_state.solver.eval(password, cast_to=bytes).decode()
        print(f"Solution: {solution}")
        return 0
    else:
        print("Could not find the solution")
        return 1

if __name__ == '__main__':
    sys.exit(main(sys.argv))
