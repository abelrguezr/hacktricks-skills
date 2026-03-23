#!/usr/bin/env python3
"""
Symbolic execution template for solving binary challenges.
Use this as a starting point for CTF-style binary analysis.
"""

import angr
import sys

def solve_with_symbolic_execution(binary_path, find_addr=None, avoid_addr=None):
    """
    Solve a binary challenge using symbolic execution.
    
    Args:
        binary_path: Path to the binary
        find_addr: Address to find (success condition)
        avoid_addr: Address to avoid (failure condition)
    
    Returns:
        List of solutions found
    """
    print(f"Loading binary: {binary_path}")
    proj = angr.Project(binary_path)
    
    # Create initial state
    print("Creating initial state...")
    state = proj.factory.full_init_state()
    
    # Create simulation manager
    print("Starting symbolic execution...")
    simgr = proj.factory.simulation_manager(state)
    
    # Explore
    if find_addr and avoid_addr:
        simgr.explore(find=find_addr, avoid=avoid_addr)
    elif find_addr:
        simgr.explore(find=find_addr)
    else:
        # Default: explore until we find something
        simgr.explore()
    
    # Check results
    solutions = []
    
    if simgr.found:
        print(f"\nFound {len(simgr.found)} solution(s)!")
        for i, found_state in enumerate(simgr.found):
            print(f"\nSolution {i+1}:")
            # Try to extract input from stdin
            try:
                input_data = found_state.posix.dumps(0)
                print(f"  Input: {input_data}")
                solutions.append(input_data)
            except:
                print(f"  Could not extract input from state")
    
    if simgr.deadended:
        print(f"\n{len(simgr.deadended)} dead-end state(s)")
    
    if simgr.unsat:
        print(f"\n{len(simgr.unsat)} unsatisfiable state(s)")
    
    return solutions


def solve_with_symbolic_input(binary_path, input_size=64):
    """
    Solve by making input symbolic.
    
    Args:
        binary_path: Path to the binary
        input_size: Size of symbolic input in bytes
    
    Returns:
        List of solutions found
    """
    print(f"Loading binary: {binary_path}")
    proj = angr.Project(binary_path)
    
    # Create symbolic input
    print(f"Creating symbolic input of {input_size} bytes...")
    symbolic_input = angr.SIM_PROCEDURES['stubs']['ReturnUnconstrained']()
    
    # Create initial state with symbolic stdin
    state = proj.factory.full_init_state()
    
    # Make stdin symbolic
    state = proj.factory.entry_state(
        stdin=angr.SIM_FILESYSTEM().create_file(
            "stdin",
            angr.SIM_FILESYSTEM().create_file_content(input_size)
        )
    )
    
    # Create simulation manager
    simgr = proj.factory.simulation_manager(state)
    
    # Explore
    print("Exploring...")
    simgr.explore()
    
    # Check results
    solutions = []
    
    if simgr.found:
        print(f"\nFound {len(simgr.found)} solution(s)!")
        for i, found_state in enumerate(simgr.found):
            try:
                input_data = found_state.posix.dumps(0)
                print(f"  Solution {i+1}: {input_data}")
                solutions.append(input_data)
            except:
                pass
    
    return solutions


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python symbolic_solver.py <binary_path> [find_addr] [avoid_addr]")
        print("Example: python symbolic_solver.py ./binary 0x400500 0x400600")
        sys.exit(1)
    
    binary_path = sys.argv[1]
    find_addr = int(sys.argv[2], 16) if len(sys.argv) > 2 else None
    avoid_addr = int(sys.argv[3], 16) if len(sys.argv) > 3 else None
    
    solve_with_symbolic_execution(binary_path, find_addr, avoid_addr)
