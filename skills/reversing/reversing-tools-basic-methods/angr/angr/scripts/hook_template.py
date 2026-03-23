#!/usr/bin/env python3
"""
Hooking template for angr.
Demonstrates how to hook functions and addresses.
"""

import angr
import sys

def hook_address_example(binary_path, addr_to_hook):
    """
    Example of hooking a specific address.
    
    Args:
        binary_path: Path to the binary
        addr_to_hook: Address to hook (hex string or int)
    """
    if isinstance(addr_to_hook, str):
        addr_to_hook = int(addr_to_hook, 16)
    
    print(f"Loading binary: {binary_path}")
    proj = angr.Project(binary_path)
    
    # Hook with built-in procedure
    print(f"\nHooking address {hex(addr_to_hook)} with ReturnUnconstrained...")
    stub_func = angr.SIM_PROCEDURES['stubs']['ReturnUnconstrained']
    proj.hook(addr_to_hook, stub_func())
    
    # Verify hook
    print(f"Is hooked: {proj.is_hooked(addr_to_hook)}")
    print(f"Hooked by: {proj.hooked_by(addr_to_hook)}")
    
    # Unhook
    proj.unhook(addr_to_hook)
    print(f"After unhook - Is hooked: {proj.is_hooked(addr_to_hook)}")


def custom_hook_example(binary_path, addr_to_hook):
    """
    Example of creating a custom hook.
    
    Args:
        binary_path: Path to the binary
        addr_to_hook: Address to hook (hex string or int)
    """
    if isinstance(addr_to_hook, str):
        addr_to_hook = int(addr_to_hook, 16)
    
    print(f"Loading binary: {binary_path}")
    proj = angr.Project(binary_path)
    
    # Define custom hook
    @proj.hook(addr_to_hook, length=5)
    def my_hook(state):
        """Custom hook that sets return value."""
        print(f"Hook called! Setting RAX to 0x42")
        state.regs.rax = 0x42
    
    print(f"Custom hook installed at {hex(addr_to_hook)}")
    print(f"Is hooked: {proj.is_hooked(addr_to_hook)}")


def hook_symbol_example(binary_path, symbol_name):
    """
    Example of hooking by symbol name.
    
    Args:
        binary_path: Path to the binary
        symbol_name: Name of the symbol to hook
    """
    print(f"Loading binary: {binary_path}")
    proj = angr.Project(binary_path)
    
    # Find the symbol
    symbol = proj.loader.find_symbol(symbol_name)
    if symbol:
        print(f"Found symbol: {symbol.name} at {hex(symbol.rebased_addr)}")
        
        # Hook the symbol
        stub_func = angr.SIM_PROCEDURES['stubs']['ReturnUnconstrained']
        proj.hook_symbol(symbol_name, stub_func())
        
        print(f"Symbol {symbol_name} hooked")
    else:
        print(f"Symbol {symbol_name} not found")


def hook_printf_example(binary_path):
    """
    Example of hooking printf to capture output.
    
    Args:
        binary_path: Path to the binary
    """
    print(f"Loading binary: {binary_path}")
    proj = angr.Project(binary_path)
    
    # Capture printf output
    printf_output = []
    
    @proj.hook_symbol('printf')
    def printf_hook(state):
        """Hook printf to capture output."""
        # Get the format string
        format_addr = state.regs.rdi
        try:
            format_str = state.mem[format_addr].str
            printf_output.append(format_str)
            print(f"printf called with: {format_str}")
        except:
            pass
    
    print("Printf hook installed")
    
    # Run the binary
    state = proj.factory.full_init_state()
    simgr = proj.factory.simulation_manager(state)
    simgr.step()
    
    print(f"\nCaptured {len(printf_output)} printf calls")
    for i, output in enumerate(printf_output):
        print(f"  {i+1}. {output}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python hook_template.py <binary_path> <command> [args]")
        print("Commands:")
        print("  addr <address>     - Hook an address")
        print("  custom <address>   - Custom hook at address")
        print("  symbol <name>      - Hook by symbol name")
        print("  printf             - Hook printf")
        sys.exit(1)
    
    binary_path = sys.argv[1]
    command = sys.argv[2]
    
    if command == "addr" and len(sys.argv) > 3:
        hook_address_example(binary_path, sys.argv[3])
    elif command == "custom" and len(sys.argv) > 3:
        custom_hook_example(binary_path, sys.argv[3])
    elif command == "symbol" and len(sys.argv) > 3:
        hook_symbol_example(binary_path, sys.argv[3])
    elif command == "printf":
        hook_printf_example(binary_path)
    else:
        print("Invalid command or missing arguments")
        sys.exit(1)
