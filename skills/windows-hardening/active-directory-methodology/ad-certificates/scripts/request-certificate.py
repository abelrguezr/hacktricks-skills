#!/usr/bin/env python3
"""
Certificate Request Helper

Helper script for requesting certificates from AD CS using various methods.
Supports certipy, certreq, and PowerShell methods.

Usage:
    python request-certificate.py --method certipy --template User --target ca.domain.local
    python request-certificate.py --method certreq --template User --ca \\ca.domain.local
    python request-certificate.py --method powershell --template User
"""

import argparse
import json
import subprocess
import sys
from typing import Dict, Optional


def run_certipy_request(
    template: str,
    target: str,
    username: str = "",
    password: str = "",
    upn: str = "",
    dns: str = "",
    web: bool = False
) -> Dict:
    """Request certificate using certipy."""
    cmd = ["certipy", "req"]
    
    if web:
        cmd.append("-web")
    
    if target:
        cmd.extend(["-target", target])
    
    if template:
        cmd.extend(["-template", template])
    
    if username:
        cmd.extend(["-u", username])
    
    if password:
        cmd.extend(["-p", password])
    
    if upn:
        cmd.extend(["-upn", upn])
    
    if dns:
        cmd.extend(["-dns", dns])
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        return {
            "method": "certipy",
            "command": " ".join(cmd),
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "success": result.returncode == 0
        }
    except subprocess.TimeoutExpired:
        return {"error": "Command timed out", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def run_certreq_request(
    template: str,
    ca: str,
    output_file: str = "certificate.pfx"
) -> Dict:
    """Request certificate using certreq.exe."""
    # Create a simple INF file for the request
    inf_content = f"""[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=Test"
KeySpec = 1
KeyLength = 2048
MachineKeySet = 0
SMIME = 0
PrivateKeyArchive = 0
UserProtected = 0
Exportable = 1
SignatureAlgorithm = SHA256

[Extensions]
2.5.29.17 = "{text}"
"""
    
    # Write INF file
    inf_file = "certreq.inf"
    with open(inf_file, "w") as f:
        f.write(inf_content)
    
    cmd = ["certreq", "-f", inf_file, template]
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        return {
            "method": "certreq",
            "command": " ".join(cmd),
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "success": result.returncode == 0
        }
    except subprocess.TimeoutExpired:
        return {"error": "Command timed out", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def run_powershell_request(
    template: str,
    store_location: str = "cert:\\CurrentUser\\My"
) -> Dict:
    """Request certificate using PowerShell."""
    cmd = [
        "powershell",
        "-Command",
        f'Get-Certificate -Template "{template}" -CertStoreLocation "{store_location}"'
    ]
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60
        )
        return {
            "method": "powershell",
            "command": " ".join(cmd),
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "success": result.returncode == 0
        }
    except subprocess.TimeoutExpired:
        return {"error": "Command timed out", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}


def main():
    parser = argparse.ArgumentParser(description="Certificate Request Helper")
    parser.add_argument("--method", choices=["certipy", "certreq", "powershell"], required=True,
                        help="Request method")
    parser.add_argument("--template", required=True, help="Certificate template name")
    parser.add_argument("--target", help="Target CA (for certipy)")
    parser.add_argument("--ca", help="CA path (for certreq)")
    parser.add_argument("-u", "--username", help="Username")
    parser.add_argument("-p", "--password", help="Password")
    parser.add_argument("--upn", help="User Principal Name")
    parser.add_argument("--dns", help="DNS name for SAN")
    parser.add_argument("--web", action="store_true", help="Use web enrollment (certipy)")
    parser.add_argument("--output", "-o", help="Output file for JSON results")
    
    args = parser.parse_args()
    
    print(f"[*] Requesting certificate using {args.method}...")
    print(f"    Template: {args.template}")
    
    result = None
    
    if args.method == "certipy":
        result = run_certipy_request(
            template=args.template,
            target=args.target or "",
            username=args.username or "",
            password=args.password or "",
            upn=args.upn or "",
            dns=args.dns or "",
            web=args.web
        )
    elif args.method == "certreq":
        result = run_certreq_request(
            template=args.template,
            ca=args.ca or ""
        )
    elif args.method == "powershell":
        result = run_powershell_request(template=args.template)
    
    # Output results
    print("\n" + "="*60)
    print(json.dumps(result, indent=2))
    
    if result.get("success"):
        print("\n[+] Certificate request successful!")
    else:
        print("\n[-] Certificate request failed")
    
    if args.output:
        with open(args.output, "w") as f:
            json.dump(result, f, indent=2)
        print(f"\n[+] Results saved to {args.output}")


if __name__ == "__main__":
    main()
