#!/usr/bin/env python3
"""Parse Discord cache f_* entries to extract HTTP headers and body content."""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime


def parse_f_entry(file_path):
    """Parse an f_* cache entry, separating headers from body."""
    result = {
        "file_path": str(file_path),
        "file_size": file_path.stat().st_size,
        "modified_time": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat(),
        "headers": {},
        "body_size": 0,
        "content_type": None,
        "content_encoding": None,
        "original_url": None,
        "parse_status": "success"
    }
    
    try:
        with open(file_path, 'rb') as f:
            content = f.read()
        
        # Find header/body boundary (\r\n\r\n)
        header_end = content.find(b'\r\n\r\n')
        
        if header_end == -1:
            result["parse_status"] = "no_header_boundary"
            result["body_size"] = len(content)
            return result
        
        header_bytes = content[:header_end]
        body_bytes = content[header_end + 4:]
        
        result["body_size"] = len(body_bytes)
        
        # Parse headers
        try:
            header_text = header_bytes.decode('utf-8', errors='replace')
            for line in header_text.split('\r\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    result["headers"][key.strip().lower()] = value.strip()
        except Exception as e:
            result["parse_status"] = f"header_parse_error: {e}"
        
        # Extract key headers
        result["content_type"] = result["headers"].get("content-type")
        result["content_encoding"] = result["headers"].get("content-encoding")
        result["original_url"] = result["headers"].get("content-location") or result["headers"].get("x-original-url")
        
    except Exception as e:
        result["parse_status"] = f"error: {e}"
    
    return result


def main():
    parser = argparse.ArgumentParser(description='Parse Discord cache f_* entries')
    parser.add_argument('--cache', required=True, help='Path to Cache_Data directory')
    parser.add_argument('--output', required=True, help='Output directory for parsed results')
    args = parser.parse_args()
    
    cache_dir = Path(args.cache)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    if not cache_dir.exists():
        print(f"Error: Cache directory not found: {cache_dir}")
        sys.exit(1)
    
    print(f"Parsing Discord cache entries from: {cache_dir}")
    print(f"Output directory: {output_dir}")
    print()
    
    # Find all f_* files
    f_files = list(cache_dir.glob('f_*'))
    print(f"Found {len(f_files)} f_* files to parse")
    
    results = []
    
    for f_file in f_files:
        result = parse_f_entry(f_file)
        results.append(result)
    
    # Write JSON results
    json_output = output_dir / 'parsed_entries.json'
    with open(json_output, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nParsed entries saved to: {json_output}")
    
    # Write CSV summary
    csv_output = output_dir / 'parsed_entries.csv'
    with open(csv_output, 'w') as f:
        f.write('file_path,modified_time,file_size,body_size,content_type,content_encoding,original_url,parse_status\n')
        for r in results:
            # Escape commas in fields
            original_url = (r.get('original_url') or '').replace(',', ';')
            f.write(f"{r['file_path']},{r['modified_time']},{r['file_size']},{r['body_size']},{r.get('content_type') or ''},{r.get('content_encoding') or ''},{original_url},{r['parse_status']}\n")
    print(f"CSV summary saved to: {csv_output}")
    
    # Summary statistics
    print("\n=== Parse Summary ===")
    print(f"Total files: {len(results)}")
    print(f"Successfully parsed: {sum(1 for r in results if r['parse_status'] == 'success')}")
    print(f"With content-type: {sum(1 for r in results if r.get('content_type'))}")
    print(f"With original URL: {sum(1 for r in results if r.get('original_url'))}")
    
    # List files with webhooks
    webhook_files = [r for r in results if r.get('original_url') and 'webhooks' in r['original_url']]
    if webhook_files:
        print(f"\n[*] Found {len(webhook_files)} files with webhook URLs:")
        for wf in webhook_files[:5]:  # Show first 5
            print(f"    {wf['file_path']}: {wf['original_url']}")
        if len(webhook_files) > 5:
            print(f"    ... and {len(webhook_files) - 5} more")


if __name__ == '__main__':
    main()
