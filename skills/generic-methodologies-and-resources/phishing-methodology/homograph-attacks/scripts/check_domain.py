#!/usr/bin/env python3
"""
Domain Homoglyph Checker

Analyzes domains for homoglyph attacks and punycode encoding.
Generates visually-similar domain variants for security testing.
"""

import argparse
import sys
import unicodedata as ud
from collections import defaultdict

try:
    import idna
except ImportError:
    print("Error: idna library required. Install with: pip install idna")
    sys.exit(1)


# Common homoglyph mappings (Latin -> lookalikes)
HOMOGlyph_MAP = {
    'A': ['Α', 'А', 'А'],  # Greek Alpha, Cyrillic A
    'B': ['В', 'Β'],       # Cyrillic Ve, Greek Beta
    'C': ['С'],            # Cyrillic Es
    'E': ['Е', 'Ε'],       # Cyrillic Ye, Greek Epsilon
    'H': ['Η'],            # Greek Eta
    'K': ['К'],            # Cyrillic Ka
    'M': ['М'],            # Cyrillic Em
    'N': ['Н'],            # Cyrillic En
    'O': ['О', 'Ο', 'օ'],  # Cyrillic O, Greek Omicron, Armenian O
    'P': ['Р', 'Ρ'],       # Cyrillic Er, Greek Rho
    'C': ['С'],            # Cyrillic Es
    'T': ['Т', 'Ꭲ'],       # Cyrillic Te, Cherokee T
    'X': ['Х'],            # Cyrillic Ha
    'Y': ['У', 'Υ'],       # Cyrillic U, Greek Upsilon
    'a': ['а', 'α'],       # Cyrillic a, Greek alpha
    'b': ['в', 'β'],       # Cyrillic v, Greek beta
    'c': ['с'],            # Cyrillic es
    'e': ['е', 'ε'],       # Cyrillic ye, Greek epsilon
    'h': ['η'],            # Greek eta
    'k': ['к'],            # Cyrillic ka
    'm': ['м'],            # Cyrillic em
    'n': ['н'],            # Cyrillic en
    'o': ['о', 'ο', 'օ'],  # Cyrillic o, Greek omicron, Armenian o
    'p': ['р', 'ρ'],       # Cyrillic er, Greek rho
    'r': ['ɹ', 'ɾ'],       # Latin small capital r, Latin small letter r
    's': ['ѕ', 'ѕ'],       # Cyrillic dze
    't': ['т', 'Ꭲ'],       # Cyrillic te, Cherokee t
    'x': ['х'],            # Cyrillic ha
    'y': ['у', 'υ'],       # Cyrillic u, Greek upsilon
    '0': ['0', '۰'],       # Arabic-Indic digit zero
    '1': ['1', '۱'],       # Arabic-Indic digit one
    '2': ['2', '۲'],       # Arabic-Indic digit two
    '3': ['3', '۳'],       # Arabic-Indic digit three
    '4': ['4', '۴'],       # Arabic-Indic digit four
    '5': ['5', '۵'],       # Arabic-Indic digit five
    '6': ['6', '۶'],       # Arabic-Indic digit six
    '7': ['7', '۷'],       # Arabic-Indic digit seven
    '8': ['8', '۸'],       # Arabic-Indic digit eight
    '9': ['9', '۹'],       # Arabic-Indic digit nine
}


def get_domain_info(domain: str) -> dict:
    """Get detailed information about a domain."""
    result = {
        "original": domain,
        "is_punycode": domain.startswith("xn--"),
        "punycode": None,
        "unicode": None,
        "has_homoglyphs": False,
        "homoglyph_details": [],
        "script_breakdown": {}
    }
    
    # Check for punycode
    if result["is_punycode"]:
        try:
            result["unicode"] = idna.decode(domain)
        except Exception as e:
            result["unicode"] = f"Error decoding: {e}"
    else:
        # Try to encode to punycode
        try:
            result["punycode"] = idna.encode(domain).decode()
        except Exception as e:
            result["punycode"] = f"Error encoding: {e}"
    
    # Analyze characters
    blocks = defaultdict(int)
    for char in domain:
        if char.isascii() and char != '.':
            blocks["Latin"] += 1
        elif char == '.':
            blocks["Separator"] += 1
        else:
            try:
                name = ud.name(char, 'UNKNOWN')
                block = name.split(' ')[0]
                blocks[block] += 1
                
                # Check if this is a known homoglyph
                if char in [v for sublist in HOMOGlyph_MAP.values() for v in sublist]:
                    # Find which Latin char it resembles
                    for latin, lookalikes in HOMOGlyph_MAP.items():
                        if char in lookalikes:
                            result["homoglyph_details"].append({
                                "char": char,
                                "codepoint": f"U+{ord(char):04X}",
                                "resembles": latin,
                                "script": block
                            })
                            result["has_homoglyphs"] = True
                            break
            except ValueError:
                pass
    
    result["script_breakdown"] = dict(blocks)
    return result


