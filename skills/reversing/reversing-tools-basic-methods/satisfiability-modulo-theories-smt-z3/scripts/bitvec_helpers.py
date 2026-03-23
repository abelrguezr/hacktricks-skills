#!/usr/bin/env python3
"""
Helper functions for common bit-vector operations in reversing.

Import this module to get convenient wrappers for common patterns:
    from bitvec_helpers import *
    
    # Create little-endian word from bytes
    eax = le_word([b0, b1, b2, b3])
    
    # Extract register parts
    al = extract_byte(eax, 0)  # bits 0-7
    ah = extract_byte(eax, 1)  # bits 8-15
    
    # Sign/zero extend
    eax = sign_extend(b0, 32)  # movsx
    eax = zero_extend(b0, 32)  # movzx
"""

from z3 import *


def le_word(bytes_list):
    """Create little-endian word from list of byte BitVecs."""
    # bytes_list[0] is lowest byte (LSB)
    return Concat(*reversed(bytes_list))


def be_word(bytes_list):
    """Create big-endian word from list of byte BitVecs."""
    # bytes_list[0] is highest byte (MSB)
    return Concat(*bytes_list)


def extract_byte(word, byte_idx):
    """Extract a byte from a word (0 = lowest byte)."""
    start = byte_idx * 8
    end = start + 7
    return Extract(end, start, word)


def extract_word(word, bit_width, start_bit):
    """Extract a sub-word of given bit width."""
    end_bit = start_bit + bit_width - 1
    return Extract(end_bit, start_bit, word)


def sign_extend(byte_var, target_bits):
    """Sign-extend a byte to target bit width (like movsx)."""
    ext_bits = target_bits - 8
    return SignExt(ext_bits, byte_var)


def zero_extend(byte_var, target_bits):
    """Zero-extend a byte to target bit width (like movzx)."""
    ext_bits = target_bits - 8
    return ZeroExt(ext_bits, byte_var)


def rotate_left(val, n):
    """Rotate left (ROL)."""
    return RotateLeft(val, n)


def rotate_right(val, n):
    """Rotate right (ROR)."""
    return RotateRight(val, n)


def logical_shift_right(val, n):
    """Logical right shift (SHR)."""
    return LShR(val, n)


def arithmetic_shift_right(val, n):
    """Arithmetic right shift (SAR) - signed."""
    return val >> n


def unsigned_lt(x, y):
    """Unsigned less than (x < y)."""
    return ULT(x, y)


def unsigned_le(x, y):
    """Unsigned less than or equal (x <= y)."""
    return ULE(x, y)


def unsigned_gt(x, y):
    """Unsigned greater than (x > y)."""
    return UGT(x, y)


def unsigned_ge(x, y):
    """Unsigned greater than or equal (x >= y)."""
    return UGE(x, y)


def unsigned_div(x, y):
    """Unsigned division."""
    return UDiv(x, y)


def unsigned_mod(x, y):
    """Unsigned modulo."""
    return URem(x, y)


def create_printable_byte():
    """Create a byte constrained to printable ASCII."""
    b = BitVec('b', 8)
    return b, [b >= 0x20, b <= 0x7e]


def create_alphanumeric_byte():
    """Create a byte constrained to alphanumeric."""
    b = BitVec('b', 8)
    return b, [Or(
        And(b >= ord('0'), b <= ord('9')),
        And(b >= ord('A'), b <= ord('Z')),
        And(b >= ord('a'), b <= ord('z'))
    )]


def create_flag_vars(length, alphabet='printable'):
    """Create a list of flag byte variables with alphabet constraints."""
    flag = [BitVec(f'flag_{i}', 8) for i in range(length)]
    constraints = []
    
    if alphabet == 'printable':
        for c in flag:
            constraints.extend([c >= 0x20, c <= 0x7e])
    elif alphabet == 'alphanumeric':
        for c in flag:
            constraints.append(Or(
                And(c >= ord('0'), c <= ord('9')),
                And(c >= ord('A'), c <= ord('Z')),
                And(c >= ord('a'), c <= ord('z'))
            ))
    elif alphabet == 'digits':
        for c in flag:
            constraints.extend([c >= ord('0'), c <= ord('9')])
    elif alphabet == 'lowercase':
        for c in flag:
            constraints.extend([c >= ord('a'), c <= ord('z')])
    elif alphabet == 'uppercase':
        for c in flag:
            constraints.extend([c >= ord('A'), c <= ord('Z')])
    
    return flag, constraints


def model_crc32_step(state, byte_val):
    """Model one step of CRC32 computation.
    
    This is a simplified model - for actual CRC32, you'd need the full polynomial.
    Use this as a template for custom CRC-like operations.
    """
    # CRC32 uses a 32-bit state and processes one byte at a time
    # This is a placeholder - implement the actual CRC32 algorithm
    
    # Example pattern for CRC-like operations:
    # 1. XOR state with byte (shifted)
    # 2. For each bit, conditionally XOR with polynomial
    
    # For actual use, implement the specific CRC variant you're reversing
    pass


def build_tactic_solver(tactic_name='default'):
    """Build a solver with appropriate tactics.
    
    Args:
        tactic_name: 'default', 'bitblast', 'simplify', or custom
    
    Returns:
        A configured Solver
    """
    if tactic_name == 'bitblast':
        # Good for bit-vector heavy problems
        t = Then('simplify', 'solve-eqs', 'bit-blast', 'sat')
    elif tactic_name == 'simplify':
        # Just simplify first
        t = Then('simplify', 'sat')
    elif tactic_name == 'qfbv':
        # Quantifier-free bit-vectors
        t = Then('simplify', 'qfbv')
    else:
        # Default solver
        return Solver()
    
    return t.solver()


# Example usage
if __name__ == '__main__':
    from z3 import *
    
    # Example: Solve a simple check using helpers
    flag, constraints = create_flag_vars(4, 'printable')
    s = Solver()
    
    # Add alphabet constraints
    s.add(constraints)
    
    # Add custom constraints using helpers
    w0 = le_word(flag[:4])  # Little-endian word
    s.add(w0 == BitVecVal(0x44332211, 32))
    
    if s.check() == sat:
        m = s.model()
        result = bytes(m[c].as_long() for c in flag)
        print(f"Solution: {result}")
    else:
        print("No solution")
