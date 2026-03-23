#!/usr/bin/env python3
"""
U-Boot Environment Analyzer

Analyzes U-Boot environment dumps to identify security-relevant variables
and potential attack vectors.

Usage:
    python3 uboot_env_analyzer.py <env_dump.txt>
    python3 uboot_env_analyzer.py -f <env_dump.txt> --output report.json
"""

import argparse
import json
import re
import sys
from typing import Dict, List, Tuple


# Security-relevant environment variables
SECURITY_VARS = {
    'bootcmd': 'Primary boot command - check for network boot or unsigned image loading',
    'bootargs': 'Kernel boot arguments - check for init=/bin/sh or debug options',
    'bootdelay': 'Boot delay - if > 0, allows interruption to U-Boot shell',
    'bootlimit': 'Boot limit counter - affects fallback boot behavior',
    'bootcount': 'Boot failure counter - can be manipulated to trigger fallback',
    'altbootcmd': 'Alternative boot command - may be less secure',
    'boot_targets': 'Boot target list - check for network/USB options',
    'serverip': 'TFTP server IP - indicates network boot capability',
    'ipaddr': 'Device IP address',
    'verify': 'Signature verification setting - verify=n is dangerous',
    'fdt_addr': 'Device tree address',
    'kernel_addr': 'Kernel load address',
    'ramdisk_addr': 'Ramdisk load address',
    'autoload': 'Auto-load setting - affects TFTP behavior',
    'baudrate': 'Serial baud rate',
    'stdin': 'Standard input device',
    'stdout': 'Standard output device',
    'stderr': 'Standard error device',
}

# Dangerous patterns to look for
DANGEROUS_PATTERNS = [
    (r'init=/bin/sh', 'Root shell injection in bootargs'),
    (r'rd\.break', 'Emergency shell injection'),
    (r'verify\s*=\s*n', 'Signature verification disabled'),
    (r'tftpboot', 'Network boot enabled - potential for rogue server'),
    (r'fatload\s+usb', 'USB loading enabled'),
    (r'loady|loads', 'Serial loading enabled - XMODEM/YMODEM'),
    (r'env\s+import', 'Environment import from untrusted source'),
    (r'bootdelay\s*=\s*[1-9]', 'Boot delay allows shell interruption'),
    (r'\$\{.*\}', 'Variable expansion - check for injection points'),
]


def parse_env_dump(content: str) -> Dict[str, str]:
    """Parse U-Boot environment dump into key-value pairs."""
    env_vars = {}
    
    # Pattern for standard U-Boot printenv output
    pattern = r'^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$'
    
    for line in content.split('\n'):
        line = line.strip()
        if not line:
            continue
        
        match = re.match(pattern, line)
        if match:
            key, value = match.groups()
            env_vars[key] = value
    
    return env_vars


def analyze_security_vars(env_vars: Dict[str, str]) -> List[Tuple[str, str, str]]:
    """Analyze security-relevant environment variables."""
    findings = []
    
    for var_name, description in SECURITY_VARS.items():
        if var_name in env_vars:
            value = env_vars[var_name]
            findings.append((var_name, value, description))
    
    return findings


def check_dangerous_patterns(env_vars: Dict[str, str]) -> List[Tuple[str, str, str]]:
    """Check for dangerous patterns in environment values."""
    findings = []
    
    for var_name, value in env_vars.items():
        for pattern, description in DANGEROUS_PATTERNS:
            if re.search(pattern, value, re.IGNORECASE):
                findings.append((var_name, value, description))
    
    return findings


def generate_report(env_vars: Dict[str, str], output_format: str = 'text') -> str:
    """Generate analysis report."""
    security_findings = analyze_security_vars(env_vars)
    dangerous_findings = check_dangerous_patterns(env_vars)
    
    if output_format == 'json':
        report = {
            'total_variables': len(env_vars),
            'security_relevant': [
                {'variable': f[0], 'value': f[1], 'description': f[2]}
                for f in security_findings
            ],
            'dangerous_patterns': [
                {'variable': f[0], 'value': f[1], 'description': f[2]}
                for f in dangerous_findings
            ],
            'all_variables': env_vars
        }
        return json.dumps(report, indent=2)
    
    # Text format
    lines = [
        "=" * 60,
        "U-Boot Environment Security Analysis",
        "=" * 60,
        f"Total variables: {len(env_vars)}",
        "",
        "-" * 60,
        "SECURITY-RELEVANT VARIABLES",
        "-" * 60,
    ]
    
    if security_findings:
        for var_name, value, description in security_findings:
            lines.append(f"\n{var_name}:")
            lines.append(f"  Value: {value[:100]}{'...' if len(value) > 100 else ''}")
            lines.append(f"  Note: {description}")
    else:
        lines.append("\nNo security-relevant variables found.")
    
    lines.extend([
        "",
        "-" * 60,
        "DANGEROUS PATTERNS DETECTED",
        "-" * 60,
    ])
    
    if dangerous_findings:
        for var_name, value, description in dangerous_findings:
            lines.append(f"\n⚠️  {var_name}:")
            lines.append(f"  Pattern: {description}")
            lines.append(f"  Value: {value[:100]}{'...' if len(value) > 100 else ''}")
    else:
        lines.append("\nNo dangerous patterns detected.")
    
    lines.extend([
        "",
        "-" * 60,
        "RECOMMENDATIONS",
        "-" * 60,
        "",
        "1. Check if environment storage is write-protected",
        "2. Test bootdelay interruption to access U-Boot shell",
        "3. Verify signature checking is enabled (verify=y)",
        "4. Assess network boot security (TFTP server access)",
        "5. Check for fallback boot mechanisms (altbootcmd, bootlimit)",
        "",
        "=" * 60,
    ])
    
    return '\n'.join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="U-Boot Environment Analyzer"
    )
    parser.add_argument(
        "input",
        nargs="?",
        help="Input file with U-Boot environment dump (or stdin)"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file (default: stdout)"
    )
    parser.add_argument(
        "--format", "-f",
        choices=['text', 'json'],
        default='text',
        help="Output format (default: text)"
    )
    
    args = parser.parse_args()
    
    # Read input
    if args.input:
        try:
            with open(args.input, 'r') as f:
                content = f.read()
        except FileNotFoundError:
            print(f"[!] File not found: {args.input}")
            sys.exit(1)
    else:
        content = sys.stdin.read()
    
    # Parse and analyze
    env_vars = parse_env_dump(content)
    
    if not env_vars:
        print("[!] No environment variables found in input")
        print("[!] Expected format: key=value (one per line)")
        sys.exit(1)
    
    # Generate report
    report = generate_report(env_vars, args.format)
    
    # Output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(report)
        print(f"[+] Report saved to: {args.output}")
    else:
        print(report)


if __name__ == "__main__":
    main()
