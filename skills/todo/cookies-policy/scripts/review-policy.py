#!/usr/bin/env python3
"""Review a cookies policy for completeness and compliance."""

import re
import sys

def review_policy(policy_text):
    """Review a cookies policy and return findings."""
    
    findings = {
        "score": 0,
        "max_score": 100,
        "checks": [],
        "recommendations": []
    }
    
    # Check for required sections
    required_sections = {
        "introduction": (r"(introduction|intro)", 10),
        "what are cookies": (r"(what are cookies?|what is a cookie|cookies are)", 10),
        "how we use cookies": (r"(how we use cookies|cookie usage|types of cookies)", 15),
        "third-party": (r"(third[- ]?party|third party)", 10),
        "managing cookies": (r"(managing cookies|disable cookies|browser settings|cookie preferences)", 10),
        "changes": (r"(changes|update|updated)", 5),
        "contact": (r"(contact|email|support|reach us)", 10)
    }
    
    for section_name, (pattern, points) in required_sections.items():
        if re.search(pattern, policy_text, re.IGNORECASE):
            findings["checks"].append({"name": section_name, "passed": True, "points": points})
            findings["score"] += points
        else:
            findings["checks"].append({"name": section_name, "passed": False, "points": 0})
            findings["recommendations"].append(f"Add a section about {section_name}")
    
    # Check for cookie type mentions
    cookie_types = ["essential", "performance", "functionality", "targeting", "advertising"]
    types_found = 0
    for cookie_type in cookie_types:
        if re.search(rf"\b{cookie_type}\b", policy_text, re.IGNORECASE):
            types_found += 1
    
    if types_found >= 3:
        findings["checks"].append({"name": "cookie_types", "passed": True, "points": 15})
        findings["score"] += 15
    else:
        findings["checks"].append({"name": "cookie_types", "passed": False, "points": 0})
        findings["recommendations"].append(f"Mention more cookie types (found {types_found}/4)")
    
    # Check for date
    if re.search(r"(last updated|updated|date):?\s*\d{1,2}/\d{1,2}/\d{2,4}", policy_text, re.IGNORECASE):
        findings["checks"].append({"name": "last_updated", "passed": True, "points": 10})
        findings["score"] += 10
    else:
        findings["checks"].append({"name": "last_updated", "passed": False, "points": 0})
        findings["recommendations"].append("Add a 'Last updated' date")
    
    # Check for email
    if re.search(r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", policy_text):
        findings["checks"].append({"name": "contact_email", "passed": True, "points": 10})
        findings["score"] += 10
    else:
        findings["checks"].append({"name": "contact_email", "passed": False, "points": 0})
        findings["recommendations"].append("Add a contact email address")
    
    # Check for GDPR mention (bonus)
    if re.search(r"(GDPR|General Data Protection Regulation)", policy_text, re.IGNORECASE):
        findings["checks"].append({"name": "gdpr_mention", "passed": True, "points": 5})
        findings["score"] += 5
    else:
        findings["checks"].append({"name": "gdpr_mention", "passed": False, "points": 0})
    
    # Check for CCPA mention (bonus)
    if re.search(r"(CCPA|California Consumer Privacy Act)", policy_text, re.IGNORECASE):
        findings["checks"].append({"name": "ccpa_mention", "passed": True, "points": 5})
        findings["score"] += 5
    else:
        findings["checks"].append({"name": "ccpa_mention", "passed": False, "points": 0})
    
    findings["max_score"] = sum(c["points"] for c in required_sections.values()) + 15 + 10 + 10 + 5 + 5
    
    return findings

def main():
    """Main entry point."""
    
    if len(sys.argv) > 1:
        with open(sys.argv[1], 'r') as f:
            policy_text = f.read()
    else:
        policy_text = sys.stdin.read()
    
    findings = review_policy(policy_text)
    
    print(f"Cookies Policy Review Results")
    print(f"=" * 40)
    print(f"Score: {findings['score']}/{findings['max_score']}")
    print(f"")
    print(f"Checks:")
    for check in findings["checks"]:
        status = "✓" if check["passed"] else "✗"
        print(f"  {status} {check['name']}")
    
    if findings["recommendations"]:
        print(f"")
        print(f"Recommendations:")
        for rec in findings["recommendations"]:
            print(f"  • {rec}")
    
    # Output JSON for programmatic use
    print(f"")
    print(f"---")
    print(json.dumps(findings, indent=2))

if __name__ == "__main__":
    main()
