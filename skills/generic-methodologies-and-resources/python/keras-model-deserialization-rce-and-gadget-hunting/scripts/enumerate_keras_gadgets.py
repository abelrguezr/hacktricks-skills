#!/usr/bin/env python3
"""
Enumerate potentially dangerous callables in allowlisted Keras modules.

Usage:
    python scripts/enumerate_keras_gadgets.py [--output FILE]

This script walks through keras, keras_nlp, keras_cv, keras_hub and identifies
functions/classes with I/O, network, or process-related side effects.
"""

import argparse
import importlib
import inspect
import json
import pkgutil
import sys

ALLOWLIST = ["keras", "keras_nlp", "keras_cv", "keras_hub"]

# Heuristics for potentially dangerous operations
DANGEROUS_KEYWORDS = [
    "download", "file", "path", "open", "url", "http", "socket",
    "env", "process", "spawn", "exec", "run", "system", "shell",
    "read", "write", "save", "load", "fetch", "request", "connect",
    "import", "compile", "eval", "exec", "marshal", "pickle"
]


def iter_modules(mod):
    """Recursively iterate all submodules of a module."""
    if not hasattr(mod, "__path__"):
        return
    for m in pkgutil.walk_packages(mod.__path__, mod.__name__ + "."):
        yield m.name


def is_dangerous(obj, doc):
    """Check if a callable appears to have dangerous side effects."""
    if not doc:
        return False
    doc_lower = doc.lower()
    return any(keyword in doc_lower for keyword in DANGEROUS_KEYWORDS)


def enumerate_gadgets():
    """Enumerate potentially dangerous callables in allowlisted modules."""
    seen = set()
    candidates = []
    
    for root in ALLOWLIST:
        try:
            r = importlib.import_module(root)
        except Exception as e:
            print(f"Warning: Could not import {root}: {e}", file=sys.stderr)
            continue
        
        for name in iter_modules(r):
            if name in seen:
                continue
            seen.add(name)
            
            try:
                m = importlib.import_module(name)
            except Exception:
                continue
            
            for n, obj in inspect.getmembers(m):
                if not (inspect.isfunction(obj) or inspect.isclass(obj)):
                    continue
                
                # Skip private/internal symbols
                if n.startswith("_"):
                    continue
                
                sig = None
                try:
                    sig = str(inspect.signature(obj))
                except Exception:
                    pass
                
                doc = inspect.getdoc(obj) or ""
                
                if is_dangerous(obj, doc):
                    candidates.append({
                        "module": name,
                        "name": n,
                        "type": "function" if inspect.isfunction(obj) else "class",
                        "signature": sig,
                        "doc": doc[:200] + "..." if len(doc) > 200 else doc,
                        "full_path": f"{name}.{n}"
                    })
    
    return sorted(candidates, key=lambda x: x["full_path"])


def main():
    parser = argparse.ArgumentParser(
        description="Enumerate potentially dangerous callables in Keras modules"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output JSON file (default: stdout)"
    )
    parser.add_argument(
        "--limit", "-l",
        type=int,
        default=200,
        help="Maximum number of results to show (default: 200)"
    )
    args = parser.parse_args()
    
    print("Enumerating Keras gadgets...", file=sys.stderr)
    candidates = enumerate_gadgets()
    
    if args.output:
        with open(args.output, "w") as f:
            json.dump(candidates[:args.limit], f, indent=2)
        print(f"Wrote {len(candidates[:args.limit])} candidates to {args.output}", file=sys.stderr)
    else:
        for c in candidates[:args.limit]:
            print(f"{c['full_path']} {c['signature']}")
            if c['doc']:
                print(f"  {c['doc'][:100]}..." if len(c['doc']) > 100 else f"  {c['doc']}")
            print()
    
    print(f"\nTotal candidates found: {len(candidates)}", file=sys.stderr)


if __name__ == "__main__":
    main()
