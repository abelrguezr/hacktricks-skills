#!/usr/bin/env python3
"""
AI Risk Coverage Checker

Checks which OWASP/SAIF risks are covered in a risk assessment document.
Usage: python check-risk-coverage.py --input assessment.md
"""

import argparse
import re
from pathlib import Path


# OWASP Top 10 ML vulnerabilities
OWASP_RISKS = [
    "Input Manipulation",
    "Data Poisoning",
    "Model Inversion",
    "Membership Inference",
    "Model Theft",
    "AI Supply-Chain",
    "Transfer Learning",
    "Model Skewing",
    "Output Integrity",
    "Model Poisoning",
]

# Google SAIF risks
SAIF_RISKS = [
    "Data Poisoning",
    "Unauthorized Training Data",
    "Model Source Tampering",
    "Excessive Data Handling",
    "Model Exfiltration",
    "Model Deployment Tampering",
    "Denial of ML Service",
    "Model Reverse Engineering",
    "Insecure Integrated Component",
    "Prompt Injection",
    "Model Evasion",
    "Sensitive Data Disclosure",
    "Inferred Sensitive Data",
    "Insecure Model Output",
    "Rogue Actions",
]

# LLMJacking patterns
LLMJACKING_RISKS = [
    "Token Theft",
    "Credential Compromise",
    "Reverse Proxy Abuse",
    "Unauthorized API Access",
]


def check_coverage(content: str) -> dict:
    """Check which risks are mentioned in the content."""
    
    results = {
        "owasp": {risk: False for risk in OWASP_RISKS},
        "saif": {risk: False for risk in SAIF_RISKS},
        "llmjacking": {risk: False for risk in LLMJACKING_RISKS},
    }
    
    content_lower = content.lower()
    
    # Check OWASP risks
    for risk in OWASP_RISKS:
        risk_lower = risk.lower()
        if risk_lower in content_lower:
            results["owasp"][risk] = True
    
    # Check SAIF risks
    for risk in SAIF_RISKS:
        risk_lower = risk.lower()
        if risk_lower in content_lower:
            results["saif"][risk] = True
    
    # Check LLMJacking risks
    for risk in LLMJACKING_RISKS:
        risk_lower = risk.lower()
        if risk_lower in content_lower:
            results["llmjacking"][risk] = True
    
    return results


def print_coverage(results: dict) -> None:
    """Print coverage summary."""
    
    print("\n=== AI Risk Coverage Analysis ===\n")
    
    # OWASP coverage
    owasp_covered = sum(1 for v in results["owasp"].values() if v)
    print(f"OWASP Top 10 ML: {owasp_covered}/10 covered")
    for risk, covered in results["owasp"].items():
        status = "✓" if covered else "✗"
        print(f"  {status} {risk}")
    
    print()
    
    # SAIF coverage
    saif_covered = sum(1 for v in results["saif"].values() if v)
    print(f"Google SAIF: {saif_covered}/15 covered")
    for risk, covered in results["saif"].items():
        status = "✓" if covered else "✗"
        print(f"  {status} {risk}")
    
    print()
    
    # LLMJacking coverage
    llmjacking_covered = sum(1 for v in results["llmjacking"].values() if v)
    print(f"LLMJacking: {llmjacking_covered}/4 covered")
    for risk, covered in results["llmjacking"].items():
        status = "✓" if covered else "✗"
        print(f"  {status} {risk}")
    
    print()
    
    # Summary
    total = owasp_covered + saif_covered + llmjacking_covered
    max_total = 10 + 15 + 4
    print(f"Overall Coverage: {total}/{max_total} ({100*total/max_total:.1f}%)")


def main():
    parser = argparse.ArgumentParser(description='Check AI risk coverage in assessment document')
    parser.add_argument('--input', '-i', required=True,
                        help='Input assessment document path')
    
    args = parser.parse_args()
    
    try:
        content = Path(args.input).read_text()
    except FileNotFoundError:
        print(f"Error: File not found: {args.input}")
        return
    
    results = check_coverage(content)
    print_coverage(results)


if __name__ == '__main__':
    main()
