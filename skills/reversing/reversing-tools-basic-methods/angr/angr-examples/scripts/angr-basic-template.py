#!/usr/bin/env python3
"""
Basic angr template for CTF challenges.
Usage: python angr-basic-template.py <path-to-binary>
"""

import angr
import claripy
import sys

def main(argv):
    if len(argv) < 2:
        print(f"Usage: {argv[0]} <path-to-binary>")
        sys.exit(1)
    
    path_to_binary = argv[1]
    project = angr.Project(path_to_binary)
    
    # Start simulation from main
    initial_state = project.factory.entry_state()
    simulation = project.factory.simgr(initial_state)
    
    # Define success and failure conditions
    def is_successful(state):
        stdout = state.posix.dumps(sys.stdout.fileno())
        return b'Good Job.' in stdout or b'correct' in stdout.lower() or b'win' in stdout.lower()
    
    def should_abort(state):
        stdout = state.posix.dumps(sys.stdout.fileno())
        return b'Try again.' in stdout or b'wrong' in stdout.lower() or b'fail' in stdout.lower()
    
    # Explore to find solution
    simulation.explore(find=is_successful, avoid=should_abort)
    
    if simulation.found:
        solution_state = simulation.found[0]
        solution = solution_state.posix.dumps(sys.stdin.fileno())
        print(f"Solution: {solution.decode()}")
        return 0
    else:
        print("Could not find the solution")
        return 1

if __name__ == '__main__':
    sys.exit(main(sys.argv))
