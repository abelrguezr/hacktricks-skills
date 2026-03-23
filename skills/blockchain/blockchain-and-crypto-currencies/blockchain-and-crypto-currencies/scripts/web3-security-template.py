#!/usr/bin/env python3
"""
Web3 Security Assessment Template Generator

Generates structured security assessment reports for smart contracts, DeFi protocols, and wallet integrations.

Usage:
    python web3-security-template.py --type <type> --output <file.md>
    
Types:
    - smart-contract: Smart contract security assessment
    - defi-protocol: DeFi protocol security assessment
    - wallet-integration: Wallet integration security assessment
    - general: General Web3 security assessment
"""

import argparse
import json
from datetime import datetime
from typing import Dict, List, Optional


ASSESSMENT_TEMPLATES = {
    'smart-contract': {
        'title': 'Smart Contract Security Assessment',
        'sections': [
            {
                'name': 'Contract Overview',
                'fields': [
                    'Contract Name',
                    'Contract Address',
                    'Network',
                    'Deployment Date',
                    'Total Value Locked (if applicable)',
                    'Primary Functionality'
                ]
            },
            {
                'name': 'Architecture Analysis',
                'fields': [
                    'Inheritance Structure',
                    'External Dependencies',
                    'Upgrade Mechanism',
                    'Access Control Pattern',
                    'Event Emission Strategy'
                ]
            },
            {
                'name': 'Vulnerability Assessment',
                'fields': [
                    'Reentrancy Risks',
                    'Integer Overflow/Underflow',
                    'Access Control Issues',
                    'Logic Errors',
                    'Gas Optimization Issues',
                    'Front-running Vulnerabilities',
                    'Oracle Manipulation Risks'
                ]
            },
            {
                'name': 'Testing Coverage',
                'fields': [
                    'Unit Test Coverage %',
                    'Integration Test Coverage %',
                    'Fuzz Testing Results',
                    'Formal Verification Status',
                    'Known Edge Cases'
                ]
            },
            {
                'name': 'Recommendations',
                'fields': [
                    'Critical Issues',
                    'High Priority Issues',
                    'Medium Priority Issues',
                    'Low Priority Issues',
                    'Best Practices'
                ]
            }
        ]
    },
    'defi-protocol': {
        'title': 'DeFi Protocol Security Assessment',
        'sections': [
            {
                'name': 'Protocol Overview',
                'fields': [
                    'Protocol Name',
                    'Protocol Type (DEX, Lending, Yield, etc.)',
                    'Total Value Locked',
                    'Primary Token(s)',
                    'Governance Model'
                ]
            },
            {
                'name': 'Value-Bearing Components',
                'fields': [
                    'Signers/Multisig Configuration',
                    'Oracle Integrations',
                    'Bridge Connections',
                    'Automation Systems',
                    'Liquidity Pools',
                    'Staking Mechanisms'
                ]
            },
            {
                'name': 'Attack Surface Analysis',
                'fields': [
                    'Flash Loan Vulnerabilities',
                    'Oracle Manipulation Risks',
                    'Price Feed Dependencies',
                    'Liquidity Risks',
                    'Governance Attack Vectors',
                    'Cross-Chain Risks'
                ]
            },
            {
                'name': 'Economic Security',
                'fields': [
                    'Incentive Alignment',
                    'Collateralization Requirements',
                    'Liquidation Mechanisms',
                    'Tokenomics Analysis',
                    'MEV Exposure'
                ]
            },
            {
                'name': 'Incident Response',
                'fields': [
                    'Emergency Pause Mechanisms',
                    'Upgrade Procedures',
                    'Bug Bounty Program',
                    'Insurance Coverage',
                    'Communication Channels'
                ]
            }
        ]
    },
    'wallet-integration': {
        'title': 'Wallet Integration Security Assessment',
        'sections': [
            {
                'name': 'Integration Overview',
                'fields': [
                    'Wallet Type (Hardware, Software, Custodial)',
                    'Supported Networks',
                    'Integration Method (SDK, API, Direct)',
                    'User Base Size',
                    'Transaction Volume'
                ]
            },
            {
                'name': 'Key Management',
                'fields': [
                    'Key Storage Method',
                    'Encryption Standards',
                    'Backup/Recovery Process',
                    'Multi-sig Support',
                    'Social Recovery Options'
                ]
            },
            {
                'name': 'Transaction Security',
                'fields': [
                    'Signature Verification',
                    'Transaction Simulation',
                    'Phishing Protection',
                    'Approval Management',
                    'Gas Estimation Accuracy'
                ]
            },
            {
                'name': 'UI/UX Security',
                'fields': [
                    'Transaction Display Clarity',
                    'Warning Systems',
                    'Confirmation Flows',
                    'EIP-712 Payload Display',
                    'Deception Prevention'
                ]
            },
            {
                'name': 'Supply Chain Security',
                'fields': [
                    'Dependency Audit',
                    'Update Mechanism',
                    'Code Signing',
                    'Distribution Channels',
                    'Tamper Detection'
                ]
            }
        ]
    },
    'general': {
        'title': 'General Web3 Security Assessment',
        'sections': [
            {
                'name': 'Project Overview',
                'fields': [
                    'Project Name',
                    'Project Type',
                    'Target Users',
                    'Value at Risk',
                    'Regulatory Considerations'
                ]
            },
            {
                'name': 'Threat Model',
                'fields': [
                    'Adversary Capabilities',
                    'Attack Vectors',
                    'Asset Classification',
                    'Trust Boundaries',
                    'MITRE AADAPT Mapping'
                ]
            },
            {
                'name': 'Technical Assessment',
                'fields': [
                    'Smart Contract Audit Status',
                    'Infrastructure Security',
                    'API Security',
                    'Database Security',
                    'Network Security'
                ]
            },
            {
                'name': 'Operational Security',
                'fields': [
                    'Key Management Procedures',
                    'Access Control',
                    'Monitoring & Alerting',
                    'Incident Response Plan',
                    'Team Security Training'
                ]
            },
            {
                'name': 'Compliance & Governance',
                'fields': [
                    'Regulatory Compliance',
                    'Governance Structure',
                    'Transparency Measures',
                    'Audit Trail',
                    'Stakeholder Communication'
                ]
            }
        ]
    }
}


