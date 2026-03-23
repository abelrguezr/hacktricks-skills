#!/usr/bin/env python3
"""
angr template for hooking a function with SimProcedure.
Usage: python angr-hook-function.py <path-to-binary> <function-symbol> <expected-string>
"""

import angr
import claripy
import sys

def main(argv):
    if len(argv) < 4:
        print(f"Usage: {argv[0]} <path-to-binary> <function-symbol> <expected-string>")
        print("Example: python angr-hook-function.py binary check_equals_ABCD ABCD")
        sys.exit(1)
    
    path_to_binary = argv[1]
    function_symbol = argv[2]
    expected_string = argv[3].encode()
    
    project = angr.Project(path_to_binary)
    initial_state = project.factory.entry_state()
    
    # Define SimProcedure to replace the function
    class ReplacementCheckEquals(angr.SimProcedure):
        def run(self, to_check, length):
            input_string = self.state.memory.load(to_check, length)
            return claripy.If(
                input_string == expected_string,
                claripy.BVV(1, 32),
                claripy.BVV(0, 32)
            )
    
    # Hook the function
    project.hook_symbol(function_symbol, ReplacementCheckEquals())
    
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
        solution = solution_state.posix.dumps(sys.stdin.fileno()).decode()
        print(f"Solution: {solution}")
        return 0
    else:
        print("Could not find the solution")
        return 1

if __name__ == '__main__':
    sys.exit(main(sys.argv))
