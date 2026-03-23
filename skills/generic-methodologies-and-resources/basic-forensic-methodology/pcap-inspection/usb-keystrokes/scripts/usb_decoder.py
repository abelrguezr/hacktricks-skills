#!/usr/bin/env python3
"""
USB HID Keyboard Decoder

Decodes USB HID boot protocol keystrokes from raw hex data.
Input: Lines of colon-separated hex bytes (e.g., "00:00:04:00:00:00:00:00")
Output: Decoded keystrokes to stdout

Usage:
    python3 usb_decoder.py keystrokes.txt
    tshark -r capture.pcap -Y 'usb.capdata && usb.data_len == 8' -T fields -e usb.capdata | \
        sed 's/../:&/g' | python3 usb_decoder.py
"""

import sys
import argparse

# USB HID Usage Table for Keyboard (Page 0x07)
HID_KEYCODES = {
    0x00: None,  # No key
    0x01: None,  # Rollover indicator
    0x02: None,  # RET (Return)
    0x03: None,  # ESC (Escape)
    0x04: 'a',
    0x05: 'b',
    0x06: 'c',
    0x07: 'd',
    0x08: 'e',
    0x09: 'f',
    0x0A: 'g',
    0x0B: 'h',
    0x0C: 'i',
    0x0D: 'j',
    0x0E: 'k',
    0x0F: 'l',
    0x10: ';',
    0x11: "'",
    0x12: '`',
    0x13: '\\',
    0x14: '\n',  # Enter
    0x15: '\x1b',  # Escape
    0x16: '\x08',  # Backspace
    0x17: '\t',  # Tab
    0x18: ' ',
    0x19: '-',
    0x1A: '=',
    0x1B: '[',
    0x1C: ']',
    0x1D: '#',
    0x1E: '1',
    0x1F: '2',
    0x20: '3',
    0x21: '4',
    0x22: '5',
    0x23: '6',
    0x24: '7',
    0x25: '8',
    0x26: '9',
    0x27: '0',
    0x28: '\n',  # Return
    0x29: None,  # Caps Lock
    0x2A: None,  # F1
    0x2B: None,  # F2
    0x2C: None,  # F3
    0x2D: None,  # F4
    0x2E: None,  # F5
    0x2F: None,  # F6
    0x30: None,  # F7
    0x31: None,  # F8
    0x32: None,  # F9
    0x33: None,  # F10
    0x34: None,  # F11
    0x35: None,  # F12
    0x36: None,  # Scroll Lock
    0x37: None,  # Num Lock
    0x38: None,  # Print Screen
    0x39: None,  # Insert
    0x3A: None,  # Home
    0x3B: None,  # Page Up
    0x3C: None,  # Delete
    0x3D: None,  # End
    0x3E: None,  # Page Down
    0x3F: None,  # Right
    0x40: None,  # Left
    0x41: None,  # Down
    0x42: None,  # Up
    0x43: None,  # Num Lock
    0x44: '/',
    0x45: '*',
    0x46: '-',
    0x47: '+',
    0x48: '.',
    0x49: '\n',  # Enter (Numpad)
    0x4A: '0',
    0x4B: '1',
    0x4C: '2',
    0x4D: '3',
    0x4E: '4',
    0x4F: '5',
    0x50: '6',
    0x51: '7',
    0x52: '8',
    0x53: '9',
    0x54: None,  # F13
    0x55: None,  # F14
    0x56: None,  # F15
    0x57: None,  # F16
    0x58: None,  # F17
    0x59: None,  # F18
    0x5A: None,  # F19
    0x5B: None,  # F20
    0x5C: None,  # F21
    0x5D: None,  # F22
    0x5E: None,  # F23
    0x5F: None,  # F24
    0x60: None,  # Left Ctrl
    0x61: None,  # Left Shift
    0x62: None,  # Left Alt
    0x63: None,  # Left GUI
    0x64: None,  # Right Ctrl
    0x65: None,  # Right Shift
    0x66: None,  # Right Alt
    0x67: None,  # Right GUI
}

