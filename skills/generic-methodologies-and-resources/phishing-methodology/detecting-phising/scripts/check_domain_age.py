#!/usr/bin/env python3
"""Check domain registration age via RDAP.

Usage:
    python check_domain_age.py <domain>
    python check_domain_age.py suspicious-example.com

This script queries RDAP to get domain registration dates and
helps identify Newly Registered Domains (NRDs) which are higher risk.
"""

import sys
import json
import requests
from datetime import datetime


def get_domain_age(domain: str) -> dict:
    """Query RDAP for domain registration information."""
    
    # Extract TLD
    parts = domain.split('.')
    if len(parts) < 2:
        raise ValueError(f"Invalid domain: {domain}")
    
    tld = parts[-1]
    
    # Try Verisign RDAP for .com/.net
    if tld in ['com', 'net']:
        rdap_url = f"https://rdap.verisign.com/{tld}/v1/domain/{domain}"
    else:
        # Use generic rdap.net redirector
        rdap_url = f"https://www.rdap.net/domain/{domain}"
    
    try:
        response = requests.get(rdap_url, timeout=15)
        response.raise_for_status()
        data = response.json()
        
        # Extract registration date from events
        events = data.get('events', [])
        registration_date = None
        
        for event in events:
            if event.get('eventAction') == 'registration':
                registration_date = event.get('eventDate')
                break
        
        if not registration_date:
            # Try to find any date in the response
            for event in events:
                if 'eventDate' in event:
                    registration_date = event['eventDate']
                    break
        
        # Calculate age
        age_days = None
        if registration_date:
            reg_date = datetime.fromisoformat(registration_date.replace('Z', '+00:00'))
            age_days = (datetime.now(reg_date.tzinfo) - reg_date).days
        
        return {
            'domain': domain,
            'registration_date': registration_date,
            'age_days': age_days,
            'risk_level': 'HIGH' if age_days and age_days < 7 else 'MEDIUM' if age_days and age_days < 30 else 'LOW',
            'raw_response': data
        }
        
    except requests.RequestException as e:
        return {
            'domain': domain,
            'error': str(e),
            'registration_date': None,
            'age_days': None,
            'risk_level': 'UNKNOWN'
        }


def main():
    if len(sys.argv) < 2:
        print("Usage: python check_domain_age.py <domain> [domain2 ...]")
        print("Example: python check_domain_age.py suspicious-example.com")
        sys.exit(1)
    
    domains = sys.argv[1:]
    results = []
    
    print(f"Checking domain ages for {len(domains)} domain(s)")
    print("-" * 50)
    
    for domain in domains:
        print(f"\nChecking: {domain}")
        result = get_domain_age(domain)
        results.append(result)
        
        if 'error' in result:
            print(f"  Error: {result['error']}")
        else:
            print(f"  Registration Date: {result['registration_date']}")
            print(f"  Age: {result['age_days']} days")
            print(f"  Risk Level: {result['risk_level']}")
    
    # Save results
    output_file = "domain_age_results.json"
    with open(output_file, "w") as f:
        json.dump(results, f, indent=2)
    
    print(f"\n{'=' * 50}")
    print(f"Results saved to: {output_file}")
    print()
    print("Risk Level Guide:")
    print("  HIGH:   < 7 days old (prioritize for investigation)")
    print("  MEDIUM: 7-30 days old")
    print("  LOW:    > 30 days old")


if __name__ == "__main__":
    main()
