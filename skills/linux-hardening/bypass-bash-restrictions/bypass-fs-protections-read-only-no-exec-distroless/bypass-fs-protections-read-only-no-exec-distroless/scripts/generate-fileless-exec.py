#!/usr/bin/env python3
"""
Generate fileless ELF execution script using create_memfd syscall.
This is a simplified wrapper around the fileless-elf-exec concept.

Usage:
    python3 generate-fileless-exec.py -b binary.elf -l python -o output.py
    python3 generate-fileless-exec.py -b binary.elf -l perl -o output.pl
"""

import argparse
import base64
import zlib
import os
import sys

def compress_and_encode(binary_path):
    """Compress and base64 encode a binary file."""
    with open(binary_path, 'rb') as f:
        data = f.read()
    
    # Compress with zlib
    compressed = zlib.compress(data, level=9)
    
    # Base64 encode
    encoded = base64.b64encode(compressed).decode('ascii')
    
    return encoded

def generate_python_script(encoded_data, argv0=None, args=None):
    """Generate Python script for fileless execution."""
    if args is None:
        args = []
    
    script = f'''#!/usr/bin/env python3
import os
import sys
import ctypes
import base64
import zlib

# Compressed and encoded binary data
DATA = "{encoded_data}"

# Decode and decompress
data = zlib.decompress(base64.b64decode(DATA))

# create_memfd syscall number (Linux x86_64)
SYS_create_memfd = 319
SYS_execve = 59

# Create memory file descriptor
def create_memfd(name, flags):
    return ctypes.CDLL("libc.so.6", mode=ctypes.RTLD_GLOBAL).syscall(
        SYS_create_memfd, name, flags
    )

# Write data to memfd
def write_to_fd(fd, data):
    libc = ctypes.CDLL("libc.so.6", mode=ctypes.RTLD_GLOBAL)
    libc.write(fd, data, len(data))

# Seek to beginning of fd
def seek_to_beginning(fd):
    libc = ctypes.CDLL("libc.so.6", mode=ctypes.RTLD_GLOBAL)
    libc.lseek(fd, 0, 0)

# Execute from fd
def execve_fd(fd, argv, envp):
    libc = ctypes.CDLL("libc.so.6", mode=ctypes.RTLD_GLOBAL)
    
    # Build argv array
    argv_ptr = (ctypes.c_char_p * (len(argv) + 1))()
    for i, arg in enumerate(argv):
        argv_ptr[i] = arg.encode() if isinstance(arg, str) else arg
    
    # Build envp array (use current environment)
    envp_ptr = (ctypes.c_char_p * (len(os.environ) + 1))()
    for i, (k, v) in enumerate(os.environ.items()):
        envp_ptr[i] = f"{k}={v}".encode()
    
    # Call execve with fd as filename (Linux 5.8+)
    libc.execve(f"/proc/self/fd/{fd}", argv_ptr, envp_ptr)

# Main execution
if __name__ == "__main__":
    # Create memory fd
    fd = create_memfd("", 0)
    if fd < 0:
        print("Failed to create memfd", file=sys.stderr)
        sys.exit(1)
    
    # Write binary data to fd
    write_to_fd(fd, data)
    
    # Seek to beginning
    seek_to_beginning(fd)
    
    # Prepare arguments
    argv = ["{argv0}" if argv0 else "binary"] + [str(a) for a in args]
    
    # Execute
    execve_fd(fd, argv, None)
'''
    return script

def generate_perl_script(encoded_data, argv0=None, args=None):
    """Generate Perl script for fileless execution."""
    if args is None:
        args = []
    
    script = f'''#!/usr/bin/env perl
use strict;
use warnings;
use Compress::Zlib;
use MIME::Base64;

# Compressed and encoded binary data
my $data = decode_base64("{encoded_data}");

# Decompress
my $inflator = inflateInit or die "Cannot create inflator: $!";
my $binary;
my $status = $inflator->inflate(\$data, \\my $buf);
$binary = $buf;
$inflator->end;

# Create memory fd using syscall
my $SYS_create_memfd = 319;
my $fd = syscall($SYS_create_memfd, "", 0);
if ($fd < 0) {
    die "Failed to create memfd";
}

# Write binary to fd
open(my $fh, ">=", "/proc/self/fd/$fd") or die "Cannot open fd: $!";
print $fh $binary;
close($fh);

# Execute
my @argv = ("{argv0}" // "binary", @args);
exec("/proc/self/fd/$fd", @argv);
'''
    return script

def main():
    parser = argparse.ArgumentParser(
        description='Generate fileless ELF execution script'
    )
    parser.add_argument('-b', '--binary', required=True,
                        help='Path to binary file')
    parser.add_argument('-l', '--language', required=True,
                        choices=['python', 'perl', 'ruby'],
                        help='Target language')
    parser.add_argument('-o', '--output', required=True,
                        help='Output script path')
    parser.add_argument('--argv0', default=None,
                        help='Custom argv[0] for the executed binary')
    parser.add_argument('args', nargs='*', default=[],
                        help='Arguments to pass to the binary')
    
    args = parser.parse_args()
    
    # Validate binary exists
    if not os.path.exists(args.binary):
        print(f"Error: Binary not found: {args.binary}", file=sys.stderr)
        sys.exit(1)
    
    # Compress and encode
    print(f"Processing {args.binary}...")
    encoded = compress_and_encode(args.binary)
    print(f"Compressed size: {len(encoded)} bytes")
    
    # Generate script
    if args.language == 'python':
        script = generate_python_script(encoded, args.argv0, args.args)
    elif args.language == 'perl':
        script = generate_perl_script(encoded, args.argv0, args.args)
    else:
        print(f"Error: Language {args.language} not yet supported", file=sys.stderr)
        sys.exit(1)
    
    # Write output
    with open(args.output, 'w') as f:
        f.write(script)
    
    os.chmod(args.output, 0o755)
    print(f"Generated: {args.output}")
    print(f"Usage: {args.output}")

if __name__ == '__main__':
    main()
