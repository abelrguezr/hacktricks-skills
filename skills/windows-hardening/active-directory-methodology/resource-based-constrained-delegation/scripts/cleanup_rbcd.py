#!/usr/bin/env python3
"""
Clean up Resource-based Constrained Delegation (RBCD) configurations.

Usage:
    python cleanup_rbcd.py -dc <domain_controller> -u <username> -p <password> -t <target_computer> -f <fake_computer>
    python cleanup_rbcd.py -dc <domain_controller> -u <username> -p <password> -t <target_computer> --flush

This script removes RBCD configurations from target computer objects.
"""

import argparse
import sys
from impacket.ldap import ldap, ldapasn1
from impacket.ldap.ldaptypes import MSRPCAuth, SecurityDescriptor


def parse_args():
    parser = argparse.ArgumentParser(
        description='Clean up RBCD configurations in Active Directory'
    )
    parser.add_argument('-dc', required=True, help='Domain Controller IP or hostname')
    parser.add_argument('-u', required=True, help='Username (domain/user format)')
    parser.add_argument('-p', help='Password')
    parser.add_argument('-hashes', help='LM:NTLM hashes')
    parser.add_argument('-k', action='store_true', help='Use Kerberos authentication')
    parser.add_argument('-dc-ip', help='IP address of the domain controller')
    parser.add_argument('-t', '--target', required=True, help='Target computer to clean up')
    parser.add_argument('-f', '--fake', help='Fake computer to remove from delegation list')
    parser.add_argument('--flush', action='store_true', help='Flush entire delegation list')
    parser.add_argument('-use-ldaps', action='store_true', help='Use LDAPS')
    return parser.parse_args()


def get_credentials(args):
    """Parse credentials from arguments."""
    if '@' in args.u:
        domain, username = args.u.split('@', 1)
    else:
        domain, username = args.u.split('/', 1)
    
    return domain, username


def cleanup_rbcd(dc_ip, domain, username, password=None, hashes=None, use_kerberos=False, 
                 use_ldaps=False, target=None, fake=None, flush=False):
    """Clean up RBCD configurations."""
    
    print(f"[*] Connecting to {dc_ip}...")
    
    # Build LDAP connection
    if use_ldaps:
        ldap_url = f"ldaps://{dc_ip}"
    else:
        ldap_url = f"ldap://{dc_ip}"
    
    try:
        conn = ldap.LDAPConnection(ldap_url)
        
        if use_kerberos:
            from impacket.krb5.ccache import CCache
            ccache = CCache.loadFile()
            principal = ccache.principal
            conn.kerberosLogin(principal, ccache)
        elif hashes:
            lmhash, nthash = hashes.split(':')
            conn.login(username, password or '', domain, lmhash, nthash)
        else:
            conn.login(username, password, domain)
        
        print(f"[*] Connected as {domain}/{username}")
        
        # Find the target computer
        search_filter = f"(cn={target})"
        search_attributes = ['distinguishedName', 'msDS-AllowedToActOnBehalfOfOtherIdentity']
        
        results = conn.search(
            baseDN=f"DC={domain.replace('.', ',DC=")}",
            scope=ldap.SCOPE_SUBTREE,
            searchFilter=search_filter,
            attributes=search_attributes
        )
        
        if not results:
            print(f"[!] Computer {target} not found.")
            return
        
        target_dn = results[0]['distinguishedName']
        print(f"[*] Found target: {target_dn}")
        
        if flush:
            # Clear the entire attribute
            print(f"[*] Flushing RBCD configuration from {target}...")
            
            # Clear the attribute by setting it to empty
            conn.modify(target_dn, [('msDS-AllowedToActOnBehalfOfOtherIdentity', ldap.MOD_DELETE, b'')])
            
            print(f"[+] Successfully flushed RBCD configuration from {target}")
            
        elif fake:
            # Remove specific principal
            print(f"[*] Removing {fake} from RBCD configuration on {target}...")
            
            # This is a simplified version - in practice you'd need to parse the SD
            # and remove the specific ACE. For now, we'll use the impacket-rbcd approach.
            print(f"[*] For removing specific principals, use: impacket-rbcd -delegate-to '{target}$' -delegate-from '{fake}$' -action remove 'domain/user:pass'")
            
        else:
            print("[!] Specify either --flush or -f <fake_computer> to clean up.")
            return
        
    except Exception as e:
        print(f"[!] Error: {e}")
        sys.exit(1)
    finally:
        try:
            conn.close()
        except:
            pass


def main():
    args = parse_args()
    
    domain, username = get_credentials(args)
    
    cleanup_rbcd(
        dc_ip=args.dc_ip or args.dc,
        domain=domain,
        username=username,
        password=args.p,
        hashes=args.hashes,
        use_kerberos=args.k,
        use_ldaps=args.use_ldaps,
        target=args.target,
        fake=args.fake,
        flush=args.flush
    )


if __name__ == '__main__':
    main()