def generate_template(template_type: str, output_format: str = 'markdown') -> str:
    """Generate a security assessment template."""
    
    if template_type not in ASSESSMENT_TEMPLATES:
        raise ValueError(f"Unknown template type: {template_type}. Available: {list(ASSESSMENT_TEMPLATES.keys())}")
    
    template = ASSESSMENT_TEMPLATES[template_type]
    
    if output_format == 'markdown':
        return generate_markdown_template(template)
    elif output_format == 'json':
        return json.dumps(template, indent=2)
    else:
        raise ValueError(f"Unknown output format: {output_format}")


def generate_markdown_template(template: Dict) -> str:
    """Generate markdown format assessment template."""
    
    md = f"""# {template['title']}

**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

"""
    
    for section in template['sections']:
        md += f"## {section['name']}\n\n"
        
        for field in section['fields']:
            md += f"- **{field}**: _[Enter details]_\n"
        
        md += "\n"
    
    md += """---

## Assessment Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 0 | 🔴 Open |
| High | 0 | 🟠 Open |
| Medium | 0 | 🟡 Open |
| Low | 0 | 🟢 Open |
| Info | 0 | 🔵 Open |

## Risk Rating

**Overall Risk Level:** _[To be determined]_

## Recommendations Summary

1. _[Top priority recommendation]_
2. _[Second priority recommendation]_
3. _[Third priority recommendation]_

## Next Steps

- [ ] Address critical vulnerabilities
- [ ] Schedule follow-up assessment
- [ ] Update security documentation
- [ ] Brief stakeholders

---

*This template follows Web3 security best practices and MITRE AADAPT framework.*
"""
    
    return md


def main():
    parser = argparse.ArgumentParser(
        description='Generate Web3 security assessment templates'
    )
    parser.add_argument(
        '--type',
        choices=list(ASSESSMENT_TEMPLATES.keys()),
        default='general',
        help='Assessment template type'
    )
    parser.add_argument(
        '--output',
        choices=['markdown', 'json'],
        default='markdown',
        help='Output format'
    )
    parser.add_argument(
        '--file',
        help='Output file path (default: stdout)'
    )
    parser.add_argument(
        '--list',
        action='store_true',
        help='List available template types'
    )
    
    args = parser.parse_args()
    
    if args.list:
        print("Available template types:")
        for template_type in ASSESSMENT_TEMPLATES.keys():
            print(f"  - {template_type}")
        return
    
    try:
        result = generate_template(args.type, args.output)
        
        if args.file:
            with open(args.file, 'w') as f:
                f.write(result)
            print(f"Template saved to {args.file}")
        else:
            print(result)
    
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
