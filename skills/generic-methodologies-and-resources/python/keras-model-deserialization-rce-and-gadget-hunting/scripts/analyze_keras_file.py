#!/usr/bin/env python3
"""
Analyze .keras model files for security assessment.

Usage:
    python scripts/analyze_keras_file.py MODEL_FILE.keras [--extract-config]

This script inspects .keras file structure, extracts config.json,
and identifies potential security concerns.
"""

import argparse
import json
import sys
import zipfile
from pathlib import Path


def analyze_keras_file(filepath, extract_config=False):
    """Analyze a .keras file structure and contents."""
    path = Path(filepath)
    
    if not path.exists():
        print(f"Error: File not found: {filepath}", file=sys.stderr)
        return None
    
    if not path.suffix == ".keras":
        print(f"Warning: File does not have .keras extension", file=sys.stderr)
    
    print(f"Analyzing: {filepath}")
    print(f"File size: {path.stat().st_size:,} bytes")
    print()
    
    try:
        with zipfile.ZipFile(path, 'r') as zf:
            # List all files in archive
            print("Archive contents:")
            files = zf.namelist()
            for f in sorted(files):
                info = zf.getinfo(f)
                print(f"  {f} ({info.file_size:,} bytes)")
            print()
            
            # Extract and analyze config.json
            if "config.json" in files:
                print("=== config.json ===")
                with zf.open("config.json") as f:
                    config = json.load(f)
                
                if extract_config:
                    output_path = path.with_suffix(".config.json")
                    with open(output_path, "w") as out:
                        json.dump(config, out, indent=2)
                    print(f"Extracted config to: {output_path}")
                else:
                    print(json.dumps(config, indent=2)[:2000])
                    if len(json.dumps(config)) > 2000:
                        print("... (truncated)")
                print()
                
                # Security analysis
                print("=== Security Analysis ===")
                analyze_config_security(config)
                
            # Check metadata.json
            if "metadata.json" in files:
                print("=== metadata.json ===")
                with zf.open("metadata.json") as f:
                    metadata = json.load(f)
                print(json.dumps(metadata, indent=2))
                print()
                
    except zipfile.BadZipFile:
        print("Error: Not a valid ZIP archive", file=sys.stderr)
        return None
    except Exception as e:
        print(f"Error analyzing file: {e}", file=sys.stderr)
        return None
    
    return True


def analyze_config_security(config):
    """Analyze config.json for potential security concerns."""
    concerns = []
    
    def check_module(obj, path=""):
        """Recursively check for module/class references."""
        if isinstance(obj, dict):
            # Check for module/class_name pattern
            if "module" in obj and "class_name" in obj:
                module = obj["module"]
                class_name = obj["class_name"]
                
                # Check for non-standard modules
                allowed_modules = ["keras", "keras_hub", "keras_cv", "keras_nlp"]
                if not any(module.startswith(a) for a in allowed_modules):
                    concerns.append({
                        "type": "non_standard_module",
                        "path": path,
                        "module": module,
                        "class_name": class_name,
                        "severity": "warning"
                    })
                
                # Check for Lambda layers (potential gadget surface)
                if class_name == "Lambda":
                    concerns.append({
                        "type": "lambda_layer",
                        "path": path,
                        "module": module,
                        "severity": "info",
                        "note": "Lambda layers can be used for gadget exploitation"
                    })
            
            # Recurse into nested dicts
            for key, value in obj.items():
                check_module(value, f"{path}.{key}")
        
        elif isinstance(obj, list):
            for i, item in enumerate(obj):
                check_module(item, f"{path}[{i}]")
    
    check_module(config)
    
    if concerns:
        for c in concerns:
            severity = c.get("severity", "info").upper()
            print(f"  [{severity}] {c['type']}")
            print(f"           Path: {c['path']}")
            if "module" in c:
                print(f"           Module: {c['module']}")
            if "class_name" in c:
                print(f"           Class: {c['class_name']}")
            if "note" in c:
                print(f"           Note: {c['note']}")
            print()
    else:
        print("  No obvious security concerns detected.")


def main():
    parser = argparse.ArgumentParser(
        description="Analyze .keras model files for security assessment"
    )
    parser.add_argument(
        "model_file",
        help="Path to .keras model file"
    )
    parser.add_argument(
        "--extract-config",
        action="store_true",
        help="Extract config.json to separate file"
    )
    args = parser.parse_args()
    
    success = analyze_keras_file(args.model_file, args.extract_config)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
