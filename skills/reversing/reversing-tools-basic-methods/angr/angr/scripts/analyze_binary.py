#!/usr/bin/env python3
"""
Basic binary analysis script using angr.
Extracts common information about a binary.
"""

import angr
import sys

def analyze_binary(binary_path):
    """Analyze a binary and print key information."""
    print(f"Analyzing: {binary_path}")
    print("=" * 60)
    
    # Load the binary
    proj = angr.Project(binary_path)
    
    # Basic info
    print(f"\n[Basic Information]")
    print(f"  Architecture: {proj.arch.name}")
    print(f"  Endianness: {proj.arch.memory_endness}")
    print(f"  Entry Point: {hex(proj.entry)}")
    print(f"  Filename: {proj.filename}")
    
    # Loader info
    print(f"\n[Loader Information]")
    print(f"  Min Address: {hex(proj.loader.min_addr)}")
    print(f"  Max Address: {hex(proj.loader.max_addr)}")
    print(f"  Number of Objects: {len(proj.loader.all_objects)}")
    
    # Main object
    obj = proj.loader.main_object
    print(f"\n[Main Object]")
    print(f"  Executable Stack: {obj.execstack}")
    print(f"  Position Independent: {obj.pic}")
    print(f"  Number of Imports: {len(obj.imports)}")
    print(f"  Number of Segments: {len(obj.segments)}")
    print(f"  Number of Sections: {len(obj.sections)}")
    
    # Entry block
    print(f"\n[Entry Block]")
    block = proj.factory.block(proj.entry)
    print(f"  Instructions: {block.instructions}")
    print(f"  Instruction Addresses: {[hex(a) for a in block.instruction_addrs]}")
    
    # First few imports
    print(f"\n[First 10 Imports]")
    for i, imp in enumerate(obj.imports[:10]):
        print(f"  {i+1}. {imp.name}")
    
    print("\n" + "=" * 60)
    return proj

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python analyze_binary.py <binary_path>")
        sys.exit(1)
    
    analyze_binary(sys.argv[1])
