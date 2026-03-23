#!/bin/bash
# Favicon Hash Discovery Script
# Usage: ./favicon-hash-search.sh <target-domain>

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <target-domain>"
    echo "Example: $0 example.com"
    exit 1
fi

TARGET="$1"
OUTPUT_DIR="./recon-output/${TARGET}"
mkdir -p "$OUTPUT_DIR"

echo "[*] Favicon Hash Discovery for: $TARGET"
echo "[*] Output directory: $OUTPUT_DIR"

# Calculate favicon hash for target
echo "[*] Calculating favicon hash for target..."

# Python script to calculate favicon hash
python3 << 'PYTHON_SCRIPT'
import sys
import mmh3
import requests
import codecs
import json

def fav_hash(url):
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            favicon = codecs.encode(response.content, "base64")
            fhash = mmh3.hash(favicon)
            return fhash
    except Exception as e:
        print(f"[!] Error fetching {url}: {e}")
    return None

if len(sys.argv) < 2:
    print("Usage: script <target-domain>")
    sys.exit(1)

target = sys.argv[1]

# Try common favicon locations
favicon_urls = [
    f"https://{target}/favicon.ico",
    f"http://{target}/favicon.ico",
    f"https://www.{target}/favicon.ico",
    f"http://www.{target}/favicon.ico",
]

for url in favicon_urls:
    fhash = fav_hash(url)
    if fhash:
        print(f"Favicon hash for {url}: {fhash}")
        
        # Save to file
        with open("./recon-output/" + target + "/favicon-hash.txt", "w") as f:
            f.write(f"Target: {target}\n")
            f.write(f"URL: {url}\n")
            f.write(f"Hash: {fhash}\n")
            f.write(f"\nShodan search: shodan search http.favicon.hash:{fhash}\n")
        
        print(f"\n[*] Favicon hash saved to: ./recon-output/{target}/favicon-hash.txt")
        print(f"[*] Search in Shodan: shodan search http.favicon.hash:{fhash}")
        break
else:
    print("[!] Could not fetch favicon from target")
PYTHON_SCRIPT

# If httpx is available, get favicon hashes at scale
echo ""
echo "[*] If you have a list of domains, use httpx:"
echo "    httpx -l domains.txt -favicon -o favicon-results.txt"

echo ""
echo "========================================"
echo "Favicon Hash Discovery Complete"
echo "========================================"
echo "Check: $OUTPUT_DIR/favicon-hash.txt"
echo ""
echo "Use the hash to search Shodan for related domains:"
echo "  shodan search http.favicon.hash:<HASH>"
echo "========================================"
