#!/usr/bin/env python3
"""
Identify esoteric languages from code snippets.
Useful for CTF challenges where the language is not specified.
"""

import sys
import re
from pathlib import Path

# Extended esolang patterns
ESOLANG_PATTERNS = {
    "brainfuck": {
        "pattern": r'^[\+\-<>.,\[\]\s]*$',
        "description": "Brainfuck - uses + - < > . , [ ]",
        "confidence": "high"
    },
    "malbolge": {
        "pattern": r'[defghijklmnopqrstuvwxyz0123456789()\[\]{}*]',
        "description": "Malbolge - complex character set with unusual operators",
        "confidence": "medium"
    },
    "whitespace": {
        "pattern": r'^[ \t\n]*$',
        "description": "Whitespace - only spaces, tabs, and newlines",
        "confidence": "high"
    },
    "piet": {
        "pattern": r'\.(png|jpg|jpeg|gif)$',
        "description": "Piet - image-based esolang",
        "confidence": "high"
    },
    "ook": {
        "pattern": r'\bOok[.!?]\b',
        "description": "Ook! - uses Ook. Ook? Ook! Ook.",
        "confidence": "high"
    },
    "lolcode": {
        "pattern": r'\b(HAI|VISIBLE|KTHXBYE|I HAS A|GIMMEH|BOTH OF|DIFF OF|SUM OF|PRODUCT OF|MOD OF|SMALLER OF|BIGGER OF|GTE|LTE|GT|LT|NOR|AND|OR|NOT|UPPER|LOWER|SIZE|SUB|REPL|NIN|YENS|HOW IZ|GUESS I|IM IN Y|IM NOT IN Y|IM IN|IM NOT IN|IM IN Y|IM NOT IN Y|IM IN|IM NOT IN|IM IN Y|IM NOT IN Y|IM IN|IM NOT IN)\b',
        "description": "LOLCODE - uses HAI, VISIBLE, KTHXBYE, etc.",
        "confidence": "high"
    },
    "unary": {
        "pattern": r'^[a-zA-Z0-9]{10,}$',
        "description": "Unary - single character repeated many times",
        "confidence": "low"
    },
    "intercal": {
        "pattern": r'\b(DO|PLEASE|COMPUTE|GIVE|READ|WRITE|FORGET|STOR|COMB|SEPAR|SCHEM|SCHEM|SCHEM)\b',
        "description": "INTERCAL - uses DO, PLEASE, COMPUTE, etc.",
        "confidence": "medium"
    },
    "forth": {
        "pattern": r'\b(:|;|\+|\-|\*|/|DROP|DUP|SWAP|OVER|ROT|PUSH|POP|IF|ELSE|THEN|BEGIN|WHILE|REPEAT|AGAIN|UNTIL|DO|LOOP)\b',
        "description": "Forth - stack-based language",
        "confidence": "medium"
    },
    "ruby": {
        "pattern": r'\b(puts|print|def|class|module|if|elsif|else|end|while|until|for|do|break|next|return|yield|super|self|nil|true|false)\b',
        "description": "Ruby - might be a normal Ruby script",
        "confidence": "low"
    },
    "python": {
        "pattern": r'\b(print|def|class|if|elif|else|while|for|in|import|from|return|yield|lambda|True|False|None|and|or|not|is|as|with|try|except|finally|raise|assert|pass|break|continue|global|nonlocal|del|exec|eval|input|open|range|len|str|int|float|list|dict|set|tuple)\b',
        "description": "Python - might be a normal Python script",
        "confidence": "low"
    },
}

def identify_language(code: str, filename: str = None) -> list:
    """Identify potential languages from code."""
    matches = []
    
    # Check filename extension
    if filename:
        ext = Path(filename).suffix.lower()
        if ext == '.png' or ext == '.jpg' or ext == '.jpeg' or ext == '.gif':
            matches.append({
                "language": "piet",
                "reason": "Image file - likely Piet esolang",
                "confidence": "high"
            })
    
    # Check patterns
    for lang, info in ESOLANG_PATTERNS.items():
        if re.search(info["pattern"], code, re.MULTILINE):
            matches.append({
                "language": lang,
                "reason": info["description"],
                "confidence": info["confidence"]
            })
    
    return matches

def main():
    if len(sys.argv) < 2:
        print("Usage: python identify_esolang.py <code_or_file>")
        print("  If argument is a file, reads from file")
        print("  If argument is code, uses it directly")
        sys.exit(1)
    
    arg = sys.argv[1]
    filename = None
    
    # Check if it's a file
    if Path(arg).exists():
        filename = arg
        with open(arg, 'r', errors='ignore') as f:
            code = f.read()
    else:
        code = arg
    
    matches = identify_language(code, filename)
    
    if matches:
        print("Identified potential languages:")
        for match in matches:
            print(f"  - {match['language']} ({match['confidence']} confidence)")
            print(f"    Reason: {match['reason']}")
        
        # Suggest next steps
        print("\nNext steps:")
        print("  1. Search for '[language] online interpreter'")
        print("  2. Try running with Docker: docker run -i [language] < code")
        print("  3. Check esolangs.org for more information")
    else:
        print("No matching esolangs found.")
        print("\nSuggestions:")
        print("  1. Copy distinctive tokens and search on Google")
        print("  2. Check esolangs.org/wiki/Main_Page")
        print("  3. Look for unusual characters or patterns")

if __name__ == "__main__":
    main()
