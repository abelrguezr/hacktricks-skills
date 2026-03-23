#!/usr/bin/env python3
"""
Data extraction from HTTP responses using regex and JSON parsing.
Usage: python extract_data.py <url> --pattern <regex> | --json <path>
"""

import argparse
import json
import re
import requests
import sys

def extract_regex(text, pattern, group=0):
    """Extract data using regex pattern."""
    try:
        match = re.search(pattern, text, re.DOTALL)
        if match:
            if group == 0:
                return match.group(0)
            else:
                return match.group(group)
    except re.error as e:
        print(f"Regex error: {e}")
        return None
    return None

def extract_json(text, json_path):
    """Extract data from JSON using dot notation path."""
    try:
        data = json.loads(text)
        keys = json_path.split('.')
        for key in keys:
            if isinstance(data, dict):
                data = data.get(key)
            elif isinstance(data, list):
                try:
                    idx = int(key)
                    data = data[idx] if idx < len(data) else None
                except ValueError:
                    return None
            else:
                return None
            if data is None:
                return None
        return data
    except (json.JSONDecodeError, TypeError) as e:
        print(f"JSON error: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description='Extract data from HTTP responses')
    parser.add_argument('url', help='Target URL')
    parser.add_argument('--method', '-m', default='GET',
                       choices=['GET', 'POST'], help='HTTP method')
    parser.add_argument('--data', '-d', help='POST data')
    parser.add_argument('--json', '-j', help='POST JSON data')
    parser.add_argument('--pattern', '-p', help='Regex pattern to extract')
    parser.add_argument('--group', '-g', type=int, default=0,
                       help='Regex capture group (default: 0)')
    parser.add_argument('--json-path', help='JSON path (e.g., data.users.0.name)')
    parser.add_argument('--headers', '-H', action='append',
                       help='Headers (Key:Value)')
    parser.add_argument('--output', '-o', choices=['text', 'json'], default='text',
                       help='Output format')
    parser.add_argument('--all-matches', '-a', action='store_true',
                       help='Return all regex matches')
    
    args = parser.parse_args()
    
    # Make request
    headers = {}
    if args.headers:
        for h in args.headers:
            if ':' in h:
                key, value = h.split(':', 1)
                headers[key.strip()] = value.strip()
    
    try:
        if args.method == 'GET':
            response = requests.get(args.url, headers=headers, timeout=30)
        else:
            if args.json:
                response = requests.post(args.url, json=json.loads(args.json), 
                                       headers=headers, timeout=30)
            else:
                response = requests.post(args.url, data=args.data,
                                       headers=headers, timeout=30)
        
        text = response.text
        
        # Extract data
        if args.pattern:
            if args.all_matches:
                matches = re.findall(args.pattern, text, re.DOTALL)
                results = matches
            else:
                result = extract_regex(text, args.pattern, args.group)
                results = [result] if result else []
        elif args.json_path:
            result = extract_json(text, args.json_path)
            results = [result] if result else []
        else:
            print("Error: Must specify --pattern or --json-path")
            sys.exit(1)
        
        # Output results
        if args.output == 'json':
            print(json.dumps(results, indent=2, default=str))
        else:
            for i, r in enumerate(results):
                if r:
                    print(f"Match {i+1}: {r}")
            if not results:
                print("No matches found")
        
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
