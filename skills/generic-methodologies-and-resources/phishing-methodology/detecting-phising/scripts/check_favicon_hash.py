#!/usr/bin/env python3
"""Generate favicon hash for Shodan/ZoomEye/Censys queries.

Usage:
    python check_favicon_hash.py <url>
    python check_favicon_hash.py https://www.paypal.com

Output:
    MurmurHash3 of the favicon for use in Shodan queries:
    http.favicon.hash:<hash>
"""

import sys
import base64
import requests
import mmh3


def get_favicon_hash(url: str) -> int:
    """Extract favicon from URL and compute MurmurHash3."""
    # Try common favicon locations
    favicon_urls = [
        f"{url.rstrip('/')}/favicon.ico",
        f"{url.rstrip('/')}/favicon.png",
        f"{url.rstrip('/')}/apple-touch-icon.png",
    ]
    
    for favicon_url in favicon_urls:
        try:
            response = requests.get(favicon_url, timeout=10)
            if response.status_code == 200:
                # Encode to base64
                b64 = base64.encodebytes(response.content)
                # Compute hash
                hash_value = mmh3.hash(b64)
                return hash_value
        except requests.RequestException as e:
            print(f"Warning: Could not fetch {favicon_url}: {e}", file=sys.stderr)
            continue
    
    raise ValueError(f"Could not find favicon at any location for {url}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python check_favicon_hash.py <url>")
        print("Example: python check_favicon_hash.py https://www.paypal.com")
        sys.exit(1)
    
    url = sys.argv[1]
    
    # Ensure URL has scheme
    if not url.startswith(('http://', 'https://')):
        url = f"https://{url}"
    
    print(f"Analyzing favicon for: {url}")
    print("-" * 50)
    
    try:
        hash_value = get_favicon_hash(url)
        
        print(f"Favicon Hash (MurmurHash3): {hash_value}")
        print()
        print("Shodan query:")
        print(f"  http.favicon.hash:{hash_value}")
        print()
        print("ZoomEye query:")
        print(f"  favicon_hash:{hash_value}")
        print()
        print("Censys query:")
        print(f"  http.favicon.hash: {hash_value}")
        print()
        print("Note: Treat matches as leads. Validate content and certificates before acting.")
        
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
