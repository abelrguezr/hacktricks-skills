#!/usr/bin/env python3
"""
List available service SPNs for Silver Ticket attacks.
Usage: python list_service_spns.py [service_type]
"""

import argparse
import json
import sys

SERVICE_INFO = {
    "cifs": {
        "spn": "cifs/<HOST_FQDN>",
        "description": "Windows File Share, SMB access, C$, ADMIN$, psexec",
        "ports": [445],
        "tools": ["psexec", "smbclient", "smbexec"]
    },
    "host": {
        "spn": "host/<HOST_FQDN>",
        "description": "Scheduled tasks, WMI execution",
        "ports": [135, 445],
        "tools": ["schtasks", "wmic", "wmiexec"]
    },
    "rpcss": {
        "spn": "rpcss/<HOST_FQDN>",
        "description": "WMI, remote administration, RPC calls",
        "ports": [135],
        "tools": ["wmiexec", "Invoke-WmiMethod"]
    },
    "ldap": {
        "spn": "ldap/<DC_FQDN>",
        "description": "DCSync, AD queries, directory enumeration",
        "ports": [389, 636],
        "tools": ["mimikatz dcsync", "ldapsearch"]
    },
    "mssql": {
        "spn": "MSSQLSvc/<HOST_FQDN>:1433",
        "description": "SQL Server access, xp_cmdshell",
        "ports": [1433],
        "tools": ["mssqlclient", "sqlcmd"]
    },
    "http": {
        "spn": "http/<HOST_FQDN>",
        "description": "WinRM, web services, IIS",
        "ports": [80, 443, 5985, 5986],
        "tools": ["winrm", "curl", "Invoke-WebRequest"]
    },
    "wsman": {
        "spn": "wsman/<HOST_FQDN>",
        "description": "PowerShell remoting, WS-Management",
        "ports": [5985, 5986],
        "tools": ["Enter-PSSession", "winrm"]
    },
    "winrm": {
        "spn": "winrm/<HOST_FQDN>",
        "description": "Windows Remote Management",
        "ports": [5985, 5986],
        "tools": ["winrm", "Enter-PSSession"]
    },
    "krbtgt": {
        "spn": "krbtgt/<DOMAIN>",
        "description": "Golden tickets (requires krbtgt hash, not silver)",
        "ports": [],
        "tools": ["mimikatz kerberos::golden"]
    }
}

def main():
    parser = argparse.ArgumentParser(description="List service SPNs for Silver Ticket attacks")
    parser.add_argument("service", nargs="?", help="Specific service to show details for")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    parser.add_argument("--table", action="store_true", help="Output as formatted table")
    
    args = parser.parse_args()
    
    if args.service:
        if args.service not in SERVICE_INFO:
            print(f"Unknown service: {args.service}")
            print(f"Available services: {', '.join(SERVICE_INFO.keys())}")
            sys.exit(1)
        
        info = SERVICE_INFO[args.service]
        if args.json:
            print(json.dumps(info, indent=2))
        else:
            print(f"Service: {args.service}")
            print(f"SPN Format: {info['spn']}")
            print(f"Description: {info['description']}")
            print(f"Ports: {', '.join(map(str, info['ports'])) if info['ports'] else 'N/A'}")
            print(f"Tools: {', '.join(info['tools'])}")
    else:
        if args.json:
            print(json.dumps(SERVICE_INFO, indent=2))
        elif args.table:
            print(f"{'Service':<12} {'SPN Format':<35} {'Description':<45}")
            print("-" * 95)
            for name, info in SERVICE_INFO.items():
                print(f"{name:<12} {info['spn']:<35} {info['description']:<45}")
        else:
            print("Available Service SPNs for Silver Ticket Attacks:")
            print("=" * 60)
            for name, info in SERVICE_INFO.items():
                print(f"\n{name.upper()}")
                print(f"  SPN: {info['spn']}")
                print(f"  Description: {info['description']}")
                if info['ports']:
                    print(f"  Ports: {', '.join(map(str, info['ports']))}")
                print(f"  Tools: {', '.join(info['tools'])}")

if __name__ == "__main__":
    main()
