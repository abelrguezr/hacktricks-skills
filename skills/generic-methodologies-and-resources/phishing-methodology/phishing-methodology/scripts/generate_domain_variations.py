#!/usr/bin/env python3
"""
Generate domain variations for phishing assessment testing.
Usage: python generate_domain_variations.py <target-domain>
"""

import sys
import re

def generate_variations(domain):
    """Generate various domain name variations."""
    variations = set()
    
    # Remove TLD for processing
    parts = domain.rsplit('.', 1)
    if len(parts) == 2:
        name, tld = parts
    else:
        name = domain
        tld = 'com'
    
    # 1. Keyword variations
    variations.add(f"{name}-management.{tld}")
    variations.add(f"{name}-portal.{tld}")
    variations.add(f"secure-{name}.{tld}")
    variations.add(f"{name}-login.{tld}")
    
    # 2. Hyphenated subdomain
    if '.' in name:
        subdomain = name.split('.')[0]
        variations.add(f"{subdomain}-{name.split('.')[1]}.{tld}")
    
    # 3. New TLDs
    for new_tld in ['org', 'net', 'io', 'co', 'info', 'biz']:
        variations.add(f"{name}.{new_tld}")
    
    # 4. Homoglyphs (similar-looking characters)
    homoglyphs = {
        'a': ['@', '4'],
        'e': ['3'],
        'i': ['1', 'l'],
        'o': ['0'],
        's': ['5', '$'],
        't': ['7'],
        'l': ['1', 'i'],
    }
    for char, replacements in homoglyphs.items():
        if char in name:
            for replacement in replacements:
                variations.add(name.replace(char, replacement, 1) + '.' + tld)
    
    # 5. Transposition (swap adjacent letters)
    for i in range(len(name) - 1):
        swapped = name[:i] + name[i+1] + name[i] + name[i+2:]
        variations.add(f"{swapped}.{tld}")
    
    # 6. Pluralization
    if not name.endswith('s'):
        variations.add(f"{name}s.{tld}")
    elif name.endswith('s'):
        variations.add(f"{name[:-1]}.{tld}")
    
    # 7. Omission (remove one letter)
    for i in range(len(name)):
        omitted = name[:i] + name[i+1:]
        variations.add(f"{omitted}.{tld}")
    
    # 8. Repetition (repeat one letter)
    for i in range(len(name)):
        repeated = name[:i] + name[i] + name[i:]
        variations.add(f"{repeated}.{tld}")
    
    # 9. Insertion (add common letters)
    for letter in ['e', 'o', 'a', 'i', 'u']:
        for i in range(len(name) + 1):
            inserted = name[:i] + letter + name[i:]
            variations.add(f"{inserted}.{tld}")
    
    # 10. Missing dot
    variations.add(f"{name}{tld}.{tld}")
    
    # 11. Subdomained (insert dot)
    for i in range(1, len(name) - 1):
        subdomained = name[:i] + '.' + name[i:]
        variations.add(f"{subdomained}.{tld}")
    
    return sorted(variations)

def main():
    if len(sys.argv) != 2:
        print("Usage: python generate_domain_variations.py <target-domain>")
        print("Example: python generate_domain_variations.py example.com")
        sys.exit(1)
    
    target = sys.argv[1].lower().strip()
    
    # Validate domain format
    if not re.match(r'^[a-z0-9.-]+\.[a-z]{2,}$', target):
        print("Invalid domain format")
        sys.exit(1)
    
    print(f"\nDomain variations for: {target}")
    print("=" * 60)
    
    variations = generate_variations(target)
    
    for i, var in enumerate(variations, 1):
        print(f"{i:3d}. {var}")
    
    print(f"\nTotal variations: {len(variations)}")
    print("\nNote: Only use these for authorized security assessments.")

if __name__ == "__main__":
    main()
