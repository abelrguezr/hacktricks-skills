#!/usr/bin/env python3
"""
Generate test cases for NTLM coercion skill evaluation.
Creates evals.json with realistic test scenarios.
"""

import json

def generate_test_cases():
    """Generate realistic test cases for the NTLM coercion skill"""
    
    test_cases = {
        "skill_name": "windows-ntlm-coercion",
        "evals": [
            {
                "id": 1,
                "name": "spooler_enumeration",
                "prompt": "I need to check which Windows servers in my domain have the Print Spooler service running. I have domain admin credentials and want to enumerate potential targets for authentication coercion testing. The domain is corp.local and I'm testing on authorized systems only.",
                "expected_output": "PowerShell command using Get-ADComputer to enumerate Windows servers, followed by spooler status checking method (Get-SpoolStatus.ps1 or rpcdump.py)",
                "files": []
            },
            {
                "id": 2,
                "name": "ms_even_coercion",
                "prompt": "I want to coerce a Windows Domain Controller at 192.168.1.10 to authenticate to my responder at 192.168.1.50. I have valid domain user credentials (corp.local/testuser:Password123). What's the most reliable method for Tier 0 assets?",
                "expected_output": "Recommendation to use MS-EVEN (ElfrOpenBELW opnum 9) via CheeseOunce or similar tool, with specific command syntax",
                "files": []
            },
            {
                "id": 3,
                "name": "privexchange_attack",
                "prompt": "I've identified an Exchange Server 2016 at 10.0.0.50 in the domain. I have a standard user account with a mailbox. How can I use the PrivExchange vulnerability to force authentication?",
                "expected_output": "Explanation of PrivExchange attack vector, command using privexchange.py tool, and potential impact (NTDS extraction via LDAP relay)",
                "files": []
            },
            {
                "id": 4,
                "name": "mssql_coercion",
                "prompt": "I have access to a MSSQL server at 192.168.1.100 with credentials corp.com/dbuser:dbpass123. I want to use it to coerce authentication from other systems to my relay server at 192.168.1.200. What are my options?",
                "expected_output": "MSSQL coercion methods including xp_dirtree command and/or MSSQLPwner tool usage with specific command examples",
                "files": []
            },
            {
                "id": 5,
                "name": "html_injection_phishing",
                "prompt": "I need to create a phishing email that will trigger NTLM authentication from the recipient's browser. The target user is john.doe@corp.local and my responder is at 10.10.10.50. How do I craft this?",
                "expected_output": "HTML email template with embedded image using UNC path (\\10.10.10.50\test.ico) with height/width set to 1 for stealth",
                "files": []
            },
            {
                "id": 6,
                "name": "unconstrained_delegation_combo",
                "prompt": "I've compromised a server with unconstrained delegation enabled. How can I combine this with Print Spooler coercion to extract a TGT from a printer's computer account?",
                "expected_output": "Step-by-step methodology: 1) Force printer to authenticate to compromised host 2) Printer's TGT cached in memory 3) Extract ticket using Mimikatz or similar 4) Use Pass-the-Ticket",
                "files": []
            }
        ]
    }
    
    return test_cases

def main():
    test_cases = generate_test_cases()
    
    # Save to file
    with open("evals/evals.json", "w") as f:
        json.dump(test_cases, f, indent=2)
    
    print(f"Generated {len(test_cases['evals'])} test cases")
    print("Saved to evals/evals.json")
    
    # Print summary
    for eval_case in test_cases["evals"]:
        print(f"\n[{eval_case['id']}] {eval_case['name']}")
        print(f"  Prompt: {eval_case['prompt'][:80]}...")

if __name__ == "__main__":
    main()
