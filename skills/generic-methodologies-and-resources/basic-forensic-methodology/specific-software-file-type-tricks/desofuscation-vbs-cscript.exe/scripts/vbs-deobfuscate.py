#!/usr/bin/env python3
"""
VBS Deobfuscation Helper

Extracts and decodes common obfuscation patterns from VBS files.
Usage: python vbs-deobfuscate.py <script.vbs>
"""

import re
import base64
import sys
from pathlib import Path


def extract_base64(content: str) -> list:
    """Extract potential Base64 strings from content."""
    # Look for Base64 patterns (at least 40 chars with proper padding)
    pattern = r'[A-Za-z0-9+/]{40,}={0,2}'
    matches = re.findall(pattern, content)
    
    decoded = []
    for match in matches:
        try:
            # Try to decode
            decoded_str = base64.b64decode(match).decode('utf-8', errors='ignore')
            if decoded_str and len(decoded_str) > 10:
                decoded.append({
                    'encoded': match[:100] + '...' if len(match) > 100 else match,
                    'decoded': decoded_str[:200] + '...' if len(decoded_str) > 200 else decoded_str
                })
        except Exception:
            pass
    
    return decoded


def extract_hex_strings(content: str) -> list:
    """Extract and decode hex literals from VBS."""
    # Match &H followed by hex digits
    pattern = r'&H([0-9A-Fa-f]+)'
    matches = re.findall(pattern, content)
    
    decoded = []
    for match in matches:
        try:
            # Convert hex to integer, then try to interpret as ASCII
            value = int(match, 16)
            if value < 256:  # Single byte
                char = chr(value) if 32 <= value < 127 else f'0x{value:02x}'
                decoded.append(f'&H{match} -> {char}')
        except Exception:
            pass
    
    return decoded[:20]  # Limit output


def extract_chr_calls(content: str) -> list:
    """Extract Chr() calls and decode them."""
    # Match Chr(number) patterns
    pattern = r'Chr\s*\(\s*(\d+)\s*\)'
    matches = re.findall(pattern, content, re.IGNORECASE)
    
    decoded = []
    for match in matches:
        try:
            value = int(match)
            if 0 <= value <= 255:
                char = chr(value) if 32 <= value < 127 else f'0x{value:02x}'
                decoded.append(f'Chr({match}) -> {char}')
        except Exception:
            pass
    
    return decoded[:30]  # Limit output


def extract_string_concatenations(content: str) -> list:
    """Find and resolve string concatenations."""
    # Simple pattern for "string" & "string" & "string"
    pattern = r'"([^"]*)"\s*&\s*"([^"]*)"'
    matches = re.findall(pattern, content)
    
    resolved = []
    for match in matches:
        combined = ''.join(match)
        if len(combined) > 5:  # Only show meaningful concatenations
            resolved.append(f'"{match[0]}" & "{match[1]}" -> "{combined}"')
    
    return resolved[:20]


def extract_eval_execute(content: str) -> list:
    """Extract Eval() and Execute() arguments."""
    # Match Eval(string) or Execute(string)
    pattern = r'(?:Eval|Execute)\s*\(\s*(.+?)\s*\)'
    matches = re.findall(pattern, content, re.IGNORECASE | re.DOTALL)
    
    return matches[:10]  # Limit output


def analyze_vbs_file(filepath: str) -> dict:
    """Analyze a VBS file for obfuscation patterns."""
    path = Path(filepath)
    
    if not path.exists():
        raise FileNotFoundError(f"File not found: {filepath}")
    
    content = path.read_text(encoding='utf-8', errors='ignore')
    
    return {
        'file': str(path),
        'size': path.stat().st_size,
        'lines': len(content.splitlines()),
        'base64': extract_base64(content),
        'hex_strings': extract_hex_strings(content),
        'chr_calls': extract_chr_calls(content),
        'concatenations': extract_string_concatenations(content),
        'eval_execute': extract_eval_execute(content)
    }


def print_report(report: dict):
    """Print analysis report."""
    print("=" * 60)
    print(f"VBS Deobfuscation Report: {report['file']}")
    print("=" * 60)
    print(f"\nFile Size: {report['size']} bytes")
    print(f"Lines: {report['lines']}")
    
    if report['base64']:
        print(f"\n## Base64 Encoded Strings ({len(report['base64'])} found)")
        for i, item in enumerate(report['base64'][:5], 1):
            print(f"\n{i}. Encoded: {item['encoded']}")
            print(f"   Decoded: {item['decoded']}")
    
    if report['hex_strings']:
        print(f"\n## Hex Literals ({len(report['hex_strings'])} found)")
        for item in report['hex_strings'][:10]:
            print(f"  {item}")
    
    if report['chr_calls']:
        print(f"\n## Chr() Calls ({len(report['chr_calls'])} found)")
        for item in report['chr_calls'][:15]:
            print(f"  {item}")
    
    if report['concatenations']:
        print(f"\n## String Concatenations ({len(report['concatenations'])} found)")
        for item in report['concatenations'][:10]:
            print(f"  {item}")
    
    if report['eval_execute']:
        print(f"\n## Eval/Execute Calls ({len(report['eval_execute'])} found)")
        for i, item in enumerate(report['eval_execute'][:5], 1):
            print(f"\n{i}. {item[:200]}..." if len(item) > 200 else f"\n{i}. {item}")
    
    print("\n" + "=" * 60)


def main():
    if len(sys.argv) < 2:
        print("Usage: python vbs-deobfuscate.py <script.vbs>")
        print("  Extracts and decodes obfuscation patterns from VBS files")
        sys.exit(1)
    
    try:
        report = analyze_vbs_file(sys.argv[1])
        print_report(report)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