# Modifier bit positions
MODIFIERS = {
    0x01: 'LCTRL',
    0x02: 'LSHIFT',
    0x04: 'LALT',
    0x08: 'LGUI',
    0x10: 'RCTRL',
    0x20: 'RSHIFT',
    0x40: 'RALT',
    0x80: 'RGUI',
}

# Shifted characters for common keys
SHIFTED = {
    '1': '!',
    '2': '@',
    '3': '#',
    '4': '$',
    '5': '%',
    '6': '^',
    '7': '&',
    '8': '*',
    '9': '(',
    '0': ')',
    '-': '_',
    '=': '+',
    '[': '{',
    ']': '}',
    '\\': '|',
    ';': ':',
    "'": '"',
    ',': '<',
    '.': '>',
    '/': '?',
    '`': '~',
}


def parse_hex_line(line):
    """Parse a hex line into bytes."""
    line = line.strip()
    if not line:
        return None
    
    # Handle colon-separated format: 00:00:04:00:00:00:00:00
    if ':' in line:
        parts = line.split(':')
    else:
        # Handle space-separated or continuous hex
        parts = [line[i:i+2] for i in range(0, len(line), 2)]
    
    try:
        return [int(p, 16) for p in parts if p]
    except ValueError:
        return None


def decode_report(report, verbose=False):
    """Decode a single 8-byte HID report."""
    if len(report) < 8:
        return None, None
    
    modifier = report[0]
    reserved = report[1]
    keycodes = report[2:8]
    
    # Skip empty reports
    if modifier == 0 and all(k == 0 for k in keycodes):
        return None, None
    
    # Check for rollover
    if keycodes[0] == 0x01:
        if verbose:
            print("[ROLLOVER]", end='', flush=True)
        return None, None
    
    result = []
    
    # Decode each keycode
    for keycode in keycodes:
        if keycode == 0:
            continue
        
        char = HID_KEYCODES.get(keycode)
        
        if char is None:
            if verbose:
                print(f"[0x{keycode:02X}]", end='', flush=True)
            continue
        
        # Apply shift modifier
        if modifier & 0x02 or modifier & 0x20:  # Left or Right Shift
            char = SHIFTED.get(char, char.upper() if char.isalpha() else char)
        
        result.append(char)
    
    return result, modifier


def main():
    parser = argparse.ArgumentParser(
        description='Decode USB HID keyboard keystrokes from PCAP data'
    )
    parser.add_argument(
        'input',
        nargs='?',
        default='-',
        help='Input file (default: stdin)'
    )
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Show modifier keys and unknown keycodes'
    )
    parser.add_argument(
        '-r', '--raw',
        action='store_true',
        help='Output raw bytes for debugging'
    )
    args = parser.parse_args()
    
    # Open input
    if args.input == '-':
        f = sys.stdin
    else:
        try:
            f = open(args.input, 'r')
        except FileNotFoundError:
            print(f"Error: File not found: {args.input}", file=sys.stderr)
            sys.exit(1)
    
    try:
        for line in f:
            report = parse_hex_line(line)
            if report is None:
                continue
            
            if args.raw:
                print(' '.join(f'{b:02X}' for b in report))
                continue
            
            chars, modifier = decode_report(report, args.verbose)
            
            if chars:
                for char in chars:
                    if char == '\n':
                        print()
                    elif char == '\t':
                        print('    ', end='', flush=True)
                    elif char == '\x08':
                        print('\b', end='', flush=True)
                    elif char == '\x1b':
                        print('[ESC]', end='', flush=True)
                    else:
                        print(char, end='', flush=True)
            
            # Show modifiers in verbose mode
            if args.verbose and modifier:
                mods = [MODIFIERS.get(m, f'0x{m:02X}') 
                        for m in range(8) if modifier & (1 << m)]
                print(f" [{', '.join(mods)}]", end='', flush=True)
    finally:
        if f != sys.stdin:
            f.close()
    
    print()  # Final newline


if __name__ == '__main__':
    main()
