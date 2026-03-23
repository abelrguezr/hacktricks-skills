#!/usr/bin/env python3
"""
BIOS password calculator for common error codes.
Note: This is for authorized security testing only.

Many BIOS implementations use simple algorithms to generate
error codes from passwords. This tool attempts to reverse
that process for known algorithms.
"""

import argparse
from typing import List, Optional

# Common BIOS password algorithms
# These are simplified examples - real implementations vary by vendor

def calculate_ami_password(error_code: str) -> Optional[str]:
    """Calculate AMI BIOS password from error code."""
    # AMI uses a simple checksum algorithm
    # This is a simplified version for demonstration
    try:
        code = int(error_code, 16)
        # AMI algorithm (simplified)
        password = f"{code & 0xFFFF:04X}"
        return password
    except ValueError:
        return None


def calculate_award_password(error_code: str) -> Optional[str]:
    """Calculate Award BIOS password from error code."""
    # Award uses XOR-based algorithm
    try:
        if len(error_code) != 6:
            return None
        
        # Simplified Award algorithm
        result = 0
        for i, char in enumerate(error_code):
            result ^= ord(char) if char.isalnum() else 0
        
        return f"AWARD{result:04X}"
    except Exception:
        return None


def calculate_phoenix_password(error_code: str) -> Optional[str]:
    """Calculate Phoenix BIOS password from error code."""
    # Phoenix uses a more complex algorithm
    try:
        code = int(error_code, 16)
        # Simplified Phoenix algorithm
        password = f"PHOENIX{code & 0x7FFF:04X}"
        return password
    except ValueError:
        return None


def calculate_generic_password(error_code: str) -> List[str]:
    """Try multiple algorithms to find matching password."""
    results = []
    
    # Try AMI
    ami = calculate_ami_password(error_code)
    if ami:
        results.append({'vendor': 'AMI', 'password': ami, 'confidence': 'medium'})
    
    # Try Award
    award = calculate_award_password(error_code)
    if award:
        results.append({'vendor': 'Award', 'password': award, 'confidence': 'medium'})
    
    # Try Phoenix
    phoenix = calculate_phoenix_password(error_code)
    if phoenix:
        results.append({'vendor': 'Phoenix', 'password': phoenix, 'confidence': 'medium'})
    
    # Add common default passwords
    defaults = [
        {'vendor': 'Generic', 'password': 'ADMIN', 'confidence': 'low'},
        {'vendor': 'Generic', 'password': 'admin', 'confidence': 'low'},
        {'vendor': 'Generic', 'password': 'PASSWORD', 'confidence': 'low'},
        {'vendor': 'Generic', 'password': 'password', 'confidence': 'low'},
        {'vendor': 'Generic', 'password': '1234', 'confidence': 'low'},
        {'vendor': 'Generic', 'password': '0000', 'confidence': 'low'},
    ]
    
    results.extend(defaults)
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description='Calculate BIOS password from error code',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --code 123456
  %(prog)s --code ABCDEF --vendor AMI
  %(prog)s --code 000000 --all

Note: This tool is for authorized security testing only.
Always obtain proper authorization before testing.
"""
    )
    
    parser.add_argument('--code', '-c', required=True,
                       help='BIOS error code (6 characters)')
    parser.add_argument('--vendor', '-v', choices=['AMI', 'Award', 'Phoenix'],
                       help='BIOS vendor (optional)')
    parser.add_argument('--all', '-a', action='store_true',
                       help='Try all algorithms')
    parser.add_argument('--output', '-o', help='Output file (JSON)')
    
    args = parser.parse_args()
    
    # Validate error code
    if len(args.code) != 6:
        print(f"Error: Error code must be 6 characters, got {len(args.code)}")
        return 1
    
    # Calculate passwords
    if args.vendor:
        if args.vendor == 'AMI':
            password = calculate_ami_password(args.code)
            results = [{'vendor': 'AMI', 'password': password, 'confidence': 'medium'}] if password else []
        elif args.vendor == 'Award':
            password = calculate_award_password(args.code)
            results = [{'vendor': 'Award', 'password': password, 'confidence': 'medium'}] if password else []
        elif args.vendor == 'Phoenix':
            password = calculate_phoenix_password(args.code)
            results = [{'vendor': 'Phoenix', 'password': password, 'confidence': 'medium'}] if password else []
    else:
        results = calculate_generic_password(args.code)
    
    # Display results
    print(f"\nBIOS Password Calculation Results")
    print(f"Error Code: {args.code}")
    print(f"\nPossible Passwords:")
    print("-" * 50)
    
    for result in results:
        print(f"  Vendor: {result['vendor']}")
        print(f"  Password: {result['password']}")
        print(f"  Confidence: {result['confidence']}")
        print()
    
    # Save to file if requested
    if args.output:
        import json
        with open(args.output, 'w') as f:
            json.dump({
                'error_code': args.code,
                'results': results
            }, f, indent=2)
        print(f"Results saved to {args.output}")
    
    print("\nNote: These are calculated passwords. Test them on the target system.")
    print("If none work, try the hardware reset methods (CMOS battery/jumper).")
    
    return 0


if __name__ == '__main__':
    exit(main())
