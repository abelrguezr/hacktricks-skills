#!/usr/bin/env python3
"""
Mach-O Binary Information Extractor
Extracts structured information from Mach-O binaries
"""

import subprocess
import json
import sys
import os

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
        return result.stdout.strip()
    except Exception as e:
        return f"Error: {e}"

def analyze_binary(binary_path):
    """Analyze a Mach-O binary and return structured info"""
    
    if not os.path.exists(binary_path):
        return {"error": f"File not found: {binary_path}"}
    
    info = {
        "path": binary_path,
        "file_type": None,
        "architectures": [],
        "macho_header": {},
        "security_flags": [],
        "dependencies": [],
        "load_commands": [],
        "segments": [],
        "code_signed": False,
        "encrypted": False
    }
    
    # File type
    output = run_command(f"file '{binary_path}'")
    info["file_type"] = output
    
    # Extract architectures from file output
    if "universal binary" in output.lower():
        import re
        archs = re.findall(r'\[([^\]]+)\]', output)
        info["architectures"] = archs
    
    # Mach-O header
    output = run_command(f"otool -hv '{binary_path}' 2>/dev/null")
    if output:
        lines = output.split('\n')
        for line in lines:
            if 'magic' in line.lower():
                info["macho_header"]["magic"] = line.strip()
            if 'cputype' in line.lower() or 'arm64' in line.lower() or 'x86_64' in line.lower():
                info["macho_header"]["cpu"] = line.strip()
            if 'filetype' in line.lower():
                info["macho_header"]["filetype"] = line.strip()
    
    # Security flags
    output = run_command(f"otool -hv '{binary_path}' 2>/dev/null")
    if output:
        flags = ['PIE', 'NOUNDEFS', 'NO_HEAP_EXECUTION', 'ALLOW_STACK_EXECUTION', 'DYLDLINK', 'SPLIT_SEGS']
        for flag in flags:
            if flag in output:
                info["security_flags"].append(flag)
    
    # Dependencies
    output = run_command(f"otool -L '{binary_path}' 2>/dev/null")
    if output:
        deps = []
        for line in output.split('\n')[1:]:  # Skip first line
            line = line.strip()
            if line and '(' in line:
                dep = line.split('(')[0].strip()
                deps.append(dep)
        info["dependencies"] = deps
    
    # Load commands
    output = run_command(f"otool -l '{binary_path}' 2>/dev/null | grep 'cmd ' | head -20")
    if output:
        info["load_commands"] = output.split('\n')
    
    # Segments
    output = run_command(f"otool -l '{binary_path}' 2>/dev/null | grep -A2 'LC_SEGMENT' | head -30")
    if output:
        info["segments"] = output.split('\n')
    
    # Code signature
    output = run_command(f"codesign -dv --verbose=2 '{binary_path}' 2>/dev/null")
    if "Authority" in output or "Identifier" in output:
        info["code_signed"] = True
    
    # Encryption
    output = run_command(f"otool -l '{binary_path}' 2>/dev/null")
    if "LC_ENCRYPTION_INFO" in output:
        info["encrypted"] = True
    
    return info

def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_macho_info.py <binary_path> [--json]")
        print("Example: python extract_macho_info.py /bin/ls")
        sys.exit(1)
    
    binary_path = sys.argv[1]
    output_json = '--json' in sys.argv
    
    info = analyze_binary(binary_path)
    
    if output_json:
        print(json.dumps(info, indent=2))
    else:
        print(f"=== Mach-O Analysis: {binary_path} ===")
        print(f"\nFile Type: {info['file_type']}")
        print(f"\nArchitectures: {', '.join(info['architectures']) if info['architectures'] else 'Single architecture'}")
        print(f"\nSecurity Flags: {', '.join(info['security_flags']) if info['security_flags'] else 'None detected'}")
        print(f"\nDependencies ({len(info['dependencies'])}):")
        for dep in info['dependencies'][:5]:
            print(f"  - {dep}")
        if len(info['dependencies']) > 5:
            print(f"  ... and {len(info['dependencies']) - 5} more")
        print(f"\nCode Signed: {'Yes' if info['code_signed'] else 'No'}")
        print(f"Encrypted: {'Yes' if info['encrypted'] else 'No'}")

if __name__ == "__main__":
    main()
