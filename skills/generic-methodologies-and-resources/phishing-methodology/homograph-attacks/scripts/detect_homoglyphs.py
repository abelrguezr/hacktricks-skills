#!/usr/bin/env python3
"""
Homoglyph/Homograph Attack Detector

Detects mixed scripts and character substitutions in text fields.
Useful for analyzing phishing emails, URLs, and domains.
"""

import argparse
import json
import sys
import unicodedata as ud
from collections import defaultdict
from email import policy
from email.parser import BytesParser
from pathlib import Path


def get_unicode_info(char: str) -> dict:
    """Get Unicode information for a character."""
    if char.isascii():
        return {
            "char": char,
            "codepoint": f"U+{ord(char):04X}",
            "name": "ASCII",
            "block": "Latin",
            "is_ascii": True
        }
    
    try:
        name = ud.name(char, 'UNKNOWN')
        block = name.split(' ')[0]  # e.g., 'CYRILLIC', 'GREEK'
    except ValueError:
        name = 'UNKNOWN'
        block = 'UNKNOWN'
    
    return {
        "char": char,
        "codepoint": f"U+{ord(char):04X}",
        "name": name,
        "block": block,
        "is_ascii": False
    }


def analyze_field(field_name: str, value: str) -> dict:
    """Analyze a single field for homoglyph attacks."""
    if not value:
        return {
            "field": field_name,
            "value": value,
            "has_mixed_scripts": False,
            "has_non_latin": False,
            "blocks": {},
            "characters": [],
            "suspicious": False,
            "reason": "Empty field"
        }
    
    blocks = defaultdict(int)
    characters = []
    
    for char in value:
        info = get_unicode_info(char)
        characters.append(info)
        
        if info["is_ascii"]:
            blocks["Latin"] += 1
        else:
            blocks[info["block"]] += 1
    
    has_mixed_scripts = len(blocks) > 1
    has_non_latin = any(block != "Latin" for block in blocks.keys())
    
    # Determine if suspicious
    suspicious = has_mixed_scripts or has_non_latin
    reason = []
    if has_mixed_scripts:
        reason.append(f"Mixed scripts detected: {', '.join(blocks.keys())}")
    if has_non_latin:
        non_latin_blocks = [b for b in blocks.keys() if b != "Latin"]
        reason.append(f"Non-Latin scripts present: {', '.join(non_latin_blocks)}")
    
    return {
        "field": field_name,
        "value": value,
        "has_mixed_scripts": has_mixed_scripts,
        "has_non_latin": has_non_latin,
        "blocks": dict(blocks),
        "characters": characters,
        "suspicious": suspicious,
        "reason": "; ".join(reason) if reason else "Clean"
    }


def analyze_email_file(email_path: str) -> dict:
    """Analyze an email file for homoglyph attacks."""
    path = Path(email_path)
    if not path.exists():
        raise FileNotFoundError(f"Email file not found: {email_path}")
    
    with open(path, 'rb') as f:
        email = BytesParser(policy=policy.default).parse(f)
    
    fields_to_check = {
        "display_name": email.get("From", ""),
        "subject": email.get("Subject", ""),
        "sender": email.get("Sender", ""),
        "to": email.get("To", ""),
    }
    
    results = {}
    for field_name, value in fields_to_check.items():
        if value:
            results[field_name] = analyze_field(field_name, value)
    
    return results


def print_analysis(result: dict):
    """Print analysis results in a readable format."""
    field = result["field"]
    value = result["value"]
    suspicious = result["suspicious"]
    
    status = "[!] SUSPICIOUS" if suspicious else "[✓] Clean"
    print(f"\n{status}: {field}")
    print(f"  Value: {value}")
    
    if suspicious:
        print(f"  Reason: {result['reason']}")
        print(f"  Script breakdown: {result['blocks']}")
    
    # Show non-ASCII characters
    non_ascii = [c for c in result["characters"] if not c["is_ascii"]]
    if non_ascii:
        print(f"  Non-ASCII characters ({len(non_ascii)}):")
        for char_info in non_ascii:
            print(f"    '{char_info['char']}' = {char_info['codepoint']} ({char_info['name']})")


def main():
    parser = argparse.ArgumentParser(
        description="Detect homoglyph/homograph attacks in text fields",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --field "display_name" --value "Ηеlрdеѕk"
  %(prog)s --email-file suspicious.eml
  %(prog)s --json '{"subject": "Urgеnt Аctіon", "url": "https://example.com"}'
        """
    )
    
    parser.add_argument(
        "--field", "-f",
        help="Name of the field to analyze (e.g., 'display_name', 'subject')"
    )
    parser.add_argument(
        "--value", "-v",
        help="Value to analyze"
    )
    parser.add_argument(
        "--email-file", "-e",
        help="Path to email file (.eml) to analyze"
    )
    parser.add_argument(
        "--json", "-j",
        help="JSON object with field names and values to analyze"
    )
    parser.add_argument(
        "--output-json", "-o",
        action="store_true",
        help="Output results as JSON"
    )
    
    args = parser.parse_args()
    
    # Validate arguments
    if not any([args.field, args.email_file, args.json]):
        parser.print_help()
        sys.exit(1)
    
    results = {}
    
    # Analyze single field
    if args.field and args.value:
        results[args.field] = analyze_field(args.field, args.value)
    
    # Analyze email file
    if args.email_file:
        try:
            results = analyze_email_file(args.email_file)
        except FileNotFoundError as e:
            print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Analyze JSON input
    if args.json:
        try:
            data = json.loads(args.json)
            for field_name, value in data.items():
                results[field_name] = analyze_field(field_name, str(value))
        except json.JSONDecodeError as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Output results
    if args.output_json:
        print(json.dumps(results, indent=2, ensure_ascii=False))
    else:
        for result in results.values():
            print_analysis(result)
        
        # Summary
        suspicious_count = sum(1 for r in results.values() if r["suspicious"])
        print(f"\n{'='*50}")
        print(f"Summary: {suspicious_count}/{len(results)} fields flagged as suspicious")
        if suspicious_count > 0:
            print("[!] Review flagged fields for potential homoglyph attacks")


if __name__ == "__main__":
    main()
