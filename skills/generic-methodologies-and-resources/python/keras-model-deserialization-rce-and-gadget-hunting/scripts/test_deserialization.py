#!/usr/bin/env python3
"""
Test crafted config dicts against Keras deserializers.

Usage:
    python scripts/test_deserialization.py --config JSON_STRING
    python scripts/test_deserialization.py --file CONFIG_FILE.json

This script feeds crafted dictionaries directly into Keras deserializers
to learn accepted parameters and observe side effects.
"""

import argparse
import json
import sys


def test_deserialization(config_dict, safe_mode=True):
    """Test a config dict against Keras deserializer."""
    try:
        from keras import layers
        
        print(f"Testing deserialization (safe_mode={safe_mode})...")
        print(f"Config: {json.dumps(config_dict, indent=2)}")
        print()
        
        layer = layers.deserialize(config_dict, safe_mode=safe_mode)
        print(f"✓ Deserialization succeeded")
        print(f"  Layer type: {type(layer).__name__}")
        print(f"  Layer name: {getattr(layer, 'name', 'N/A')}")
        return True, layer
        
    except Exception as e:
        print(f"✗ Deserialization failed: {type(e).__name__}: {e}")
        return False, None


def main():
    parser = argparse.ArgumentParser(
        description="Test crafted config dicts against Keras deserializers"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--config", "-c",
        help="JSON config string to test"
    )
    group.add_argument(
        "--file", "-f",
        help="JSON file containing config to test"
    )
    parser.add_argument(
        "--unsafe",
        action="store_true",
        help="Test with safe_mode=False (use with caution)"
    )
    args = parser.parse_args()
    
    # Load config
    if args.config:
        try:
            config = json.loads(args.config)
        except json.JSONDecodeError as e:
            print(f"Invalid JSON: {e}", file=sys.stderr)
            sys.exit(1)
    else:
        try:
            with open(args.file) as f:
                config = json.load(f)
        except Exception as e:
            print(f"Could not load config file: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Test deserialization
    success, _ = test_deserialization(config, safe_mode=not args.unsafe)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
