#!/usr/bin/env python3
"""Validate Python code objects for OOB access vulnerabilities.

Usage:
    python validate_sandbox.py --code-object <path-to-pickle>
    python validate_sandbox.py --source "print('hello')"
"""

import argparse
import dis
import sys
import pickle
import types


def max_name_index(code):
    """Find maximum name index used in bytecode.
    
    Args:
        code: Code object to analyze
        
    Returns:
        int: Maximum name index, or -1 if none
    """
    max_idx = -1
    for ins in dis.get_instructions(code):
        if ins.opname in {
            "LOAD_NAME", "STORE_NAME", "DELETE_NAME",
            "IMPORT_NAME", "IMPORT_FROM",
            "STORE_ATTR", "LOAD_ATTR",
            "LOAD_GLOBAL", "DELETE_GLOBAL"
        }:
            namei = ins.arg or 0
            # Python 3.11+: LOAD_ATTR/LOAD_GLOBAL encode flags in low bit
            if ins.opname in {"LOAD_ATTR", "LOAD_GLOBAL"}:
                namei >>= 1
            max_idx = max(max_idx, namei)
    return max_idx


def max_const_index(code):
    """Find maximum const index used in bytecode.
    
    Args:
        code: Code object to analyze
        
    Returns:
        int: Maximum const index, or -1 if none
    """
    indices = [
        ins.arg for ins in dis.get_instructions(code)
        if ins.opname == "LOAD_CONST"
    ]
    return max(indices + [-1])


def validate_code_object(code):
    """Validate code object for OOB access.
    
    Args:
        code: Code object to validate
        
    Raises:
        ValueError: If OOB access is possible
    """
    if not isinstance(code, types.CodeType):
        raise TypeError(f"Expected CodeType, got {type(code)}")
    
    max_const = max_const_index(code)
    max_name = max_name_index(code)
    
    if max_const >= len(code.co_consts):
        raise ValueError(
            f"Bytecode refers to const index {max_const} "
            f"beyond co_consts length {len(code.co_consts)}"
        )
    
    if max_name >= len(code.co_names):
        raise ValueError(
            f"Bytecode refers to name index {max_name} "
            f"beyond co_names length {len(code.co_names)}"
        )
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description="Validate Python code objects for OOB access"
    )
    parser.add_argument(
        "--source", "-s",
        help="Python source code to compile and validate"
    )
    parser.add_argument(
        "--code-object", "-c",
        help="Path to pickled code object"
    )
    parser.add_argument(
        "--simulate-empty",
        action="store_true",
        help="Simulate empty co_consts/co_names (like sandbox)"
    )
    
    args = parser.parse_args()
    
    # Get code object
    if args.source:
        code = compile(args.source, "<validate>", "exec")
    elif args.code_object:
        with open(args.code_object, "rb") as f:
            code = pickle.load(f)
    else:
        parser.print_help()
        sys.exit(1)
    
    # Simulate sandbox if requested
    if args.simulate_empty:
        code = code.replace(co_consts=(), co_names=())
    
    # Validate
    try:
        validate_code_object(code)
        print("✓ Code object is safe (no OOB access possible)")
        sys.exit(0)
    except ValueError as e:
        print(f"✗ Code object is vulnerable: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"✗ Error: {e}")
        sys.exit(2)


if __name__ == "__main__":
    main()
