#!/usr/bin/env python3
"""Query urlscan.io for brand abuse and phishing detection.

Usage:
    python query_urlscan.py <brand-name> [--api-key KEY] [--days N]
    python query_urlscan.py paypal --days 7

This script searches for:
1. Lookalike domains containing your brand name
2. Sites hotlinking your assets
3. Recent scans (default: last 7 days)
"""

import sys
import json
import urllib.parse
import requests
from datetime import datetime, timedelta


def search_urlscan(brand: str, api_key: str, days: int = 7) -> list:
    """Search urlscan.io for brand-related domains."""
    
    # Calculate date range
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    date_filter = f"date:>now-{days}d"
    
    # Query 1: Lookalike domains
    query1 = f"page.domain:(/.*{brand}.*/ AND NOT {brand}.com) AND {date_filter}"
    
    # Query 2: Hotlinking your assets (if brand has a .com)
    query2 = f"domain:{brand}.com AND NOT page.domain:{brand}.com AND {date_filter}"
    
    results = []
    
    for i, query in enumerate([query1, query2], 1):
        print(f"\nQuery {i}: {query}")
        
        encoded_query = urllib.parse.quote(query)
        url = f"https://urlscan.io/api/v1/search/?q={encoded_query}"
        
        headers = {
            "User-Agent": "PhishingDetection/1.0",
        }
        
        if api_key:
            headers["API-Key"] = api_key
        
        try:
            response = requests.get(url, headers=headers, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            for result in data.get("results", [])[:20]:  # Limit to 20 per query
                page = result.get("page", {})
                task = result.get("task", {})
                
                entry = {
                    "url": page.get("url", "unknown"),
                    "domain": page.get("domain", "unknown"),
                    "scan_date": result.get("date", "unknown"),
                    "tls_issuer": page.get("tlsIssuer", "unknown"),
                    "tls_valid_from": page.get("tlsValidFrom", "unknown"),
                    "tls_age_days": page.get("tlsAgeDays", "unknown"),
                    "source": task.get("source", "unknown"),
                    "query_type": f"Query {i}",
                }
                results.append(entry)
                
                print(f"  Found: {entry['url']}")
                print(f"    TLS Age: {entry['tls_age_days']} days, Issuer: {entry['tls_issuer']}")
                
        except requests.RequestException as e:
            print(f"  Error querying urlscan: {e}", file=sys.stderr)
    
    return results


def main():
    if len(sys.argv) < 2:
        print("Usage: python query_urlscan.py <brand-name> [--api-key KEY] [--days N]")
        print("Example: python query_urlscan.py paypal --days 7")
        sys.exit(1)
    
    brand = sys.argv[1]
    api_key = None
    days = 7
    
    # Parse optional arguments
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == "--api-key" and i + 1 < len(sys.argv):
            api_key = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == "--days" and i + 1 < len(sys.argv):
            days = int(sys.argv[i + 1])
            i += 2
        else:
            i += 1
    
    print(f"Searching urlscan.io for brand: {brand}")
    print(f"Time range: Last {days} days")
    print("-" * 50)
    
    results = search_urlscan(brand, api_key, days)
    
    # Save results
    output_file = f"urlscan_results_{brand.replace('.', '_')}.json"
    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\n{'=' * 50}")
    print(f"Total results: {len(results)}")
    print(f"Results saved to: {output_file}")
    print()
    print("Next steps:")
    print("1. Review results for suspicious domains")
    print("2. Prioritize domains with:")
    print("   - Very new TLS certificates (< 7 days)")
    print("   - Unknown or suspicious TLS issuers")
    print("   - Source: certstream-suspicious")
    print("3. Validate by checking content and login forms")


if __name__ == "__main__":
    main()
