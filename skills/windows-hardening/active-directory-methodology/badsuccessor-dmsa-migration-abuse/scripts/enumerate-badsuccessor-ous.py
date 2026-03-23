#!/usr/bin/env python3
"""
BadSuccessor OU Enumeration Script

Enumerates Active Directory OUs to identify those vulnerable to the
BadSuccessor privilege escalation technique.

Usage:
    python enumerate-badsuccessor-ous.py -domain contoso.local -username user -password pass
    python enumerate-badsuccessor-ous.py -domain contoso.local -k (Kerberos auth)

Requirements:
    pip install ldap3 impacket

⚠️ WARNING: Only use on systems you are authorized to test.
"""

import argparse
import sys
from ldap3 import Server, Connection, ALL, SUBTREE
from ldap3.utils.conv import escape_filter_chars

# Object class GUID for msDS-DelegatedManagedServiceAccount
DMSA_OBJECT_CLASS_GUID = "31ed51fa-77b1-4175-884a-5c6f3f6f34e8"

# ADS_RIGHT_DS_CREATE_CHILD permission
CREATE_CHILD_RIGHT = 0x0001


def parse_args():
    parser = argparse.ArgumentParser(
        description="Enumerate OUs vulnerable to BadSuccessor attack"
    )
    parser.add_argument(
        "-domain", "--domain",
        required=True,
        help="Target domain (e.g., contoso.local)"
    )
    parser.add_argument(
        "-username", "-u",
        help="Username for authentication"
    )
    parser.add_argument(
        "-password", "-p",
        help="Password for authentication"
    )
    parser.add_argument(
        "-k",
        action="store_true",
        help="Use Kerberos authentication (requires kinit)"
    )
    parser.add_argument(
        "-dc-ip",
        help="Domain Controller IP address (optional)"
    )
    return parser.parse_args()


def check_ou_vulnerability(sd_bytes, username):
    """
    Check if an OU's security descriptor allows creating dMSA objects.
    
    This is a simplified check - full implementation would parse SDDL
    and check ACEs for the specific object class GUID.
    """
    # In a full implementation, you would:
    # 1. Parse the nTSecurityDescriptor (SDDL format)
    # 2. Check for ACEs with CREATE_CHILD right
    # 3. Verify the object class GUID is allowed
    # 4. Check if the current user is in the allowed SID
    
    # For this example, we'll note that the OU has a security descriptor
    # and recommend manual review
    return "REVIEW_NEEDED", "Security descriptor present - manual review recommended"


def enumerate_ous(server, username, domain):
    """
    Enumerate all OUs and check for BadSuccessor vulnerability.
    """
    print(f"[*] Enumerating OUs in {domain}...")
    print(f"[*] Using credentials: {username}")
    print()
    
    # Search for all OUs
    search_filter = "(objectClass=organizationalUnit)"
    attributes = ["distinguishedName", "nTSecurityDescriptor"]
    
    results = []
    
    try:
        conn = Connection(
            Server(server, get_info=ALL),
            user=username,
            auto_bind=True
        )
        
        conn.search(
            search_base=f"DC={domain.replace('.', ',DC=")}",
            search_filter=search_filter,
            search_scope=SUBTREE,
            attributes=attributes
        )
        
        for entry in conn.entries:
            ou_dn = entry.distinguishedName.value
            
            if entry.nTSecurityDescriptor:
                status, message = check_ou_vulnerability(
                    entry.nTSecurityDescriptor.value,
                    username
                )
                
                results.append({
                    "ou": ou_dn,
                    "status": status,
                    "message": message
                })
                
                print(f"[+] OU: {ou_dn}")
                print(f"    Status: {status}")
                print(f"    Note: {message}")
                print()
            else:
                print(f"[-] OU: {ou_dn} (no security descriptor)")
                print()
        
        conn.unbind()
        
    except Exception as e:
        print(f"[!] Error: {e}")
        sys.exit(1)
    
    return results


def main():
    args = parse_args()
    
    if not args.username and not args.k:
        print("[!] Error: Must provide username or use Kerberos auth (-k)")
        sys.exit(1)
    
    if args.username and not args.password:
        print("[!] Error: Password required when using username")
        sys.exit(1)
    
    # Determine server and credentials
    if args.dc_ip:
        server = args.dc_ip
    else:
        server = args.domain
    
    if args.k:
        username = None
    else:
        username = f"{args.domain}\\{args.username}"
    
    # Run enumeration
    results = enumerate_ous(server, username, args.domain)
    
    # Summary
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    
    vulnerable = [r for r in results if r["status"] == "VULNERABLE"]
    review_needed = [r for r in results if r["status"] == "REVIEW_NEEDED"]
    
    print(f"Total OUs checked: {len(results)}")
    print(f"Potentially vulnerable: {len(vulnerable)}")
    print(f"Need manual review: {len(review_needed)}")
    
    if vulnerable:
        print("\n[!] VULNERABLE OUS:")
        for r in vulnerable:
            print(f"    - {r['ou']}")
    
    print("\n[+] Next steps:")
    print("    1. Review vulnerable OUs and determine if dMSA creation is intended")
    print("    2. Remove unnecessary Create Child permissions")
    print("    3. Enable object auditing on sensitive OUs")
    print("    4. See SKILL.md for exploitation and mitigation details")


if __name__ == "__main__":
    main()
