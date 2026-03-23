#!/usr/bin/env python3
"""
Generate krb5.conf file for Kerberos authentication.

Usage:
    python3 generate_krb5_conf.py --realm <REALM> --kdc <KDC> --admin-server <ADMIN_SERVER>
    python3 generate_krb5_conf.py --realm <REALM> --kdc <KDC> --admin-server <ADMIN_SERVER> --output /etc/krb5.conf
"""

import argparse
import sys


def generate_krb5_conf(realm, kdc, admin_server, output_file=None):
    """
    Generate a krb5.conf configuration file.
    
    Args:
        realm: Kerberos realm (uppercase domain)
        kdc: Key Distribution Center hostname or IP
        admin_server: Kerberos admin server hostname or IP
        output_file: Optional output file path
        
    Returns:
        The generated krb5.conf content
    """
    # Convert realm to uppercase if not already
    realm = realm.upper()
    
    krb5_conf = f"""[libdefaults]
    default_realm = {realm}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    
[realms]
    {realm} = {{
        kdc = {kdc}
        admin_server = {admin_server}
    }}
    
[domain_realm]
    .{realm.lower()} = {realm}
    {realm.lower()} = {realm}
"""
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(krb5_conf)
        print(f"krb5.conf saved to {output_file}")
    else:
        print(krb5_conf)
    
    return krb5_conf


def main():
    parser = argparse.ArgumentParser(
        description='Generate krb5.conf file for Kerberos authentication'
    )
    parser.add_argument('--realm', required=True, help='Kerberos realm (e.g., EXAMPLE.COM)')
    parser.add_argument('--kdc', required=True, help='Key Distribution Center hostname or IP')
    parser.add_argument('--admin-server', required=True, help='Kerberos admin server hostname or IP')
    parser.add_argument('--output', '-o', help='Output file path (default: stdout)')
    
    args = parser.parse_args()
    
    try:
        generate_krb5_conf(
            args.realm,
            args.kdc,
            args.admin_server,
            args.output
        )
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
