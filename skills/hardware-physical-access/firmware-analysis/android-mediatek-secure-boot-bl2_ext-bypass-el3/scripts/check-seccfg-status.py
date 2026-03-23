#!/usr/bin/env python3
"""
Check seccfg status from DA output or device configuration.

Usage:
    python check-seccfg-status.py <da-output.json>
    python check-seccfg-status.py --target-config 0x00000001
"""

import sys
import json
import argparse
from pathlib import Path


def parse_target_config(config_value: int) -> dict:
    """Parse MTK target configuration bitfields."""
    
    analysis = {
        "raw_value": config_value,
        "hex_value": hex(config_value),
        "bits": {},
        "security_features": {}
    }
    
    # Common MTK target config bitfields
    # Note: Exact bit positions may vary by platform
    bit_definitions = {
        0: "SBC (Secure Boot Chain)",
        1: "SBC Lock",
        2: "Secure Download",
        3: "Preloader Verification",
        4: "Brom Verification",
        5: "DA Extension",
        6: "Factory Unlock",
        7: "Test Mode"
    }
    
    for bit_pos, description in bit_definitions.items():
        bit_value = (config_value >> bit_pos) & 1
        analysis["bits"][f"bit_{bit_pos}"] = {
            "value": bit_value,
            "description": description,
            "enabled": bit_value == 1
        }
    
    # Security feature analysis
    sbc_enabled = (config_value >> 0) & 1
    sbc_locked = (config_value >> 1) & 1
    
    analysis["security_features"] = {
        "secure_boot_chain": {
            "enabled": sbc_enabled,
            "locked": sbc_locked,
            "status": "LOCKED" if (sbc_enabled and sbc_locked) else 
                       "UNLOCKED" if sbc_enabled else "DISABLED"
        },
        "vulnerable_to_bl2_ext_bypass": not (sbc_enabled and sbc_locked),
        "da_extensions_allowed": (config_value >> 5) & 1 == 1
    }
    
    return analysis


def print_report(analysis: dict):
    """Print seccfg status report."""
    
    print("=" * 60)
    print("MediaTek seccfg Status Report")
    print("=" * 60)
    print()
    
    print(f"Target Configuration: {analysis['hex_value']}")
    print()
    
    # Security features
    print("Security Features:")
    print("-" * 40)
    
    sbc = analysis["security_features"]["secure_boot_chain"]
    print(f"  Secure Boot Chain: {sbc['status']}")
    print(f"    - Enabled: {sbc['enabled']}")
    print(f"    - Locked: {sbc['locked']}")
    print()
    
    vuln = analysis["security_features"]["vulnerable_to_bl2_ext_bypass"]
    vuln_status = "YES (VULNERABLE)" if vuln else "NO (Protected)"
    print(f"  Vulnerable to bl2_ext bypass: {vuln_status}")
    print()
    
    da_ext = analysis["security_features"]["da_extensions_allowed"]
    print(f"  DA Extensions Allowed: {da_ext}")
    print()
    
    # Bitfield details
    print("Bitfield Analysis:")
    print("-" * 40)
    
    for bit_name, bit_info in analysis["bits"].items():
        status = "✓" if bit_info["enabled"] else "✗"
        print(f"  {status} {bit_name}: {bit_info['description']}")
    
    print()
    
    # Recommendations
    print("Recommendations:")
    print("-" * 40)
    
    if vuln:
        print("  ⚠ Device may be vulnerable to bl2_ext secure boot bypass")
        print("  - Verify boot logs for img_auth_required = 0")
        print("  - Check if seccfg can be locked")
        print("  - Consider firmware update if available")
    else:
        print("  ✓ Secure boot chain appears to be properly locked")
        print("  - bl2_ext bypass should not be possible via this vector")
        print("  - Other vulnerabilities may still exist")
    
    if da_ext:
        print("  ⚠ DA extensions are allowed - partition readback possible")
        print("  - Use Penumbra or similar tools for analysis")
    
    print()
    print("=" * 60)


def main():
    """Main entry point."""
    
    parser = argparse.ArgumentParser(
        description="Check MediaTek seccfg status from DA output"
    )
    parser.add_argument(
        "input",
        nargs="?",
        help="Input file (JSON) or use --target-config"
    )
    parser.add_argument(
        "--target-config",
        type=lambda x: int(x, 0),
        help="Target configuration value (hex or decimal)"
    )
    
    args = parser.parse_args()
    
    # Get config value
    if args.target_config is not None:
        config_value = args.target_config
    elif args.input:
        # Read from JSON file
        filepath = Path(args.input)
        if not filepath.exists():
            print(f"Error: File not found: {filepath}", file=sys.stderr)
            sys.exit(1)
        
        data = json.loads(filepath.read_text())
        
        # Try common field names
        config_value = data.get("target_config") or \
                      data.get("dev_info", {}).get("target_config") or \
                      data.get("cfg")
        
        if config_value is None:
            print("Error: Could not find target_config in input", file=sys.stderr)
            sys.exit(1)
    else:
        parser.print_help()
        sys.exit(1)
    
    # Analyze and report
    analysis = parse_target_config(config_value)
    print_report(analysis)
    
    # Output JSON
    print("\n# JSON Output")
    print(json.dumps(analysis, indent=2))


if __name__ == "__main__":
    main()
