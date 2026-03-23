#!/usr/bin/env python3
"""
UART Firmware Extraction Helper

Processes UART console output to extract firmware dumps.
Usage: python firmware_extractor.py <uart_log.txt> -o <output.rom>
"""

import sys
import re
import argparse
from pathlib import Path

def extract_hex_dump(content):
    """
    Extract hex dump from UART console output.
    
    U-Boot md command typically outputs in format:
    00000000: 45 4c 46 7f 45 4c 46 02  01 01 00 00 00 00 00 00  ELF.ELF.......
    
    Args:
        content: Raw UART console output
        
    Returns:
        bytes: Extracted firmware data
    """
    # Pattern for U-Boot style hex dump
    # Format: address: hex_bytes  ascii
    hex_pattern = re.compile(
        r'^([0-9a-fA-F]{8}):\s*'  # Address
        r'([0-9a-fA-F\s]{48})'    # 16 bytes in hex (48 chars with spaces)
        r'\s+\|?\s*'              # Optional separator
        r'(.{16})'                 # ASCII representation
    )
    
    hex_bytes = []
    
    for line in content.split('\n'):
        match = hex_pattern.match(line.strip())
        if match:
            hex_str = match.group(2).replace(' ', '')
            try:
                # Convert hex string to bytes
                line_bytes = bytes.fromhex(hex_str)
                hex_bytes.extend(line_bytes)
            except ValueError:
                continue
    
    return bytes(hex_bytes)

def extract_raw_hex(content):
    """
    Extract raw hex sequences from output.
    
    Some bootloaders output raw hex without formatting.
    """
    # Find sequences of hex pairs
    hex_pattern = re.compile(r'([0-9a-fA-F]{2})')
    matches = hex_pattern.findall(content)
    
    # Filter to likely firmware content (long sequences)
    # This is a simplified approach
    return bytes.fromhex(''.join(matches[:4096]))  # Limit to 2KB

def clean_uart_log(content):
    """
    Remove common UART console noise from log.
    
    Removes:
    - Timestamps
    - Console prompts
    - Common debug messages
    - Empty lines
    """
    lines = content.split('\n')
    cleaned = []
    
    # Patterns to skip
    skip_patterns = [
        r'^\s*$',  # Empty lines
        r'^\d{4}-\d{2}-\d{2}',  # Timestamps
        r'^#\s*$',  # Shell prompts
        r'^uart>',  # UART prompts
        r'^\(\d+\)>',  # Bus Pirate prompts
        r'^Ready$',  # Status messages
        r'^POWER',  # Power messages
    ]
    
    for line in lines:
        skip = False
        for pattern in skip_patterns:
            if re.match(pattern, line):
                skip = True
                break
        if not skip:
            cleaned.append(line)
    
    return '\n'.join(cleaned)

def save_firmware(data, output_path):
    """Save extracted firmware to file."""
    path = Path(output_path)
    path.write_bytes(data)
    print(f"Saved {len(data)} bytes to {output_path}")
    return path

def analyze_firmware(data):
    """Basic firmware analysis."""
    print("\nFirmware Analysis:")
    print("=" * 40)
    print(f"Size: {len(data)} bytes ({len(data)/1024:.2f} KB)")
    
    # Check for common headers
    if data[:4] == b'\x7fELF':
        print("Format: ELF executable")
    elif data[:2] == b'MZ':
        print("Format: DOS/Windows executable")
    elif data[:4] == b'PK\x03\x04':
        print("Format: ZIP archive")
    else:
        print("Format: Unknown (run binwalk for analysis)")
    
    # Show first 64 bytes as hex
    print("\nFirst 64 bytes:")
    for i in range(0, min(64, len(data)), 16):
        hex_part = ' '.join(f'{b:02x}' for b in data[i:i+16])
        ascii_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in data[i:i+16])
        print(f"{i:08x}: {hex_part:<48} |{ascii_part}|")

def main():
    parser = argparse.ArgumentParser(
        description='Extract firmware from UART console logs'
    )
    parser.add_argument('input', help='Input UART log file')
    parser.add_argument('-o', '--output', help='Output firmware file (default: input.rom)')
    parser.add_argument('--analyze', action='store_true', help='Analyze extracted firmware')
    parser.add_argument('--method', choices=['hexdump', 'raw'], default='hexdump',
                        help='Extraction method (default: hexdump)')
    
    args = parser.parse_args()
    
    # Read input file
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}")
        sys.exit(1)
    
    content = input_path.read_text(encoding='utf-8', errors='ignore')
    
    # Clean the log
    content = clean_uart_log(content)
    
    # Extract firmware
    if args.method == 'hexdump':
        firmware = extract_hex_dump(content)
    else:
        firmware = extract_raw_hex(content)
    
    if not firmware:
        print("Error: No firmware data extracted")
        print("Try a different extraction method or check the log format")
        sys.exit(1)
    
    # Determine output path
    output_path = args.output or str(input_path.with_suffix('.rom'))
    
    # Save firmware
    save_firmware(firmware, output_path)
    
    # Analyze if requested
    if args.analyze:
        analyze_firmware(firmware)
    
    print("\nNext steps:")
    print(f"  binwalk -e {output_path}")
    print(f"  strings {output_path} | head -50")

if __name__ == "__main__":
    main()