def generate_homoglyph_variants(domain: str) -> list:
    """Generate visually-similar domain variants."""
    variants = []
    
    # Split domain into parts
    parts = domain.split('.')
    
    # Generate variants for each character in each part
    for part_idx, part in enumerate(parts):
        for char_idx, char in enumerate(part):
            if char in HOMOGlyph_MAP:
                for lookalike in HOMOGlyph_MAP[char]:
                    if lookalike != char:  # Skip if same character
                        new_part = part[:char_idx] + lookalike + part[char_idx+1:]
                        new_domain = '.'.join(parts[:part_idx] + [new_part] + parts[part_idx+1:])
                        variants.append({
                            "domain": new_domain,
                            "substitution": f"{char} -> {lookalike}",
                            "position": f"part {part_idx+1}, char {char_idx+1}"
                        })
    
    return variants


def print_domain_info(info: dict):
    """Print domain analysis in a readable format."""
    print(f"\n{'='*60}")
    print(f"Domain Analysis: {info['original']}")
    print(f"{'='*60}")
    
    print(f"\nOriginal: {info['original']}")
    
    if info['is_punycode']:
        print(f"Status: Punycode encoded (IDN)")
        print(f"Decoded: {info['unicode']}")
    else:
        print(f"Status: ASCII domain")
        print(f"Punycode: {info['punycode']}")
    
    print(f"\nScript breakdown: {info['script_breakdown']}")
    
    if info['has_homoglyphs']:
        print(f"\n[!] HOMOGlyph DETECTED!")
        print(f"Suspicious characters:")
        for detail in info['homoglyph_details']:
            print(f"  '{detail['char']}' ({detail['codepoint']}) resembles '{detail['resembles']}' from {detail['script']} script")
    else:
        print(f"\n[✓] No obvious homoglyphs detected")


def print_variants(variants: list, limit: int = 20):
    """Print generated variants."""
    print(f"\n{'='*60}")
    print(f"Generated Homoglyph Variants (showing {min(len(variants), limit)} of {len(variants)})")
    print(f"{'='*60}")
    
    for i, variant in enumerate(variants[:limit], 1):
        print(f"{i:3}. {variant['domain']:<50} [{variant['substitution']}]")
    
    if len(variants) > limit:
        print(f"\n... and {len(variants) - limit} more variants")


def main():
    parser = argparse.ArgumentParser(
        description="Check domains for homoglyph attacks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --domain "Paypal.com"
  %(prog)s --domain "Ρаypal.com" --analyze
  %(prog)s --domain "paypal.com" --generate-variants
        """
    )
    
    parser.add_argument(
        "--domain", "-d",
        required=True,
        help="Domain to analyze"
    )
    parser.add_argument(
        "--analyze", "-a",
        action="store_true",
        help="Analyze domain for homoglyphs (default)"
    )
    parser.add_argument(
        "--generate-variants", "-g",
        action="store_true",
        help="Generate homoglyph variants of the domain"
    )
    parser.add_argument(
        "--output-json", "-o",
        action="store_true",
        help="Output results as JSON"
    )
    parser.add_argument(
        "--variant-limit", "-l",
        type=int,
        default=20,
        help="Maximum variants to display (default: 20)"
    )
    
    args = parser.parse_args()
    
    # Analyze domain
    info = get_domain_info(args.domain)
    
    if args.output_json:
        result = {"analysis": info}
        if args.generate_variants:
            result["variants"] = generate_homoglyph_variants(args.domain)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        if args.analyze or not args.generate_variants:
            print_domain_info(info)
        
        if args.generate_variants:
            variants = generate_homoglyph_variants(args.domain)
            print_variants(variants, args.variant_limit)


if __name__ == "__main__":
    main()
