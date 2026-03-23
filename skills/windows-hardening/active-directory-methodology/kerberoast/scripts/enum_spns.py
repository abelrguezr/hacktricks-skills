#!/usr/bin/env python3
"""
Enumerate kerberoastable users from Active Directory

Usage:
    python enum_spns.py -d DOMAIN -u user -p password -dc-ip 192.168.1.10
    python enum_spns.py -d DOMAIN -u user -H lmhash:nthash -dc-ip 192.168.1.10

Output: CSV file with SPN, username, and account details
"""

import argparse
import csv
import sys
from datetime import datetime

try:
    from impacket.dcerpc.v5 import samr, lsat, transport
    from impacket.dcerpc.v5.rpcrt import DCERPC_v5
    from impacket.ldap import ldap
    from impacket.smbconnection import SMBConnection
    from impacket.ntlm import compute_lmhash, compute_nthash
except ImportError:
    print("[!] impacket not installed. Install with: pip install impacket")
    sys.exit(1)

def enumerate_spns(domain, username, password, dc_ip, lmhash=None, nthash=None):
    """Enumerate users with SPN set using LDAP"""
    
    # Build LDAP connection string
    if lmhash and nthash:
        auth_string = f"{domain}/{username}:{password}@{dc_ip}"
    else:
        auth_string = f"{domain}/{username}:{password}@{dc_ip}"
    
    print(f"[*] Connecting to LDAP on {dc_ip}...")
    
    try:
        # Connect to LDAP
        ldap_connection = ldap.LDAPConnection(f"ldap://{dc_ip}")
        ldap_connection.connect()
        
        # Bind with credentials
        if lmhash and nthash:
            ldap_connection.simpleBind_sam(username, lmhash, nthash)
        else:
            ldap_connection.simpleBind_sam(username, password)
        
        print(f"[*] Successfully bound as {username}")
        
        # Search for users with SPN set
        search_filter = "(&(objectClass=user)(servicePrincipalName=*)(!(objectClass=computer)))"
        base_dn = f"DC={domain.replace('.', ',DC=')}"
        
        print(f"[*] Searching for users with SPN in {base_dn}...")
        
        results = ldap_connection.search(
            base_dn,
            search_filter,
            ldap.SCOPE_SUBTREE,
            ["sAMAccountName", "servicePrincipalName", "distinguishedName", "pwdLastSet"]
        )
        
        spn_users = []
        
        for entry in results:
            dn = entry["dn"]
            attrs = entry["attributes"]
            
            username = attrs.get("sAMAccountName", [""])[0]
            spns = attrs.get("servicePrincipalName", [])
            dn_value = attrs.get("distinguishedName", [""])[0]
            pwd_last_set = attrs.get("pwdLastSet", [0])[0]
            
            # Convert pwdLastSet (100-nanosecond intervals since 1601) to datetime
            if pwd_last_set and pwd_last_set != 0:
                try:
                    pwd_date = datetime.fromtimestamp((pwd_last_set - 1164447360000000000) / 10000000)
                    pwd_str = pwd_date.strftime("%Y-%m-%d")
                except:
                    pwd_str = "unknown"
            else:
                pwd_str = "never"
            
            for spn in spns:
                spn_users.append({
                    "SPN": spn,
                    "Username": username,
                    "DN": dn_value,
                    "PasswordLastSet": pwd_str
                })
        
        return spn_users
        
    except Exception as e:
        print(f"[!] Error during LDAP enumeration: {e}")
        return []

def main():
    parser = argparse.ArgumentParser(description='Enumerate kerberoastable users')
    parser.add_argument('-d', '--domain', required=True, help='Domain name')
    parser.add_argument('-u', '--username', required=True, help='Username')
    parser.add_argument('-p', '--password', default='', help='Password')
    parser.add_argument('-H', '--hashes', help='LMHASH:NTHASH')
    parser.add_argument('-dc-ip', '--dc-ip', required=True, help='Domain Controller IP')
    parser.add_argument('-o', '--output', default='spn_users.csv', help='Output CSV file')
    
    args = parser.parse_args()
    
    # Parse hashes if provided
    lmhash = None
    nthash = None
    if args.hashes:
        parts = args.hashes.split(':')
        if len(parts) == 2:
            lmhash = parts[0]
            nthash = parts[1]
        else:
            print("[!] Hashes should be in format LMHASH:NTHASH")
            sys.exit(1)
    
    # Enumerate SPNs
    spn_users = enumerate_spns(
        args.domain,
        args.username,
        args.password,
        args.dc_ip,
        lmhash,
        nthash
    )
    
    if not spn_users:
        print("[!] No users with SPN found or enumeration failed")
        sys.exit(1)
    
    # Write to CSV
    with open(args.output, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=["SPN", "Username", "DN", "PasswordLastSet"])
        writer.writeheader()
        writer.writerows(spn_users)
    
    print(f"[+] Found {len(spn_users)} SPN entries")
    print(f"[+] Results saved to: {args.output}")
    
    # Show summary
    unique_users = len(set(u["Username"] for u in spn_users))
    print(f"[*] Unique users: {unique_users}")

if __name__ == '__main__':
    main()
