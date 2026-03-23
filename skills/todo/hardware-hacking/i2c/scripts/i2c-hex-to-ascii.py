#!/usr/bin/env python3
"""Convert I2C hex data to ASCII for quick analysis."""

import sys

def hex_to_ascii(hex_string):
    """Convert hex string to ASCII representation."""
    hex_string = hex_string.replace(' ', '').replace('0x', '').replace('0X', '')
    
    if len(hex_string) % 2 != 0:
        print("Error: Hex string must have even number of characters")
        return None
    
    result = []
    for i in range(0, len(hex_string), 2):
        byte = int(hex_string[i:i+2], 16)
        if 32 <= byte <= 126:
            result.append(chr(byte))
        else:
            result.append(f'[{byte:02X}]')
    
    return ''.join(result)

def main():
    if len(sys.argv) < 2:
        print("Usage: i2c-hex-to-ascii.py <hex_string>")
        print("Example: i2c-hex-to-ascii.py '42 42 42 20 48 69'")
        print("Example: i2c-hex-to-ascii.py '424242204869'")
        sys.exit(1)
    
    hex_input = ' '.join(sys.argv[1:])
    ascii_output = hex_to_ascii(hex_input)
    
    if ascii_output:
        print(f"Hex:  {hex_input}")
        print(f"ASCII: {ascii_output}")

if __name__ == "__main__":
    main()
