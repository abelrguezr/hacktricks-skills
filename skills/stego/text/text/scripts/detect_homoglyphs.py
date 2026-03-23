#!/usr/bin/env python3
"""Detect Unicode homoglyphs in text.

Homoglyphs are different Unicode codepoints that render identically.
Common in steganography: Latin vs Cyrillic, Greek, etc.

Usage:
    python3 detect_homoglyphs.py < suspicious_text.txt
    cat file.txt | python3 detect_homoglyphs.py
"""

import sys

# Common homoglyph mappings (Latin -> lookalikes)
HOMOGLYPH_MAP = {
    'a': [('а', 'Cyrillic Small Letter A', 'U+0430'),
          ('а', 'Cyrillic Small Letter A', 'U+0430')],
    'b': [('Ь', 'Cyrillic Capital Letter Short I', 'U+042B')],
    'c': [('с', 'Cyrillic Small Letter Es', 'U+0441')],
    'e': [('е', 'Cyrillic Small Letter Ie', 'U+0435'),
          ('ε', 'Greek Small Letter Epsilon', 'U+03B5')],
    'h': [('һ', 'Cyrillic Small Letter Shha', 'U+04B9')],
    'i': [('і', 'Cyrillic Small Letter Short I', 'U+0456'),
          ('ι', 'Greek Small Letter Iota', 'U+03B9')],
    'k': [('к', 'Cyrillic Small Letter Ka', 'U+043A')],
    'm': [('m', 'Cyrillic Small Letter Em', 'U+043C')],
    'n': [('n', 'Cyrillic Small Letter En', 'U+043D')],
    'o': [('о', 'Cyrillic Small Letter O', 'U+043E'),
          ('ο', 'Greek Small Letter Omicron', 'U+03BF')],
    'p': [('р', 'Cyrillic Small Letter Er', 'U+0440'),
          ('ρ', 'Greek Small Letter Rho', 'U+03C1')],
    's': [('ѕ', 'Cyrillic Small Letter Dze', 'U+0455')],
    't': [('т', 'Cyrillic Small Letter Te', 'U+0442')],
    'x': [('х', 'Cyrillic Small Letter Ha', 'U+0445')],
    'y': [('у', 'Cyrillic Small Letter U', 'U+0443'),
          ('γ', 'Greek Small Letter Gamma', 'U+03B3')],
    'A': [('А', 'Cyrillic Capital Letter A', 'U+0410')],
    'B': [('В', 'Cyrillic Capital Letter Ve', 'U+0412')],
    'E': [('Е', 'Cyrillic Capital Letter Ie', 'U+0415'),
          ('Ε', 'Greek Capital Letter Epsilon', 'U+0395')],
    'H': [('Н', 'Cyrillic Capital Letter En', 'U+041D')],
    'K': [('К', 'Cyrillic Capital Letter Ka', 'U+041A')],
    'M': [('М', 'Cyrillic Capital Letter Em', 'U+041C')],
    'O': [('О', 'Cyrillic Capital Letter O', 'U+041E'),
          ('Ο', 'Greek Capital Letter Omicron', 'U+039F')],
    'P': [('Р', 'Cyrillic Capital Letter Er', 'U+0420'),
          ('Ρ', 'Greek Capital Letter Rho', 'U+03A1')],
    'C': [('С', 'Cyrillic Capital Letter Es', 'U+0421')],
    'T': [('Т', 'Cyrillic Capital Letter Te', 'U+0422')],
    'X': [('Х', 'Cyrillic Capital Letter Ha', 'U+0425')],
    'Y': [('У', 'Cyrillic Capital Letter U', 'U+0423'),
          ('Υ', 'Greek Capital Letter Upsilon', 'U+03A5')],
}

def find_homoglyphs(text):
    """Find homoglyph characters in text."""
    findings = []
    
    for i, ch in enumerate(text):
        # Check if this character is a homoglyph of any Latin character
        for latin_char, lookalikes in HOMOGLYPH_MAP.items():
            for lookalike_char, name, codepoint in lookalikes:
                if ch == lookalike_char:
                    findings.append({
                        'position': i,
                        'character': ch,
                        'codepoint': codepoint,
                        'name': name,
                        'looks_like': latin_char
                    })
                    break
    
    return findings

def main():
    # Read text from stdin
    text = sys.stdin.read()
    
    if not text:
        print("No input received. Pipe text to this script or use < file.txt")
        sys.exit(1)
    
    # Find homoglyphs
    findings = find_homoglyphs(text)
    
    if not findings:
        print("No homoglyphs detected in the text")
        print("(Note: This only checks for common Latin/Cyrillic/Greek homoglyphs)")
        sys.exit(0)
    
    print(f"Found {len(findings)} homoglyph character(s):")
    print("-" * 70)
    print(f"{'Position':<10} {'Character':<10} {'Codepoint':<12} {'Looks Like':<12} {'Name'}")
    print("-" * 70)
    
    for f in findings:
        print(f"{f['position']:<10} {repr(f['character']):<10} {f['codepoint']:<12} {f['looks_like']:<12} {f['name']}")
    
    # Extract hidden data if homoglyphs form a pattern
    print("\n" + "=" * 70)
    print("Potential hidden data extraction:")
    
    # Try extracting the "looks like" characters
    hidden_text = ''.join(f['looks_like'] for f in findings)
    print(f"  Extracted as Latin: {hidden_text}")
    
    # Try extracting codepoint values
    codepoints = [f['codepoint'] for f in findings]
    print(f"  Codepoints: {', '.join(codepoints)}")

if __name__ == "__main__":
    main()
