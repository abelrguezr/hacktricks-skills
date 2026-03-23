#!/usr/bin/env python3
"""
Generate SPF and DMARC DNS records for email configuration.
Usage: python generate_spf_dmarc.py <domain> <mail-server-ip>
"""

import sys
import json

def generate_spf(ip_address, include_mx=True, include_a=True):
    """Generate SPF record."""
    parts = ["v=spf1"]
    
    if include_mx:
        parts.append("mx")
    if include_a:
        parts.append("a")
    
    parts.append(f"ip4:{ip_address}")
    parts.append("~all")  # Soft fail (use -all for hard fail)
    
    return " ".join(parts)

def generate_dmarc(policy="none", rua=None, ruf=None):
    """Generate DMARC record."""
    parts = ["v=DMARC1"]
    parts.append(f"p={policy}")  # none, quarantine, reject
    
    if rua:
        parts.append(f"rua={rua}")
    if ruf:
        parts.append(f"ruf={ruf}")
    
    # Add recommended defaults
    parts.append("sp=none")  # Subdomain policy
    parts.append("adkim=s")  # Strict DKIM alignment
    parts.append("aspf=s")   # Strict SPF alignment
    
    return " ".join(parts)

def generate_dkim_selector():
    """Generate DKIM selector name."""
    import random
    import string
    return ''.join(random.choices(string.ascii_lowercase, k=10))

def main():
    if len(sys.argv) < 3:
        print("Usage: python generate_spf_dmarc.py <domain> <mail-server-ip> [policy]")
        print("Example: python generate_spf_dmarc.py example.com 192.168.1.1 none")
        print("Policy options: none, quarantine, reject")
        sys.exit(1)
    
    domain = sys.argv[1].lower().strip()
    ip_address = sys.argv[2].strip()
    policy = sys.argv[3] if len(sys.argv) > 3 else "none"
    
    if policy not in ["none", "quarantine", "reject"]:
        print("Invalid policy. Use: none, quarantine, or reject")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("DNS Record Configuration")
    print("=" * 60)
    print(f"\nDomain: {domain}")
    print(f"Mail Server IP: {ip_address}")
    print(f"DMARC Policy: {policy}")
    print("\n" + "-" * 60)
    
    # SPF Record
    spf = generate_spf(ip_address)
    print("\n[SPF Record]")
    print("Type: TXT")
    print(f"Name: {domain}")
    print(f"Value: \"{spf}\"")
    print("\nDNS Entry:")
    print(f"  {domain}.    IN    TXT    \"{spf}\"")
    
    # DMARC Record
    dmarc = generate_dmarc(policy)
    print("\n[DMARC Record]")
    print("Type: TXT")
    print(f"Name: _dmarc.{domain}")
    print(f"Value: \"{dmarc}\"")
    print("\nDNS Entry:")
    print(f"  _dmarc.{domain}.    IN    TXT    \"{dmarc}\"")
    
    # DKIM Selector
    selector = generate_dkim_selector()
    print("\n[DKIM Record]")
    print("Type: TXT")
    print(f"Name: {selector}._domainkey.{domain}")
    print("Value: (Generate with OpenDKIM and Postfix)")
    print("\nNote: DKIM requires key generation. Use:")
    print("  opendkim-genkey -d {domain} -s {selector}")
    
    # JSON output
    print("\n" + "-" * 60)
    print("[JSON Configuration]")
    config = {
        "domain": domain,
        "mail_server_ip": ip_address,
        "spf": {
            "type": "TXT",
            "name": domain,
            "value": spf
        },
        "dmarc": {
            "type": "TXT",
            "name": f"_dmarc.{domain}",
            "value": dmarc
        },
        "dkim": {
            "type": "TXT",
            "name": f"{selector}._domainkey.{domain}",
            "note": "Generate key with opendkim-genkey"
        }
    }
    print(json.dumps(config, indent=2))
    
    print("\n" + "=" * 60)
    print("Next Steps:")
    print("=" * 60)
    print("1. Add these records to your DNS provider")
    print("2. Wait for DNS propagation (up to 48 hours)")
    print("3. Test with mail-tester.com")
    print("4. Send test to check-auth@verifier.port25.com")
    print("\nDMARC Policy Guide:")
    print("  - none: Monitor only (recommended for new domains)")
    print("  - quarantine: Send suspicious emails to spam")
    print("  - reject: Block unauthenticated emails")

if __name__ == "__main__":
    main()
