#!/usr/bin/env python3
"""
Analyze Active Directory trust relationships and suggest attack paths.
Use this after running Get-DomainTrust or nltest /domain_trusts
"""

import json
import sys

def analyze_trust(trust_info):
    """Analyze trust relationship and suggest attack paths."""
    
    analysis = {
        "trust_type": trust_info.get("TrustType", "Unknown"),
        "direction": trust_info.get("TrustDirection", "Unknown"),
        "attributes": trust_info.get("TrustAttributes", []),
        "source_domain": trust_info.get("SourceName", ""),
        "target_domain": trust_info.get("TargetName", ""),
        "attack_paths": [],
        "enumeration_commands": [],
        "risk_level": "Low"
    }
    
    direction = trust_info.get("TrustDirection", "").lower()
    attributes = trust_info.get("TrustAttributes", [])
    
    # Determine trust context
    if "within_forest" in attributes:
        analysis["context"] = "Intra-forest trust (child/parent or cross-link)"
        analysis["risk_level"] = "High"
        
        if direction == "bidirectional":
            analysis["attack_paths"].extend([
                "SID-History injection",
                "Exploit writable Configuration NC",
                "Link GPO to root DC site",
                "Compromise gMSA via KDS Root key",
                "Schema change attack"
            ])
        else:
            analysis["attack_paths"].extend([
                "Check for foreign security principals",
                "Exploit trust account credentials",
                "RDPInception attacks"
            ])
            
    elif "forest_transitive" in attributes:
        analysis["context"] = "Inter-forest trust"
        analysis["risk_level"] = "Medium"
        
        if direction == "inbound":
            # Your domain is trusted by external
            analysis["attack_paths"].extend([
                "Find principals with access to external domain",
                "Exploit foreign security principals",
                "Check for SQL trusted links"
            ])
            analysis["enumeration_commands"].extend([
                "Get-DomainForeignUser",
                "Get-DomainForeignGroupMember",
                "Search-ADObject -Filter 'objectClass -eq \"foreignSecurityPrincipal\"'"
            ])
            
        elif direction == "outbound":
            # You trust external domain
            analysis["attack_paths"].extend([
                "Access trust account (predictable name/password)",
                "Exploit SQL trusted links (opposite direction)",
                "RDPInception on machines where external users login"
            ])
            analysis["enumeration_commands"].extend([
                "Get-DomainTrust -Domain <external_domain>",
                "nltest /dclist:<external_domain>"
            ])
    
    else:
        analysis["context"] = "External or MIT trust"
        analysis["risk_level"] = "Low"
        analysis["attack_paths"].extend([
            "Check for SID filtering bypass",
            "Exploit trust account",
            "Look for SQL trusted links"
        ])
    
    # Add general enumeration commands
    analysis["enumeration_commands"].extend([
        f"Get-DomainTrust -Domain {analysis['source_domain']}",
        f"nltest /domain_trusts /all_trusts /v",
        f"nltest /dclist:{analysis['target_domain']}"
    ])
    
    return analysis

def main():
    # Example trust information (in practice, parse from Get-DomainTrust output)
    example_trusts = [
        {
            "SourceName": "child.corp.local",
            "TargetName": "corp.local",
            "TrustType": "WINDOWS_ACTIVE_DIRECTORY",
            "TrustAttributes": ["WITHIN_FOREST"],
            "TrustDirection": "Bidirectional"
        },
        {
            "SourceName": "corp.local",
            "TargetName": "partner.external",
            "TrustType": "WINDOWS_ACTIVE_DIRECTORY",
            "TrustAttributes": ["FOREST_TRANSITIVE"],
            "TrustDirection": "Outbound"
        }
    ]
    
    print("Active Directory Trust Analyzer")
    print("=" * 50)
    print()
    
    for trust in example_trusts:
        analysis = analyze_trust(trust)
        
        print(f"Trust: {analysis['source_domain']} -> {analysis['target_domain']}")
        print(f"Type: {analysis['trust_type']}")
        print(f"Direction: {analysis['direction']}")
        print(f"Context: {analysis['context']}")
        print(f"Risk Level: {analysis['risk_level']}")
        print()
        print("Attack Paths:")
        for path in analysis['attack_paths']:
            print(f"  - {path}")
        print()
        print("Enumeration Commands:")
        for cmd in analysis['enumeration_commands']:
            print(f"  {cmd}")
        print()
        print("-" * 50)
        print()

if __name__ == "__main__":
    main()
